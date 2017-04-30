package Crafty::Action::Event;
use Moo;
extends 'Crafty::Action::Base';

use Crafty::PubSub;

sub run {
    my $self = shift;

    my $body = $self->req->content;

    $body = JSON::decode_json($body);

    Crafty::PubSub->instance->publish(@$body);

    return [ 200, [], ['ok'] ];
}

1;
