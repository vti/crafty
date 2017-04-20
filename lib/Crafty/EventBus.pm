package Crafty::EventBus;

use strict;
use warnings;

use JSON ();
use AnyEvent;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    $self->{connections} = {};

    return $self;
}

sub new_conn {
    my $self = shift;
    my ($conn, $env) = @_;

    my $connections = $self->{connections};

    $connections->{"$conn"} = {
        conn      => $conn,
        heartbeat => AnyEvent->timer(
            interval => 30,
            cb       => sub {
                eval {
                    $conn->push('');
                    1;
                } or do {
                    delete $connections->{"$conn"};
                };
            }
        )
    };
}

sub broadcast {
    my $self = shift;
    my ($event, $data) = @_;

    $data //= {};

    $self->_broadcast({type => $event, data => $data});
}

sub _broadcast {
    my $self = shift;
    my ($event) = @_;

    $event = JSON::encode_json($event);

    my $connections = $self->{connections};

    my @conn_keys = keys %$connections;

    foreach my $conn_key (@conn_keys) {
        my $conn_info = $connections->{$conn_key};
        my $conn      = $conn_info->{conn};

        eval {
            $conn->push($event);
            1;
        } or do {
            delete $connections->{$conn_key};
            $conn->close;
        };
    }
}

1;
