use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;
use TestSetup;

use AnyEvent;

use_ok 'Crafty::Action::Tail';

subtest 'error when build not found' => sub {
    my $action = _build(env => {});

    my $cb = $action->run(build_id => '123');

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 404;
};

#subtest 'creates build' => sub {
#    my $action = _build(
#        env => {
#            QUERY_STRING => 'rev=123&branch=master&message=fix&author=vti'
#        }
#    );
#
#    my $cb = $action->run(provider => 'rest', project => 'my_project');
#
#    my $cv = AnyEvent->condvar;
#
#    my $res;
#    $cb->(
#        sub {
#            ($res) = @_;
#
#            $cv->send;
#        }
#    );
#
#    $cv->recv;
#
#    is $res->[0], 200;
#};
#
done_testing;

sub _build { TestSetup->build_action('Tail', @_) }
