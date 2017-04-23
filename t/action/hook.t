use strict;
use warnings;
use lib 't/lib';

use Test::More;
use TestSetup;

use_ok 'Crafty::Action::Hook';

subtest 'error on unknown provider' => sub {
    my $action = _build(env => {});

    my $res = $action->run(provider => 'unknown', project => 'my_project');

    is $res->[0], 404;
};

subtest 'error on unknown project' => sub {
    my $action = _build(env => {});

    my $res = $action->run(provider => 'rest', project => 'unknown');

    is $res->[0], 404;
};

subtest 'error when invalid params' => sub {
    my $action = _build(env => {});

    my $res = $action->run(provider => 'rest', project => 'my_project');

    is $res->[0], 400;
};

subtest 'creates build' => sub {
    my $action = _build(
        env => {
            QUERY_STRING => 'rev=123&branch=master&message=fix&author=vti'
        }
    );

    my $cb = $action->run(provider => 'rest', project => 'my_project');

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 200;

    my $uuid = $res->[2]->[0];

    my $build = TestSetup->load_build($uuid);

    is $build->status, 'I';
};

done_testing;

sub _build { TestSetup->build_action('Hook', @_) }
