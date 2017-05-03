package Crafty::Middleware::Access;

use strict;
use warnings;

use base 'Plack::Middleware';

use Plack::Util::Accessor qw(
  config
);

use Plack::Session;

sub call {
    my $self = shift;
    my ($env) = @_;

    my $route    = $env->{'crafty.route'};
    my $username = $self->_username_from_session($env);

    if ($username) {
        $env->{'crafty.username'} = $username;
    }

    my $global_mode = $self->config->config->{access}->{mode} // 'private';

    my $access = $route->arguments->{access};

    # Force private to everything except login in global private mode
    $access = 'private' if $global_mode eq 'private' && $route->name ne 'Login';

    if ($access && $access eq 'private' && !$username) {
        return $self->_redirect_to_login;
    }

    return $self->app->($env);
}

sub _redirect_to_login {
    my $self = shift;

    return [ 302, [ 'Location' => '/login' ], [] ];
}

sub _username_from_session {
    my $self = shift;
    my ($env) = @_;

    my $session = Plack::Session->new($env);
    return unless $session;

    my $username = $session->get('username');
    return unless $username;

    return unless $self->config->user($username);

    return $username;
}

1;
