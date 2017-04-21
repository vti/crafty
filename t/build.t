use strict;
use warnings;

use Test::More;
use Test::Deep;

use_ok 'Crafty::Build';

subtest 'uuid: generates when not passed' => sub {
    my $build = _build();

    like $build->uuid,
      qr/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/;
    ok $build->is_new;
};

subtest 'uuid: uses passed' => sub {
    my $build = _build(uuid => '123');

    is $build->uuid, '123';
    ok !$build->is_new;
};

subtest 'duration: zero by default' => sub {
    my $build = _build();

    is $build->duration, 0;
};

subtest 'duration: calculates duration' => sub {
    my $build = _build(
        started  => '2017-01-02 03:04:05.123456+02:00',
        finished => '2017-01-02 03:04:06.223456+02:00'
    );

    is sprintf('%.06f', $build->duration), '1.346912';
};

subtest 'is_cancelable: returns boolean when can be canceled' => sub {
    my $build = _build(status => 'N');

    ok $build->is_cancelable;

    $build = _build(status => 'P');

    ok $build->is_cancelable;

    $build = _build(status => 'E');

    ok !$build->is_cancelable;
};

subtest 'is_restartable: returns boolean when can be restarted' => sub {
    my $build = _build(status => 'N');

    ok !$build->is_restartable;

    $build = _build(status => 'P');

    ok !$build->is_restartable;

    $build = _build(status => 'E');

    ok $build->is_restartable;
};

subtest 'status: returns default value' => sub {
    my $build = _build();

    is $build->status, 'N';
};

subtest 'status_display: returns status state' => sub {
    my $build = _build(status => 'N');

    is $build->status_display, 'default';
};

subtest 'status_name: returns readable status' => sub {
    my $build = _build(status => 'N');

    is $build->status_name, 'New';
};

subtest 'finish: finishes' => sub {
    my $build = _build(status => 'N');

    ok $build->finish('S');
    is $build->status,     'S';
    isnt $build->finished, '';
};

subtest 'start: starts' => sub {
    my $build = _build(status => 'P');

    ok !$build->start;

    $build = _build(status => 'N');

    ok $build->start;
    isnt $build->started, '';
    is $build->status,    'P';
};

subtest 'restart: restarts' => sub {
    my $build = _build(status => 'N');

    ok !$build->restart;

    $build = _build(status => 'E', started => '2017-01-02');

    ok $build->restart;
    isnt $build->started, '2017-01-02';
    is $build->status,    'P';
};

subtest 'cancel: cancels' => sub {
    my $build = _build(status => 'S');

    ok !$build->cancel;

    $build = _build(status => 'P', started => '2017-01-02');

    ok $build->cancel;
    isnt $build->finished, '';
    is $build->status,     'C';
};

subtest 'to_hash: serializes' => sub {
    my $build = _build(
        status   => 'N',
        started  => '2017-01-02 03:04:05.123+02:00',
        finished => '2017-01-02 03:04:06.123+02:00',

        app => 'my_app',

        rev     => '123',
        branch  => 'master',
        author  => 'vti',
        message => 'fix',
    );

    cmp_deeply $build->to_hash, {
        uuid => ignore(),

        app     => 'my_app',
        rev     => '123',
        branch  => 'master',
        author  => 'vti',
        message => 'fix',

        status         => 'N',
        status_display => 'default',
        status_name    => 'New',

        started  => re(qr/2017-01-02/),
        finished => re(qr/2017-01-02/),
        duration => re(qr/1\.2/),

        is_restartable => '',
        is_cancelable  => 1,
    };
};

done_testing;

sub _build {
    return Crafty::Build->new(@_);
}
