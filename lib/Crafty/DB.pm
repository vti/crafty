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
    my $self = shift;

    my $sql = sql_insert
      into => 'builds',
      values =>
      [app => 'foo', rev => 'bar', branch => 'master', created => time];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            print "@$_\n" for @$rows;
        }
    );
}

sub build {
    my $self = shift;
    my ($id, $cb) = @_;

    my $sql = sql_select
      from => 'builds',
      columns => [
        'id',     'uuid',    'app', 'status', 'rev', 'branch', 'message',
        'author', 'started', 'duration'
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
        'id',     'uuid',    'app', 'status', 'rev', 'branch', 'message',
        'author', 'started', 'duration'
      ];

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
