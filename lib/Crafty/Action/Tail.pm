package Crafty::Action::Tail;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

use JSON ();
use AnyEvent;
use Plack::App::EventSource;
use Crafty::Tail;

sub run {
    my $self = shift;
    my (%params) = @_;

    my $uuid = $params{build_id};

    return sub {
        my $respond = shift;

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                my $cb = Plack::App::EventSource->new(
                    headers => [

                        #'Access-Control-Allow-Origin',
                        #'http://localhost:5000',
                        'Access-Control-Allow-Credentials',
                        'true'
                    ],
                    handler_cb => sub {
                        my ($conn, $env) = @_;

                        my $stream = sprintf "$self->{root}/data/builds/%s.log",
                          $build->uuid;

                        $self->tail($conn, $stream);
                    }
                )->call($self->env);

                $cb->($respond);
            },
            sub {
                $respond->([404, [], ['Not found']]);
            }
        );
    };
}

sub tail {
    my $self = shift;
    my ($conn, $path) = @_;

    my $connections = $self->{tails};

    my $tail = Crafty::Tail->new;
    $tail->tail(
        $path,
        on_error => sub {
            warn 'error';
            $conn->push(JSON::encode_json({type => 'error'}));
            $conn->close;
            delete $connections->{"$conn"};
        },
        on_eof => sub {
            warn 'eof';
            $conn->push(JSON::encode_json({type => 'eof'}));
            $conn->close;
            delete $connections->{"$conn"};
        },
        on_read => sub {
            my ($content) = @_;

            $content =~ s{\n}{\\n}g;

            $conn->push(
                JSON::encode_json({type => 'output', data => $content}));
        }
    );

    $connections->{"$conn"} = {
        conn      => $conn,
        tail      => $tail,
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

sub DESTROY { "ACTION TAIL DESTROY" }

1;
