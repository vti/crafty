use strict;
use warnings;

use Test::More;
use Test::Deep;
use TestSetup;

use Routes::Tiny;

use_ok 'Crafty::Middleware::Access';

subtest 'grants access to login page always' => sub {
    my $build = _build();

    my $routes = _build_routes();
    my $route  = $routes->match('/login');

    my $res = $build->call({ 'crafty.route' => $route });

    is $res->[0], 200;
};

subtest 'grants access to public page' => sub {
    my $build = _build();

    my $routes = _build_routes();
    my $route  = $routes->match('/public');

    my $res = $build->call({ 'crafty.route' => $route });

    is $res->[0], 200;
};

subtest 'denies access to private page when no user' => sub {
    my $build = _build(denier => sub { [ 302, [], [] ] });

    my $routes = _build_routes();
    my $route  = $routes->match('/private');

    my $res = $build->call({ 'crafty.route' => $route });

    is $res->[0], 302;
};

subtest 'grants access to private page to correct user' => sub {
    my $build = _build();

    my $routes = _build_routes();
    my $route  = $routes->match('/private');

    my $res = $build->call({ 'crafty.route' => $route, 'crafty.username' => 'user' });

    is $res->[0], 200;
};

done_testing;

sub _build_routes {
    my $routes = Routes::Tiny->new;

    $routes->add_route('/login',   name => 'Login');
    $routes->add_route('/public',  name => 'Public');
    $routes->add_route('/private', name => 'Private', arguments => { access => 'private' });

    return $routes;
}

sub _build {
    return Crafty::Middleware::Access->new(
        config => TestSetup->build_config,
        app    => sub { [ 200, [], ['granted'] ] },
        @_
    );
}
