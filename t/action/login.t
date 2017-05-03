use strict;
use warnings;
use lib 't/lib';

use Test::More;
use TestSetup;

use HTTP::Request::Common;
use HTTP::Message::PSGI qw(req_to_psgi);

use_ok 'Crafty::Action::Login';

subtest 'form on GET' => sub {
    my $action = _build(env => req_to_psgi GET('/'));

    my $res = $action->run;

    is $res->[0], 200;
    like $res->[2]->[0], qr/Login/i;
};

subtest 'validation errors' => sub {
    my $action = _build(env => req_to_psgi POST('/'));

    my $res = $action->run;

    is $res->[0], 400;
    like $res->[2]->[0], qr/required/i;
};

subtest 'validation errors on unknown user' => sub {
    my $action = _build(env => req_to_psgi POST('/' => { username => 'unknown', password => 'wrong' }));

    my $res = $action->run;

    is $res->[0], 400;
    like $res->[2]->[0], qr/unknown credentials/i;
};

subtest 'validation errors on wrong passport' => sub {
    my $action = _build(env => req_to_psgi POST('/' => { username => 'username', password => 'wrong' }));

    my $res = $action->run;

    is $res->[0], 400;
    like $res->[2]->[0], qr/unknown credentials/i;
};

subtest 'creates session on successful login' => sub {
    my $action = _build(env => req_to_psgi POST('/' => { username => 'username', password => 'password' }));

    $action->env->{'psgix.session'}         = {};
    $action->env->{'psgix.session.options'} = {};

    my $res = $action->run;

    is $res->[0], 302;

    my $session = $action->env->{'psgix.session'};

    is_deeply $session, { username => 'username' };
};

done_testing;

sub _build {
    my (%params) = @_;

    $params{cgi} //= 'cgi.sh';

    my $config = <<"EOF";
---
access:
    users:
      - username: username
        password: 0665fcae289dda92188f71c03828220b
        hashing: md5
projects:
    - id: test
      build:
          - date
EOF

    TestSetup->build_action('Login', env => {}, config => TestSetup->build_config($config), @_);
}
