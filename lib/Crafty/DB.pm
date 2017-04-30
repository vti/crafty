package Crafty::DB;
use Moo;

use Promises qw(deferred);
use AnyEvent::DBI;
use SQL::Composer ':funcs';
use Crafty::Build;
use Crafty::EventBus;

has 'db_file', is => 'ro';
has 'dbh',
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;

    return AnyEvent::DBI->new('dbi:SQLite:dbname=' . $self->db_file, '', '');
  };

sub save {
    my $self = shift;
    my ($build, $cb) = @_;

    my $deferred = deferred;

    if ($build->is_new) {
        my $sql = sql_insert
          into   => 'builds',
          values => [ %{ $build->to_store }, version => 1 ];

        $self->dbh->exec(
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

                        $build->version(1);
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
          set   => [ %{ $build->to_store }, version => $build->version + 1 ],
          where => [ version => $build->version, uuid => $build->uuid ];

        $self->dbh->exec(
            $sql->to_sql,
            $sql->to_bind,
            sub {
                my ($dbh, $rows, $rv) = @_;

                $#_ or die "failure: $@";

                if ($rv eq '0E0') {
                    Crafty::Log->error("Build %s not updated (version %d)",
                        $build->uuid, $build->version);

                    return $deferred->reject;
                }

                $build->version($build->version + 1);

                $self->_broadcast('build', $build->to_hash);

                $deferred->resolve($build);
            }
        );
    }

    return $deferred->promise;
}

sub update_field {
    my $self = shift;
    my ($build, $key, $value) = @_;

    my $deferred = deferred;

    my $sql = sql_update
      table => 'builds',
      set   => [ $key => $value ],
      where => [ uuid => $build->uuid ];

    $self->dbh->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            if ($rv eq '0E0') {
                Crafty::Log->error("Build %s field not updated (key %s)", $build->uuid, $key);

                return $deferred->reject;
            }

            $self->_broadcast('build', $build->to_hash);

            $deferred->resolve($build);
        }
    );

    return $deferred->promise;
}

sub lock {
    my $self = shift;
    my ($build) = @_;

    my $deferred = deferred;

    my $sql = sql_update
      table => 'builds',
      set   => [ status => 'L', version => $build->version + 1 ],
      where => [ status => { '!=' => 'L' }, uuid => $build->uuid ];

    $self->dbh->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            my $locked = $rv && $rv ne '0E0' ? 1 : 0;

            if ($locked) {
                $build->version($build->version + 1);
            }

            $deferred->resolve($build, $locked);
        }
    );

    return $deferred->promise;
}

sub load {
    my $self = shift;
    my ($uuid) = @_;

    my $sql = sql_select
      from    => 'builds',
      columns => [ Crafty::Build->columns ],
      where   => [ uuid => $uuid ];

    my $deferred = deferred;

    $self->dbh->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            unless ($rows && @$rows) {
                Crafty::Log->error('Build %s not found', $uuid);

                return $deferred->reject;
            }

            my $build = $sql->from_rows($rows)->[0];

            return $deferred->resolve(Crafty::Build->new(%$build));
        }
    );

    return $deferred->promise;
}

sub count {
    my $self = shift;

    my $sql = sql_select from => 'builds', columns => [ \'COUNT(*)' ];

    my $deferred = deferred;

    $self->dbh->exec(
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
    my (%params) = @_;

    my $sql = sql_select
      from     => 'builds',
      columns  => [ Crafty::Build->columns ],
      order_by => [ 'id' => 'DESC' ],
      %params;

    my $deferred = deferred;

    $self->dbh->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            $deferred->resolve(
                [
                    map { Crafty::Build->new(%{$_}) }
                      @{ $sql->from_rows($rows) }
                ]
            );
        }
    );

    return $deferred->promise;
}

sub _broadcast {
    my $self = shift;

    Crafty::EventBus->instance->broadcast(@_);
}

1;
