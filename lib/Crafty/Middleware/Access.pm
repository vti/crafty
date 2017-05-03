package Crafty::Middleware::Access;

use strict;
use warnings;

use base 'Plack::Middleware';

use Plack::Util::Accessor qw(
  config
  denier
);

sub call {
    my $self = shift;
    my ($env) = @_;

    my $route    = $env->{'crafty.route'};
    my $username = $env->{'crafty.username'};

    my $global_mode = $self->config->config->{access}->{mode} // 'private';

    my $access = $route->arguments->{access};

    # Force private to everything except login in global private mode
    $access = 'private' if $global_mode eq 'private' && $route->name ne 'Login';

    if ($access && $access eq 'private' && !$username) {
        return $self->denier->($env);
    }

    return $self->app->($env);
}

1;
