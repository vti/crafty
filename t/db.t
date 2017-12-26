use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;
use TestSetup;

use Storable ();
use AnyEvent;

use_ok 'Crafty::DB';

subtest 'lock: locks build' => sub {
    _setup();

    my $build = TestSetup->create_build;

    my $db = _build();

    my $cv = AnyEvent->condvar;

    $cv->begin;

    my $rv;
    $db->lock($build)->then(
        sub {
            (undef, $rv) = @_;

            $cv->end;
        }
    );

    $cv->recv;

    $build = TestSetup->load_build($build->uuid);

    ok $rv;
    is $build->status, 'L';
};

subtest 'lock: doesnt lock already locked' => sub {
    _setup();

    my $build = TestSetup->create_build(status => 'L');

    my $db = _build();

    my $cv = AnyEvent->condvar;

    $cv->begin;

    my $rv;
    $db->lock($build)->then(
        sub {
            (undef, $rv) = @_;

            $cv->end;
        }
    );

    $cv->recv;

    $build = TestSetup->load_build($build->uuid);

    ok !$rv;
    is $build->status, 'L';
};

subtest 'save: creates new build' => sub {
    _setup();

    my $build = Crafty::Build->new(
        status  => 'I',
        project => 'foo',
        rev     => '123',
        ref     => 'refs/heads/master',
        author  => 'vti',
        message => 'fix'
    );

    my $db = _build();

    my $cv = AnyEvent->condvar;

    $cv->begin;

    $db->save($build)->then(sub { $cv->end });

    $build = TestSetup->load_build($build->uuid);

    is $build->status,  'I';
    is $build->version, 1;
};

subtest 'save: updates build' => sub {
    _setup();

    my $build = TestSetup->create_build;

    my $db = _build();

    my $cv = AnyEvent->condvar;

    $cv->begin;

    $db->save(Crafty::Build->new(%{ $build->to_hash }, author => 'some new author'))->then(sub { $cv->end });

    $build = TestSetup->load_build($build->uuid);

    is $build->author,  'some new author';
    is $build->version, 2;
};

subtest 'save: fails when version not synced' => sub {
    _setup();

    my $build1 = TestSetup->create_build;
    my $build2 = Storable::dclone($build1);

    my $db = _build();

    my $cv = AnyEvent->condvar;

    $cv->begin;

    $db->save(Crafty::Build->new(%{ $build1->to_hash }, author => 'some new author'))->then(sub { $cv->end });

    $cv->begin;

    my $not_updated = 0;
    $db->save(Crafty::Build->new(%{ $build2->to_hash }, author => 'some new author'))->then(sub { $cv->end })
      ->catch(sub { $not_updated++; $cv->end });

    $cv->wait;

    ok $not_updated;
};

subtest 'update_field: updates field' => sub {
    _setup();

    my $build = TestSetup->create_build;

    my $db = _build();

    my $cv = AnyEvent->condvar;

    $cv->begin;

    $db->update_field($build, pid => '12345')->then(sub { $cv->end });

    $build = TestSetup->load_build($build->uuid);

    is $build->pid, '12345';
};

done_testing;

sub _setup { TestSetup->cleanup_db }

sub _build { TestSetup->build_db }
