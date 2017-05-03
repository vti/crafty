package Crafty::Middleware::User;

use strict;
use warnings;

use base 'Plack::Middleware';

use Plack::Util::Accessor qw(
  config
);

use MIME::Base64 ();
use Plack::Session;
use Crafty::Password;

sub call {
    my $self = shift;
    my ($env) = @_;

    my $route = $env->{'crafty.route'};

    my $username = $self->_username_from_session($env);
    $username //= $self->_username_from_basic_auth($env);

    $env->{'crafty.username'} = $username;

    return $self->app->($env);
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

sub _username_from_basic_auth {
    my $self = shift;
    my ($env) = @_;

    return unless my $auth = $env->{HTTP_AUTHORIZATION};
    return unless $auth =~ m/^Basic\s+(.*)$/i;

    my ($username, $password) = split /:/, (MIME::Base64::decode($1) || ":"), 2;

    return unless $username && $password;

    return unless my $user = $self->config->user($username);

    my $checker = Crafty::Password->new(hashing => $user->{hashing}, salt => $user->{salt});
    return unless $checker->equals($username, $password, $user->{password});

    return $username;
}

1;
