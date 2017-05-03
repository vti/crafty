#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Crafty::Password;

my $opt_salt    = '';
my $opt_hashing = 'bcrypt';

GetOptions(
    'salt=s'    => \$opt_salt,
    'hashing=s' => \$opt_hashing,
) or die("Error in command line arguments\n");

my ($username, $password) = @ARGV;
die "Usage: <username> <password> [--salt] [--hashing]\n" unless $username && $password;

my $hash = Crafty::Password->new(
    hashing => $opt_hashing,
    salt    => $opt_salt,
)->hash($username, $password);

print <<"EOF";
username: $username
password: $hash
hashing: $opt_hashing
salt: $opt_salt
EOF
