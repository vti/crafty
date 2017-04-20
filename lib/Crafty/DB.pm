package Crafty::DB;

use strict;
use warnings;

use AnyEvent::DBI;
use SQL::Composer ':funcs';
use Time::Moment;

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

    $values{started} //= $self->_now();
    $values{status}  //= 'P';

    my $sql = sql_insert into => 'builds', values => [%values];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ( $dbh, $rows, $rv ) = @_;

            $#_ or die "failure: $@";

            $dbh->func(
                q{undef, undef, 'builds', 'id'},
                'last_insert_id' => sub {
                    my ( $dbh, $id, $error ) = @_;

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

    my $time = $self->_now();

    my $sql = sql_update
      table => 'builds',
      set   => [ %values, finished => $time ],
      where => [ id => $id ];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ( $dbh, $rows, $rv ) = @_;

            $#_ or die "failure: $@";

            $cb->() if $cb;
        }
    );
}

sub build {
    my $self = shift;
    my ( $id, $cb ) = @_;

    my $sql = sql_select
      from    => 'builds',
      columns => [
        'id',      'uuid',   'app',     'status', 'rev', 'branch',
        'message', 'author', 'started', 'finished'
      ],
      where => [ uuid => $id ];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ( $dbh, $rows, $rv ) = @_;

            return $cb->() unless $rows && @$rows;

            my $build = $sql->from_rows($rows)->[0];

            $build->{duration} = $self->_duration($build->{finished}, $build->{started});

            $cb->( $build );
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
        'message', 'author', 'started', 'finished'
      ],
      order_by => [ 'started' => 'DESC' ];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ( $dbh, $rows, $rv ) = @_;

            $#_ or die "failure: $@";

            $cb->(
                [
                    map {
                        {
                            %$_, duration =>
                              $self->_duration( $_->{finished}, $_->{started} )
                        }
                    } @{ $sql->from_rows($rows) }
                ]
            );
        }
    );
}

sub _duration {
    my $self = shift;
    my ($from, $to) = @_;

    my $duration = 0;

    eval {
        my $from_tm = Time::Moment->from_string( $from, lenient => 1 );
        my $to_tm   = Time::Moment->from_string( $to,   lenient => 1 );

        $duration = ($from_tm->epoch + $from_tm->microsecond / 1000000 - $to_tm->epoch + $to_tm->microsecond / 1000000);
    } or do {
        warn "$@";
    };

    return $duration;
}

sub _now {
    return Time::Moment->now->strftime('%F %T%f%z');
}

1;
