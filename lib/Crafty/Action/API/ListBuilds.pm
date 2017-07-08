package Crafty::Action::API::ListBuilds;
use Moo;
extends 'Crafty::Action::API::Base';

use Crafty::Pager;
use Crafty::Build;

sub run {
    my $self = shift;

    my $current_page = $self->req->param('p');
    $current_page = 1
      unless $current_page && $current_page =~ m/^\d+$/ && $current_page > 0;
    my $limit = 10;

    return sub {
        my $respond = shift;

        my $total = 0;
        $self->db->count->then(
            sub {
                ($total) = @_;

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
                    total        => $total
                )->pager;

                $self->render(
                    200,
                    {
                        total  => $total,
                        builds => [
                            map {
                                {
                                    %{ $_->to_hash },
                                      links => [ { href => '/api/builds/' . $_->uuid, rel => 'build' }, ]
                                }
                            } @$builds
                        ],
                        pager => $pager
                    },
                    $respond
                );
            }
          )->catch(
            sub {
                $self->handle_error(@_);
            }
          );
    };
}

1;
