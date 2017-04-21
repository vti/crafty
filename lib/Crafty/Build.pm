package Crafty::Build;

use strict;
use warnings;

use Data::UUID;
use Time::Moment;

sub new {
    my $class = shift;
    my %params = @_ == 1 ? %{$_[0]} : @_;

    my $self = {%params};
    bless $self, $class;

    $self->{uuid}   //= $self->_generate_id;
    $self->{status} //= 'N';

    return $self;
}

sub columns {
    return (
        'app',
        'uuid',

        'status',

        'started',
        'finished',

        'rev',
        'branch',
        'author',
        'message',
    );
}

sub is_new { !!shift->{is_new} }

sub app      { shift->{app} }
sub uuid     { shift->{uuid} }
sub status   { shift->{status} }
sub started  { shift->{started} }
sub finished { shift->{finished} }

sub duration {
    my $self = shift;
    my ($from, $to) = @_;

    return 0 unless my $started = $self->{started};
    my $finished = $self->{finished} || $self->_now;

    my $duration = 0;

    eval {
        my $finished_moment =
          Time::Moment->from_string($finished, lenient => 1);
        my $started_moment = Time::Moment->from_string($started, lenient => 1);

        $duration =
          ($finished_moment->epoch +
              $finished_moment->microsecond / 1000000 -
              $started_moment->epoch +
              $started_moment->microsecond / 1000000);
    } or do {
        warn "$@";
    };

    return $duration;
}

sub status_display {
    my $self = shift;

    return {
        'N' => 'default',
        'P' => 'default',
        'S' => 'success',
        'E' => 'danger',
        'F' => 'danger',
        'C' => 'danger',
    }->{$self->{status}};
}

sub status_name {
    my $self = shift;

    return {
        'N' => 'New',
        'P' => 'Running',
        'S' => 'Success',
        'E' => 'Error',
        'F' => 'Failure',
        'C' => 'Canceled',
    }->{$self->{status}};
}

sub is_cancelable {
    my $self = shift;

    return $self->{status} eq 'P' || $self->{status} eq 'N';
}

sub is_restartable {
    my $self = shift;

    return $self->{status} ne 'P' && $self->{status} ne 'N';
}

sub finish {
    my $self = shift;
    my ($new_status) = @_;

    $self->{status}   = $new_status;
    $self->{finished} = $self->_now;

    return 1;
}

sub start {
    my $self = shift;

    return unless $self->{status} eq 'N';

    $self->{status}  = 'P';
    $self->{started} = $self->_now;

    return 1;
}

sub restart {
    my $self = shift;

    return unless $self->is_restartable;

    $self->{status}  = 'P';
    $self->{started} = $self->_now;

    return 1;
}

sub cancel {
    my $self = shift;

    return unless $self->is_cancelable;

    $self->{status}   = 'C';
    $self->{finished} = $self->_now;

    return 1;
}

sub to_store {
    my $self = shift;

    return {
        app  => $self->{app},
        uuid => $self->{uuid},

        status => $self->{status},

        started  => $self->{started},
        finished => $self->{finished},

        rev     => $self->{rev},
        branch  => $self->{branch},
        author  => $self->{author},
        message => $self->{message},
    };
}

sub to_hash {
    my $self = shift;

    return {
        app  => $self->{app},
        uuid => $self->{uuid},

        status         => $self->{status},
        status_name    => $self->status_name,
        status_display => $self->status_display,

        is_cancelable  => $self->is_cancelable,
        is_restartable => $self->is_restartable,

        started  => $self->{started},
        finished => $self->{finished},
        duration => $self->duration,

        rev     => $self->{rev},
        branch  => $self->{branch},
        author  => $self->{author},
        message => $self->{message},
    };
}

sub _now {
    return Time::Moment->now->strftime('%F %T%f%z');
}

sub _generate_id {
    my $self = shift;

    $self->{is_new} = 1;

    my $id = my $uuid = Data::UUID->new;
    return lc($uuid->to_string($uuid->create));
}

1;
