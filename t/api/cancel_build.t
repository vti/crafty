use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;
use TestSetup;

use AnyEvent;

use_ok 'Crafty::Action::API::CancelBuild';

subtest 'error when build not found' => sub {
    my $action = _build(env => {});

    my $cb = $action->run(uuid => '123');

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 404;
};

subtest 'error when build not cancelable' => sub {
    my $action = _build(env => {});

    my $build = TestSetup->create_build(status => 'S');

    my $cb = $action->run(uuid => $build->uuid);

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 400;
};

subtest 'returns ok' => sub {
    my $action = _build(env => {});

    my $build = TestSetup->create_build();

    my $cb = $action->run(uuid => $build->uuid);

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 200;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'C';
};

done_testing;

sub _build { TestSetup->build_action('API::CancelBuild', @_) }
