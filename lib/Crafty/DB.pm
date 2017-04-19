package Crafty::DB;

use strict;
use warnings;

use AnyEvent::DBI;
use SQL::Composer ':funcs';

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    my $dbpath = $params{dbpath};

    my $dbh = new AnyEvent::DBI "dbi:SQLite:dbname=$dbpath", "", "";
    $self->{dbh} = $dbh;

    return $self;
}

sub insert {
    my $self     = shift;
    my $cb       = pop;
    my (%values) = @_;

    my $sql = sql_insert into => 'builds', values => [%values];

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

                    $cb->($id);
                }
            );
        }
    );
}

sub finish {
    my $self     = shift;
    my $id       = shift;
    my $cb       = pop;
    my (%values) = @_;

    my $time = time;

    my $sql = sql_update
      table => 'builds',
      set => [%values, finished => $time, duration => \['? - started', $time]],
      where => [id => $id];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            $cb->() if $cb;
        }
    );
}

sub build {
    my $self = shift;
    my ($id, $cb) = @_;

    my $sql = sql_select
      from    => 'builds',
      columns => [
        'id',      'uuid',   'app',     'status', 'rev', 'branch',
        'message', 'author', 'started', 'duration'
      ],
      where => [uuid => $id];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $cb->($rows && @$rows ? $sql->from_rows($rows)->[0] : undef);
        }
    );
}

sub builds {
    my $self = shift;
    my ($cb) = @_;

    my $sql = sql_select
      from    => 'builds',
      columns => [
        'id',      'uuid',   'app',     'status', 'rev', 'branch',
        'message', 'author', 'started', 'duration'
      ],
      order_by => ['started' => 'DESC'];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            $cb->($sql->from_rows($rows));
        }
    );
}

1;
