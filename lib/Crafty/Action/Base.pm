package Crafty::Action::Base;

use strict;
use warnings;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{env}  = $params{env};
    $self->{db}   = $params{db};
    $self->{view} = $params{view};
    $self->{root} = $params{root};

    return $self;
}

sub env  { shift->{env} }
sub db   { shift->{db} }
sub view { shift->{view} }

sub render {
    my $self = shift;
    my ($template, $args) = @_;

    my $view = $self->{view};

    my $content = $view->render_file($template, $args);

    return $view->render_file('layout.caml', {content => $content});
}

1;
