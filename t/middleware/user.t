use strict;
use warnings;

use Test::More;
use Test::Deep;
use TestSetup;

use MIME::Base64 ();

use_ok 'Crafty::Middleware::User';

subtest 'loads user from session' => sub {
    my $build = _build();

    my $env = { 'psgix.session' => { username => 'username' } };
    $build->call($env);

    is $env->{'crafty.username'}, 'username';
};

subtest 'does not load basic auth not valid' => sub {
    my $build = _build();

    my $env = {
        'psgix.session'    => {},
        HTTP_AUTHORIZATION => 'Basic 123'
    };

    $build->call($env);

    ok !$env->{'crafty.username'};
};

subtest 'does not load basic auth with unknown user' => sub {
    my $build = _build();

    my $env = {
        'psgix.session'    => {},
        HTTP_AUTHORIZATION => 'Basic ' . MIME::Base64::encode_base64('unknown:wrong_password')
    };

    $build->call($env);

    ok !$env->{'crafty.username'};
};

subtest 'does not load basic auth with wrong password' => sub {
    my $build = _build();

    my $env = {
        'psgix.session'    => {},
        HTTP_AUTHORIZATION => 'Basic ' . MIME::Base64::encode_base64('username:wrong_password')
    };

    $build->call($env);

    ok !$env->{'crafty.username'};
};

subtest 'loads user from basic auth' => sub {
    my $build = _build();

    my $env =
      { 'psgix.session' => {}, HTTP_AUTHORIZATION => 'Basic ' . MIME::Base64::encode_base64('username:password') };

    $build->call($env);

    is $env->{'crafty.username'}, 'username';
};

done_testing;

sub _build {
    return Crafty::Middleware::User->new(
        config => TestSetup->build_config,
        app    => sub { [ 200, [], ['granted'] ] },
        @_
    );
}
