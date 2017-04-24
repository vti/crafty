package Crafty::Action::Restart;
use Moo;
extends 'Crafty::Action::Base';

use Promises qw(deferred);
use Crafty::Log;

sub run {
    my $self = shift;
    my (%params) = @_;

    my $uuid = $params{build_id};

    return sub {
        my $respond = shift;

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                if ($build && $build->restart) {
                    return $self->db->save($build);
                }
                else {
                    return deferred->reject($self->not_found);
                }
            },
            sub {
                return deferred->reject($self->not_found);
            }
          )->then(
            sub {
                my ($build) = @_;

                $self->pool->build($build);

                return $self->redirect(sprintf("/builds/%s", $build->uuid),
                    $respond);
            }
          )->catch(sub { $self->handle_error(@_, $respond) });
    };
}

1;
