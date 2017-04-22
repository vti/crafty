package Crafty::DB;

use strict;
use warnings;

use AnyEvent::DBI;
use Promises qw(deferred);
use SQL::Composer ':funcs';
use Crafty::Build;
use Crafty::EventBus;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    my $dbpath = $params{dbpath};

    my $dbh = AnyEvent::DBI->new("dbi:SQLite:dbname=$dbpath", "", "");
    $self->{dbh} = $dbh;

    return $self;
}

sub save {
    my $self = shift;
    my ($build, $cb) = @_;

    my $deferred = deferred;

    if ($build->is_new) {
        my $sql = sql_insert into => 'builds', values => [%{$build->to_store}];

        $self->{dbh}->exec(
            $sql->to_sql,
            $sql->to_bind,
            sub {
                my ($dbh, $rows, $rv) = @_;

                $#_ or die "failure: $@";

                $dbh->func(
                    q{undef, undef, 'builds', 'id'},
                    'last_insert_id' => sub {
                        my ($dbh, $id, $error) = @_;

                        $self->_broadcast('build.new', $build->to_hash);

                        $build->not_new;

                        $deferred->resolve($build);
                    }
                );
            }
        );
    }
    else {
        my $sql = sql_update
          table => 'builds',
          set   => [%{$build->to_store}],
          where => [uuid => $build->uuid];

        $self->{dbh}->exec(
            $sql->to_sql,
            $sql->to_bind,
            sub {
                my ($dbh, $rows, $rv) = @_;

                $#_ or die "failure: $@";

                $self->_broadcast('build', $build->to_hash);

                $deferred->resolve($build);
            }
        );
    }

    return $deferred->promise;
}

sub load {
    my $self = shift;
    my ($uuid) = @_;

    my $sql = sql_select
      from    => 'builds',
      columns => [Crafty::Build->columns],
      where   => [uuid => $uuid];

    my $deferred = deferred;

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            return $deferred->reject unless $rows && @$rows;

            my $build = $sql->from_rows($rows)->[0];

            return $deferred->resolve(Crafty::Build->new($build));
        }
    );

    return $deferred->promise;
}

sub count {
    my $self = shift;

    my $sql = sql_select from => 'builds', columns => [\'COUNT(*)'];

    my $deferred = deferred;

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            $deferred->resolve($rows->[0]->[0]);
        }
    );

    return $deferred->promise;
}

sub find {
    my $self = shift;

    my $sql = sql_select
      from     => 'builds',
      columns  => [Crafty::Build->columns],
      order_by => ['started' => 'DESC'],
      limit    => 10,
      offset   => 0;

    my $deferred = deferred;

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            $deferred->resolve(
                [map { Crafty::Build->new($_) } @{$sql->from_rows($rows)}]);
        }
    );

    return $deferred->promise;
}

sub _broadcast {
    my $self = shift;

    Crafty::EventBus->instance->broadcast(@_);
}

1;
