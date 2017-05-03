package Crafty::Middleware::Routes;

use strict;
use warnings;

use base 'Plack::Middleware';

use Plack::Util::Accessor qw(
  routes
);

sub call {
    my $self = shift;
    my ($env) = @_;

    my $path_info = $env->{PATH_INFO};

    my $match = $self->routes->match($path_info, method => $env->{REQUEST_METHOD});

    if ($match) {
        $env->{'crafty.route'} = $match;

        return $self->app->($env);
    }
    else {
        return [ 404, [], ['Not Found'] ];
    }
}

1;
