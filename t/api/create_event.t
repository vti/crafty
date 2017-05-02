use strict;
use warnings;
use lib 't/lib';

use Test::More;
use TestSetup;

use JSON ();
use HTTP::Request::Common;
use HTTP::Message::PSGI qw(req_to_psgi);

use_ok 'Crafty::Action::API::CreateEvent';

subtest 'error on invalid fields' => sub {
    my $action = _build(
        env => req_to_psgi POST(
            '/'     => 'Content-Type' => 'application/json',
            Content => 'abc'
        )
    );

    my $res = $action->run;

    is $res->[0], 400;
};

done_testing;

sub _build { TestSetup->build_action('API::CreateEvent', env => {}, @_) }
