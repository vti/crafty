package Crafty::Action::API::CreateEvent;
use Moo;
extends 'Crafty::Action::API::Base';

use JSON ();
use Crafty::PubSub;

sub run {
    my $self = shift;

    my $body = $self->req->content;

    eval { $body = JSON::decode_json($body); } or do {
        return $self->render(400, { error => 'Invalid JSON' });
    };

    Crafty::PubSub->instance->publish(@$body);

    return $self->render(200, { ok => 1 });
}

1;
