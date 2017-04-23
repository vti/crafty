package Crafty::Log;

use strict;
use warnings;

my $VERBOSE = 0;

sub init {
    my $class = shift;
    my (%params) = @_;

    $VERBOSE = 1 if $params{verbose};

    return $class;
}

sub error {
    my $class = shift;

    warn "ERROR: " . join('', @_) . "\n";
}

sub info {
    my $class = shift;
    my ($msg, @args) = @_;

    return unless $VERBOSE;

    warn sprintf($msg, @args) . "\n";
}

1;
