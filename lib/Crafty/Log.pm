package Crafty::Log;

use strict;
use warnings;

our $VERBOSE = 0;
our $QUIET   = 0;

sub init {
    my $class = shift;
    my (%params) = @_;

    $VERBOSE = 1 if $params{verbose};
    $QUIET   = 1 if $params{quiet};

    return $class;
}

sub error {
    my $class = shift;
    my ($msg, @args) = @_;

    return if $QUIET;

    $msg = sprintf($msg, @args);
    $msg =~ s{\s+$}{};

    warn "ERROR: " . $msg . "\n";
}

sub info {
    my $class = shift;
    my ($msg, @args) = @_;

    return unless $VERBOSE;

    warn sprintf($msg, @args) . "\n";
}

1;
