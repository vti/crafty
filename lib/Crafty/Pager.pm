package Crafty::Pager;

use strict;
use warnings;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{current_page} = $params{current_page};
    $self->{limit}        = $params{limit};
    $self->{total}        = $params{total};

    return $self;
}

sub pager {
    my $self = shift;

    return unless $self->{total} > $self->{limit};

    my $pager = {};

    $pager->{prev} = $self->{current_page} - 1 if $self->{current_page} > 1;

    $pager->{next} = $self->{current_page} + 1
      if $self->{current_page} * $self->{limit} < $self->{total};

    my $last_page = $self->{total} / $self->{limit};
    $last_page++ if $self->{total} % $self->{limit};

    for (1 .. $last_page) {
        push @{$pager->{pages}},
          {
            page   => $_,
            active => ($_ == $self->{current_page} ? 1 : 0)
          };
    }

    return $pager;
}

1;
