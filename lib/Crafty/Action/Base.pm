package Crafty::Action::Base;
use Moo;

use Plack::Request;
use Crafty::Log;

has 'config', is => 'ro', required => 1;
has 'env',    is => 'ro', required => 1;
has 'db',     is => 'ro', required => 1;
has 'view',   is => 'ro', required => 1;
has 'pool',   is => 'ro';

sub req { Plack::Request->new(shift->env) }

sub render {
    my $self = shift;
    my ($template, $args) = @_;

    my $view = $self->{view};

    my $content = $view->render_file($template, $args);

    return $view->render_file('layout.caml', { content => $content, verbose => Crafty::Log->is_verbose });
}

sub not_found {
    my $self = shift;
    my ($respond) = @_;

    my $res = [ '404', [], ['Not Found'] ];

    return $respond ? $respond->($res) : $res;
}

sub redirect {
    my $self = shift;
    my ($url, $respond) = @_;

    my $res = [ 302, [ Location => $url ], [''] ];

    return $respond ? $respond->($res) : $res;
}

sub handle_error {
    my $self = shift;
    my ($error, $respond) = @_;

    Crafty::Log->error(@_) unless ref $error;

    my $res = ref $error ? $error : [ 500, [], ['error'] ];

    return $respond ? $respond->($res) : $res;
}

1;
