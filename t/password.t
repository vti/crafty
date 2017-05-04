use strict;
use warnings;

use Test::More;
use Test::Fatal;

use_ok 'Crafty::Password';

subtest 'hash: hashes password' => sub {
    my $password = _build(hashing => 'md5', salt => 'hello');

    is $password->hash('username', 'password'), 'a616e69e90cb180bdc8aa7c303836451';
};

subtest 'hash: throws on unknown hashing' => sub {
    my $password = _build(hashing => 'unknown');

    like exception { $password->hash('username', 'password') }, qr/unknown hashing/i;
};

subtest 'equals: checks password' => sub {
    my $password = _build(hashing => 'md5', salt => 'hello');

    my $correct_hash = $password->hash('username', 'password');

    ok $password->equals('username', 'password', $correct_hash);
    ok !$password->equals('username', 'password', 'wrong');
};

done_testing;

sub _build {
    return Crafty::Password->new(@_);
}
