package Crafty::Action::Index;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

use Crafty::Pager;

sub run {
    my $self = shift;

    my $current_page = $self->req->param('p');
    $current_page = 1 unless $current_page && $current_page =~ m/^\d+$/;
    my $limit = 10;

    return sub {
        my $respond = shift;

        my $builds_count = 0;
        $self->db->count->then(
            sub {
                ($builds_count) = @_;
            }
          )->then(
            sub {
                $self->db->find(limit => $limit)->then(
                    sub {
                        my ($builds) = @_;

                        my $pager = Crafty::Pager->new(
                            current_page => $current_page,
                            limit        => $limit,
                            total        => $builds_count
                        )->pager;

                        my $content = $self->render(
                            'index.caml',
                            {
                                builds_count => $builds_count,
                                builds       => [map { $_->to_hash } @$builds],
                                pager        => $pager
                            }
                        );

                        $respond->([200, [], [$content]]);
                    }
                );
            }
          );
    };
}

1;
