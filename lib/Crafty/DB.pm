package Crafty::DB;

use strict;
use warnings;

use AnyEvent::DBI;
use SQL::Composer ':funcs';

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    my $dbh = new AnyEvent::DBI "dbi:SQLite:dbname=/home/vti/dev/crafty/db.db", "", "";
    $self->{dbh} = $dbh;

    return $self;
}

sub insert {
    my $self = shift;

    my $sql = sql_insert
      into => 'builds',
      values =>
      [app => 'foo', ref => 'bar', branch => 'master', created => time];

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

1;
