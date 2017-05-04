package Crafty::Action::API::WatchEvents;
use Moo;
extends 'Crafty::Action::API::Base';

use Promises qw(deferred);
use JSON ();
use Plack::App::EventSource;
use Crafty::PubSub;
use Crafty::Log;

sub run {
    my $self = shift;

    return sub {
        my $respond = shift;

        my $cb = Plack::App::EventSource->new(
            headers    => [ 'Access-Control-Allow-Credentials', 'true' ],
            handler_cb => sub {
                my ($conn, $env) = @_;

                Crafty::PubSub->instance->subscribe(
                    '*' => sub {
                        my ($ev, $data) = @_;

                        $conn->push(JSON::encode_json([ $ev, $data ]));

                        return deferred->resolve;
                    }
                );
            }
        )->call($self->env);

        $cb->($respond);
    };
}

1;
