use strict;
use warnings;

use Test::More;
use Test::Deep;
use TestSetup;

use_ok 'Crafty::Pool';

subtest 'build: builds successfully' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'I');

    _run_pool(config => 'date');

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'S';
};

subtest 'build: builds failure' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'I');

    _run_pool(config => 'date; exit 255');

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'F';
};

subtest 'build: builds killed' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'I');

    _run_pool(config => 'exit 255');

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'K';
};

subtest 'cancel: removes unknown builds' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'P');

    my $cv = AnyEvent->condvar;

    my $pool = _build();

    $pool->start;

    $pool->cancel($build);

    $cv->begin;
    $pool->stop(sub { $cv->end });

    $cv->recv;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'K';
};

done_testing;

sub _build_config {
    my ($cmd) = @_;

    return TestSetup->build_config(<<"EOF");
---
projects:
    - id: my_app
      build:
        - $cmd
EOF
}

sub _run_pool {
    my (%params) = @_;

    my $cv = AnyEvent->condvar;

    $cv->begin;

    my $pool = _build(
        config   => _build_config($params{config}),
        on_event => sub {
            my ($ev, $uuid) = @_;

            if ($ev eq 'build.done') {
                $cv->end;
            }
            if ($ev eq 'build.error') {
                $cv->end;
            }
        }
    );

    $pool->start;
    $pool->peek;

    $cv->recv;

    $cv->begin;
    $pool->stop(sub { $cv->end });

    $cv->recv;
}

sub _build {
    return Crafty::Pool->new(db => TestSetup->build_db, config => {}, @_);
}
