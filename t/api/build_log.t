use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;
use TestSetup;

use AnyEvent;

use_ok 'Crafty::Action::API::BuildLog';

subtest 'error when build not found' => sub {
    my $action = _build(env => {});

    my $cb = $action->run(uuid => '123');

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 404;
};

subtest 'error when stream not found' => sub {
    my $action = _build(env => {});

    my $build = TestSetup->create_build();

    my $cb = $action->run(uuid => $build->uuid);

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 404;
};

subtest 'downloads file' => sub {
    my $action = _build(env => {});

    my $build = TestSetup->create_build();

    TestSetup->write_file(TestSetup->base . '/builds/' . $build->uuid . '.log', 'hello');

    my $cb = $action->run(uuid => $build->uuid);

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 200;
    cmp_deeply $res->[1],
      [
        'Content-Type'        => 'text/plain',
        'Content-Length'      => 5,
        'Last-Modified'       => ignore(),
        'Content-Disposition' => 'attachment; filename=' . $build->uuid . '.log'
      ];
    my $fh = $res->[2];
    is <$fh>, 'hello';
};

done_testing;

sub _build { TestSetup->build_action('API::BuildLog', @_) }
