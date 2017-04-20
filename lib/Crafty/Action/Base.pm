package Crafty::Action::Base;

use strict;
use warnings;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{env}       = $params{env};
    $self->{db}        = $params{db};
    $self->{view}      = $params{view};
    $self->{root}      = $params{root};
    $self->{event_bus} = $params{event_bus};

    return $self;
}

sub env       { shift->{env} }
sub db        { shift->{db} }
sub view      { shift->{view} }
sub event_bus { shift->{event_bus} }

sub broadcast { shift->event_bus->broadcast(@_) }

sub render {
    my $self = shift;
    my ($template, $args) = @_;

    my $view = $self->{view};

    my $content = $view->render_file($template, $args);

    return $view->render_file('layout.caml', {content => $content});
}

1;
