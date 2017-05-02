use strict;
use warnings;

use Test::More;
use Test::Deep;
use TestSetup;

use_ok 'Crafty::Pool';

subtest 'build: builds successfully' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'I');

    my $config = _build_config('date');

    my $pool = _build(config => $config);

    my $cv = AnyEvent->condvar;

    $cv->begin;
    Crafty::PubSub->instance->own->subscribe(
        '*' => sub {
            my ($ev, $data) = @_;

            if ($ev eq 'build.update' && $data->{status} eq 'S') {
                $cv->end;
            }

            return;
        }
    );

    $cv->begin;
    $pool->peek->then(sub { $cv->end });

    $cv->wait;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'S';
};

subtest 'build: builds failure' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'I');

    my $config = _build_config('date; exit 255');

    my $pool = _build(config => $config);

    my $cv = AnyEvent->condvar;

    $cv->begin;
    Crafty::PubSub->instance->own->subscribe(
        '*' => sub {
            my ($ev, $data) = @_;

            if ($ev eq 'build.update' && $data->{status} eq 'F') {
                $cv->end;
            }

            return;
        }
    );

    $cv->begin;
    $pool->peek->then(sub { $cv->end });

    $cv->wait;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'F';
};

subtest 'build: builds killed' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'I');

    my $config = _build_config('exit 255');

    my $pool = _build(config => $config);

    my $cv = AnyEvent->condvar;

    $cv->begin;
    Crafty::PubSub->instance->own->subscribe(
        '*' => sub {
            my ($ev, $data) = @_;

            if ($ev eq 'build.update' && $data->{status} eq 'K') {
                $cv->end;
            }

            return;
        }
    );

    $cv->begin;
    $pool->peek->then(sub { $cv->end });

    $cv->wait;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'K';
};

subtest 'cancel: removes unknown builds' => sub {
    my $build = TestSetup->create_build(project => 'my_app', status => 'P');

    my $cv = AnyEvent->condvar;

    my $pool = _build();

    $cv->begin;
    $pool->cancel($build)->then(sub { $cv->send });

    $cv->wait;

    $build = TestSetup->load_build($build->uuid);

    is $build->status, 'K';
};

done_testing;

sub _build_config {
    my ($cmd) = @_;

    return TestSetup->build_config(<<"EOF");
---
pool:
    mode: inproc
projects:
    - id: my_app
      build:
        - $cmd
EOF
}

sub _build {
    my (%params) = @_;

    if (my $config = $params{config}) {
        $config->config->{db_file} = $TestSetup::db_file->filename;
    }

    return Crafty::Pool->new(db => TestSetup->build_db, config => {}, @_);
}
