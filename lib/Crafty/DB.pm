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
    $values{status}  //= 'N';

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

sub restart {
    my $self     = shift;
    my $id       = shift;
    my $cb       = pop;
    my (%values) = @_;

    my $time = $self->_now();

    my $new_status = 'P';

    my $sql = sql_update
      table => 'builds',
      set   => [%values, status => $new_status, started => $time, finished => 0],
      where => [-or => [id => $id, uuid => $id]];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            $cb->(
                $self->_prepare(
                    {
                        uuid => $id,
                        status   => $new_status,
                        started  => $time,
                        finished => 0,
                        duration => 0,
                    }
                )
            ) if $cb;
        }
    );
}

sub start {
    my $self     = shift;
    my $id       = shift;
    my $cb       = pop;
    my (%values) = @_;

    my $time = $self->_now();

    my $sql = sql_update
      table => 'builds',
      set   => [%values, status => 'P', started => $time, finished => 0],
      where => [-or => [id => $id, uuid => $id]];

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

sub finish {
    my $self     = shift;
    my $id       = shift;
    my $cb       = pop;
    my (%values) = @_;

    my $time = $self->_now();

    my $sql = sql_update
      table => 'builds',
      set   => [%values, finished => $time],
      where => [-or => [id => $id, uuid => $id]];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            $cb->($self->_prepare({uuid => $id, %values, finished => $time})) if $cb;
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
        'message', 'author', 'started', 'finished'
      ],
      where => [uuid => $id];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            return $cb->() unless $rows && @$rows;

            my $build = $sql->from_rows($rows)->[0];

            $cb->($self->_prepare($build));
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
      order_by => ['started' => 'DESC'];

    $self->{dbh}->exec(
        $sql->to_sql,
        $sql->to_bind,
        sub {
            my ($dbh, $rows, $rv) = @_;

            $#_ or die "failure: $@";

            $cb->([map { $self->_prepare($_) } @{$sql->from_rows($rows)}]);
        }
    );
}

sub _duration {
    my $self = shift;
    my ($from, $to) = @_;

    return 0 unless $to;

    my $duration = 0;

    $from //= $self->_now;

    eval {
        my $from_tm = Time::Moment->from_string($from, lenient => 1);
        my $to_tm   = Time::Moment->from_string($to,   lenient => 1);

        $duration =
          ($from_tm->epoch +
              $from_tm->microsecond / 1000000 -
              $to_tm->epoch +
              $to_tm->microsecond / 1000000);
    } or do {
        warn "$@";
    };

    return $duration;
}

sub _now {
    return Time::Moment->now->strftime('%F %T%f%z');
}

sub _prepare {
    my $self = shift;
    my ($build) = @_;

    $build->{duration} =
      $self->_duration($build->{finished}, $build->{started});
    $build->{status_display} = {
        'N' => 'default',
        'P' => 'default',
        'S' => 'success',
        'E' => 'danger',
        'F' => 'danger',
        'C' => 'danger',
    }->{$build->{status}};
    $build->{status_name} = {
        'N' => 'New',
        'P' => 'Running',
        'S' => 'Success',
        'E' => 'Error',
        'F' => 'Failure',
        'C' => 'Canceled',
    }->{$build->{status}};

    $build->{is_cancelable}  = $build->{status} eq 'P' || $build->{status} eq 'N';
    $build->{is_restartable} = $build->{status} ne 'P' && $build->{status} ne 'N';

    return $build;
}

1;
