use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::Deep;
use TestSetup;

use AnyEvent;
use MIME::Base64 qw(encode_base64);
use JSON ();
use HTTP::Request::Common;
use HTTP::Message::PSGI qw(req_to_psgi);
use Crafty;

subtest 'returns zero response when no builds' => sub {
    _setup();

    my $cv = AnyEvent->condvar;

    my $app = _build();

    my $cb = $app->(req_to_psgi GET('/api/builds', _headers()));

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 200;
    is_deeply JSON::decode_json($res->[2]->[0]),
      {
        builds => [],
        total  => 0,
        pager  => undef
      };
};

subtest 'returns builds' => sub {
    _setup();

    my $build = TestSetup->create_build;

    my $cv = AnyEvent->condvar;

    my $app = _build();

    my $cb = $app->(req_to_psgi GET('/api/builds', _headers()));

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 200;
    cmp_deeply JSON::decode_json($res->[2]->[0]),
      {
        builds => [ superhashof({ uuid => $build->uuid }) ],
        total  => 1,
        pager  => undef
      };
};

done_testing;

sub _setup {
    TestSetup->cleanup_db;
}

sub _headers {
    return (Authorization => 'Basic ' . encode_base64('api:password'));
}

sub _build {
    return Crafty->new(
        config => TestSetup->build_config,
        db     => TestSetup->build_db,
        pool   => TestSetup->mock_pool
    )->to_psgi;
}
