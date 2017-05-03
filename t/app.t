use strict;
use warnings;
use lib 't/lib';

use Test::More;
use TestSetup;

use AnyEvent;

use_ok 'Crafty';

subtest 'error on unknown path' => sub {
    my $app = _build();

    my $psgi = $app->to_psgi;

    my $res = $psgi->({ PATH_INFO => '/unknown', REQUEST_METHOD => 'GET', REMOTE_ADDR => '' });

    is $res->[0], 404;
};

subtest 'returns rendered page' => sub {
    my $app = _build();

    my $psgi = $app->to_psgi;

    my $cb = $psgi->({ PATH_INFO => '/', REQUEST_METHOD => 'GET', REMOTE_ADDR => '' });

    my $cv = AnyEvent->condvar;

    $cb->(
        sub {
            $cv->send(@_);
        }
    );

    my ($res) = $cv->recv;

    is $res->[0], 200;
    like $res->[2]->[0], qr{<title>Crafty</title>};
};

done_testing;

sub _build {
    return Crafty->new(
        config => TestSetup->build_config,
        db     => TestSetup->build_db,
        pool   => TestSetup->mock_pool
    );
}
