use strict;
use warnings;

use Test::More;
use Test::Deep;

use_ok 'Crafty::Pager';

subtest 'pager: returns undef when not needed' => sub {
    my $pager = _build(current_page => 1, total => 10, limit => 10);

    ok !$pager->pager;
};

subtest 'pager: first page' => sub {
    my $pager = _build(current_page => 1, total => 10, limit => 5);

    is_deeply $pager->pager,
      {
        next  => 2,
        pages => [
            {
                page   => 1,
                active => 1
            },
            {
                page   => 2,
                active => 0
            }
        ]
      };
};

subtest 'pager: middle' => sub {
    my $pager = _build(current_page => 2, total => 15, limit => 5);

    is_deeply $pager->pager,
      {
        prev  => 1,
        next  => 3,
        pages => [
            {
                page   => 1,
                active => 0
            },
            {
                page   => 2,
                active => 1
            },
            {
                page   => 3,
                active => 0
            }
        ]
      };
};

subtest 'pager: middle with tail' => sub {
    my $pager = _build(current_page => 2, total => 13, limit => 5);

    is_deeply $pager->pager,
      {
        prev  => 1,
        next  => 3,
        pages => [
            {
                page   => 1,
                active => 0
            },
            {
                page   => 2,
                active => 1
            },
            {
                page   => 3,
                active => 0
            }
        ]
      };
};

subtest 'pager: last page' => sub {
    my $pager = _build(current_page => 2, total => 7, limit => 5);

    is_deeply $pager->pager,
      {
        prev  => 1,
        pages => [
            {
                page   => 1,
                active => 0
            },
            {
                page   => 2,
                active => 1
            }
        ]
      };
};

done_testing;

sub _build {
    return Crafty::Pager->new(@_);
}
