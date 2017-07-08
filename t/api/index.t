use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;
use TestSetup;

use AnyEvent;

use_ok 'Crafty::Action::API::Index';

subtest 'api page' => sub {
    my $action = _build(env => {});

    my $build = TestSetup->create_build();

    my $res = $action->run;

    is $res->[0], 200;
    like $res->[2]->[0], qr/documentation/;
};

done_testing;

sub _build { TestSetup->build_action('API::Index', @_) }
