package Crafty::Action::Index;
use Moo;
extends 'Crafty::Action::Base';

use Crafty::Log;
use Crafty::Pager;

sub run {
    my $self = shift;

    my $current_page = $self->req->param('p');
    $current_page = 1
      unless $current_page && $current_page =~ m/^\d+$/ && $current_page > 0;
    my $limit = 10;

    return sub {
        my $respond = shift;

        my $builds_count = 0;
        $self->db->count->then(
            sub {
                ($builds_count) = @_;

                return $self->db->find(
                    offset => ($current_page - 1) * $limit,
                    limit  => $limit
                );
            }
          )->then(
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
          )->catch(
            sub {
                Crafty::Log->error(@_);

                $respond->([500, [], ['error']]);
            }
          );
    };
}

1;
