use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;
use TestSetup;

use AnyEvent;

use_ok 'Crafty::Action::Restart';

subtest 'error when build not found' => sub {
    my $action = _build(env => {});

    my $cb = $action->run(build_id => '123');

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 404;
};

subtest 'error when build not restartable' => sub {
    my $action = _build(env => {});

    my $build = TestSetup->create_build(status => 'N');

    my $cb = $action->run(build_id => $build->uuid);

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 404;
};

subtest 'redirects' => sub {
    my $action = _build(env => {});

    my $build = TestSetup->create_build();

    my $cb = $action->run(build_id => $build->uuid);

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 302;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'I';
};

done_testing;

sub _build { TestSetup->build_action('Restart', @_) }
