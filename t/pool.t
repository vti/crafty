use strict;
use warnings;

use Test::More;
use Test::Deep;
use TestSetup;

use_ok 'Crafty::Pool';

subtest 'build: builds successfully' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'I');

    my $cv = AnyEvent->condvar;

    $cv->begin;

    my $pool = _build(
        config     => _build_config('date'),
        on_destroy => sub { $cv->end; }
    );

    $cv->begin;

    $pool->start;
    $pool->build($build, sub { $cv->end });
    $pool->stop;

    $cv->recv;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'S';
};

subtest 'build: builds failure' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'I');

    my $cv = AnyEvent->condvar;

    $cv->begin;

    my $pool = _build(
        config     => _build_config('date; exit 255'),
        on_destroy => sub { $cv->end; }
    );

    $cv->begin;

    $pool->start;
    $pool->build($build, sub { $cv->end });
    $pool->stop;

    $cv->recv;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'F';
};

subtest 'build: builds killed' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'I');

    my $cv = AnyEvent->condvar;

    $cv->begin;

    my $pool = _build(
        config     => _build_config('exit 255'),
        on_destroy => sub { $cv->end; }
    );

    $cv->begin;

    $pool->start;
    $pool->build($build, sub { $cv->end });
    $pool->stop;

    $cv->recv;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'K';
};

done_testing;

sub _build_config {
    my ($cmd) = @_;

    return Crafty::Config->new(
        config => {projects => [{id => 'my_app', build => [$cmd]}]});
}

sub _build {
    return Crafty::Pool->new(db => TestSetup->build_db, @_);
}
