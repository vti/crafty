package Crafty::Action::API::BuildTail;
use Moo;
extends 'Crafty::Action::API::Base';

use JSON ();
use AnyEvent;
use Plack::App::EventSource;
use Crafty::Tail;
use Crafty::Log;

sub run {
    my $self = shift;
    my (%captures) = @_;

    my $uuid = $captures{uuid};

    return sub {
        my $respond = shift;

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                my $cb = Plack::App::EventSource->new(
                    headers    => [ 'Access-Control-Allow-Credentials', 'true' ],
                    handler_cb => sub {
                        my ($conn, $env) = @_;

                        my $stream = $self->config->catfile('builds_dir', $build->uuid . '.log');

                        $self->tail($conn, $stream);
                    }
                )->call($self->env);

                $cb->($respond);
            },
            sub {
                $respond->([ 404, [], ['Not found'] ]);
            }
          )->catch(
            sub {
                Crafty::Log->error(@_);

                $respond->([ 500, [], ['error'] ]);
            }
          );
    };
}

sub tail {
    my $self = shift;
    my ($conn, $path) = @_;

    my $tail = Crafty::Tail->new;
    $tail->tail(
        $path,
        on_error => sub {
            $conn->push(JSON::encode_json(['tail.error']));
            $conn->close;

            $tail->stop;
            delete $self->{tail};
        },
        on_eof => sub {
            $conn->push(JSON::encode_json(['tail.eof']));
            $conn->close;

            $tail->stop;
            delete $self->{tail};
        },
        on_read => sub {
            my ($content) = @_;

            $content =~ s{\n}{\\n}g;

            $conn->push(JSON::encode_json([ 'tail.output', $content ]));
        }
    );

    $self->{tail} = {
        conn      => $conn,
        tail      => $tail,
        heartbeat => AnyEvent->timer(
            interval => 15,
            cb       => sub {
                $conn->push('') or do {
                    $tail->stop;

                    delete $self->{tail};
                };
            }
        )
    };
}

1;
