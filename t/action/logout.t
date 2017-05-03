use strict;
use warnings;
use lib 't/lib';

use Test::More;
use TestSetup;

use HTTP::Request::Common;
use HTTP::Message::PSGI qw(req_to_psgi);

use_ok 'Crafty::Action::Logout';

subtest 'expires session' => sub {
    my $action = _build(env => req_to_psgi GET('/'));

    $action->env->{'psgix.session'} = { username => 'username' };
    $action->env->{'psgix.session.options'} = {};

    my $res = $action->run;

    is $res->[0], 302;

    my $session = $action->env->{'psgix.session'};
    is_deeply $session, {};

    my $options = $action->env->{'psgix.session.options'};
    is_deeply $options, { expire => 1 };
};

done_testing;

sub _build {
    my (%params) = @_;

    $params{cgi} //= 'cgi.sh';

    my $config = <<"EOF";
---
projects:
    - id: test
      build:
          - date
EOF

    TestSetup->build_action('Logout', env => {}, config => TestSetup->build_config($config), @_);
}
