use strict;
use warnings;
use lib 't/lib';

use Test::More;
use TestSetup;

use JSON ();
use HTTP::Request::Common;
use HTTP::Message::PSGI qw(req_to_psgi);

use_ok 'Crafty::Action::API::CreateBuild';

subtest 'error on unknown provider' => sub {
    my $action = _build(env => req_to_psgi POST('/' => {}));

    my $res = $action->run;

    is $res->[0], 422;
    like $res->[2]->[0], qr/required/i;
};

subtest 'error on unknown project' => sub {
    my $action = _build(
        env => req_to_psgi POST(
            '/' => { project => 'unknown', rev => '123', branch => 'master', author => 'vti', message => 'fix' }
        )
    );

    my $res = $action->run;

    is $res->[0], 422;
    like $res->[2]->[0], qr/unknown project/i;
};

subtest 'creates build from form' => sub {
    my $action = _build(
        env => req_to_psgi POST(
            '/' => { project => 'my_project', rev => '123', branch => 'master', author => 'vti', message => 'fix' }
        )
    );

    my $cv = AnyEvent->condvar;

    my $cb = $action->run;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 201;

    my $uuid = JSON::decode_json($res->[2]->[0])->{uuid};

    my $build = TestSetup->load_build($uuid);

    is $build->status,    'I';
    is $build->project,   'my_project';
    is $build->rev,       '123';
    is $build->branch,    'master';
    is $build->author,    'vti';
    is $build->message,   'fix';
    like $build->created, qr/^\d{4}-/;
};

subtest 'error on invalid json' => sub {
    my $action = _build(
        env => req_to_psgi POST(
            '/'     => 'Content-Type' => 'application/json',
            Content => 'abc'
        )
    );

    my $cv = AnyEvent->condvar;

    my $res = $action->run;

    is $res->[0], 400;
    like $res->[2]->[0], qr/invalid json/i;
};

subtest 'creates build from json' => sub {
    my $action = _build(
        env => req_to_psgi POST(
            '/'     => 'Content-Type' => 'application/json',
            Content => JSON::encode_json(
                { project => 'my_project', rev => '123', branch => 'master', author => 'vti', message => 'fix' }
            )
        )
    );

    my $cv = AnyEvent->condvar;

    my $cb = $action->run;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 201;

    my $uuid = JSON::decode_json($res->[2]->[0])->{uuid};

    my $build = TestSetup->load_build($uuid);

    is $build->status,    'I';
    is $build->project,   'my_project';
    is $build->rev,       '123';
    is $build->branch,    'master';
    is $build->author,    'vti';
    is $build->message,   'fix';
    like $build->created, qr/^\d{4}-/;
};

done_testing;

sub _build { TestSetup->build_action('API::CreateBuild', env => {}, @_) }
