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

sub is_verbose { !!$VERBOSE }

sub error {
    my $class = shift;
    my ($msg, @args) = @_;

    return if $QUIET;

    warn "ERROR: " . $class->_format($msg, @args) . "\n";
}

sub info {
    my $class = shift;
    my ($msg, @args) = @_;

    return unless $VERBOSE;

    warn $class->_format($msg, @args) . "\n";
}

sub _format {
    my $class = shift;
    my ($msg, @args) = @_;

    $msg = @args ? sprintf($msg, @args) : $msg;
    $msg =~ s{\s+$}{};

    return $msg;
}

1;
