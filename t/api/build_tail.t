use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;
use TestSetup;

use AnyEvent;

use_ok 'Crafty::Action::API::BuildTail';

subtest 'error when build not found' => sub {
    my $action = _build(env => {});

    my $cb = $action->run(uuid => '123');

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 404;
};

done_testing;

sub _build { TestSetup->build_action('API::BuildTail', @_) }
