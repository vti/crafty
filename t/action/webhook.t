use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::TempDir::Tiny;
use TestSetup;

use JSON ();
use HTTP::Request::Common;
use HTTP::Message::PSGI qw(req_to_psgi);

use_ok 'Crafty::Action::Webhook';

subtest 'error when unknown project' => sub {
    my $action = _build();

    my $res = $action->run(project => 'unknown', provider => 'unknown');

    is $res->[0], 404;
    like $res->[2]->[0], qr/unknown project/i;
};

subtest 'error when unknown provider' => sub {
    my $action = _build();

    my $res = $action->run(project => 'test', provider => 'unknown');

    is $res->[0], 404;
    like $res->[2]->[0], qr/unknown hook provider/i;
};

subtest 'error when cgi not found or not executable' => sub {
    my $action = _build(cgi => '/unknown-cgi');

    my $res = $action->run(project => 'test', provider => 'test');

    is $res->[0], 500;
    like $res->[2]->[0], qr/not executable/i;
};

subtest 'returns failed response' => sub {
    my $tempdir = tempdir();

    TestSetup->write_file("$tempdir/cgi.sh", <<'EOF');
#!/bin/sh

STDIN=`cat`

echo "Status: 400"
echo "Some error"

exit 0
EOF
    chmod 0755, "$tempdir/cgi.sh";

    my $action = _build(cgi => "$tempdir/cgi.sh", env => req_to_psgi POST('/' => { foo => 'bar' }));

    my $res = $action->run(project => 'test', provider => 'test');

    is $res->[0], 400;
    like $res->[2]->[0], qr/some error/i;
};

subtest 'returns original response without needed headers' => sub {
    my $tempdir = tempdir();

    TestSetup->write_file("$tempdir/cgi.sh", <<'EOF');
#!/bin/sh

STDIN=`cat`

echo "Status: 200"
echo "ok, but not parsed"

exit 0
EOF
    chmod 0755, "$tempdir/cgi.sh";

    my $action = _build(cgi => "$tempdir/cgi.sh", env => req_to_psgi POST('/' => { foo => 'bar' }));

    my $res = $action->run(project => 'test', provider => 'test');

    is $res->[0], 200;
    like $res->[2]->[0], qr/not parsed/i;
};

subtest 'creates new build' => sub {
    my $tempdir = tempdir();

    TestSetup->write_file("$tempdir/cgi.sh", <<'EOF');
#!/bin/sh

STDIN=`cat`

echo "Status: 200"
echo "X-Crafty-Build-Rev: 123"
echo "X-Crafty-Build-Ref: refs/heads/master"
echo "X-Crafty-Build-Author: vti"
echo "X-Crafty-Build-Message: fix"
echo
echo "ok"

exit 0
EOF
    chmod 0755, "$tempdir/cgi.sh";

    my $action = _build(cgi => "$tempdir/cgi.sh", env => req_to_psgi POST('/' => { foo => 'bar' }));

    my $cb = $action->run(project => 'test', provider => 'test');

    my $cv = AnyEvent->condvar;

    $cb->(sub { $cv->send(@_) });

    my ($res) = $cv->recv;

    is $res->[0], 200;
    like $res->[2]->[0], qr/ok/i;

    my $uuid = JSON::decode_json($res->[2]->[0])->{uuid};

    my $build = TestSetup->load_build($uuid);

    is $build->rev,     '123';
    is $build->ref,     'refs/heads/master';
    is $build->author,  'vti';
    is $build->message, 'fix';
};

done_testing;

sub _build {
    my (%params) = @_;

    $params{cgi} //= 'cgi.sh';

    my $config = <<"EOF";
---
projects:
    - id: test
      webhooks:
          - id: test
            cgi: $params{cgi}
      build:
          - date
EOF

    TestSetup->build_action('Webhook', env => {}, config => TestSetup->build_config($config), @_);
}
