package Crafty::Action::Logout;
use Moo;
extends 'Crafty::Action::Base';

use Plack::Session;

sub content_type { 'text/html' }

sub run {
    my $self = shift;

    my $session = Plack::Session->new($self->env);

    $session->expire;

    return $self->redirect('/');
}

1;
