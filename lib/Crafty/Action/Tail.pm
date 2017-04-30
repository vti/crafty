package Crafty::Action::Tail;
use Moo;
extends 'Crafty::Action::Base';

use JSON ();
use AnyEvent;
use Plack::App::EventSource;
use Crafty::Tail;
use Crafty::Log;

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
                    headers    => ['Access-Control-Allow-Credentials', 'true'],
                    handler_cb => sub {
                        my ($conn, $env) = @_;

                        my $stream =
                          $self->config->catfile('builds_dir',
                            $build->uuid . '.log');

                        $self->tail($conn, $stream);
                    }
                )->call($self->env);

                $cb->($respond);
            },
            sub {
                $respond->([404, [], ['Not found']]);
            }
          )->catch(
            sub {
                Crafty::Log->error(@_);

                $respond->([500, [], ['error']]);
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

1;
