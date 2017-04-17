package Crafty::Worker;

use strict;
use warnings;

sub work {
    my ($handle, @cmd) = @_;

    open STDOUT, ">&", $handle or die;
    open STDERR, ">&", $handle or die;

    exec @cmd;
}

1;
