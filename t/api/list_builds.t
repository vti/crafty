use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;
use TestSetup;

use AnyEvent;

use_ok 'Crafty::Action::API::ListBuilds';

subtest 'index page' => sub {
    my $action = _build(env => {});

    my $build = TestSetup->create_build();

    my $cb = $action->run;

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 200;
    like $res->[2]->[0], qr/uuid/;
};

done_testing;

sub _build { TestSetup->build_action('API::ListBuilds', @_) }
