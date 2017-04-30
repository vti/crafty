package Crafty::Action::Cancel;
use Moo;
extends 'Crafty::Action::Base';

use Promises qw(deferred);

sub run {
    my $self = shift;
    my (%params) = @_;

    my $uuid = $params{build_id};

    return sub {
        my $respond = shift;

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                return deferred->reject($self->not_found)
                  unless $build && $build->cancel;

                return $self->db->save($build);
            },
            sub {
                return deferred->reject($self->not_found);
            }
          )->then(
            sub {
                my ($build) = @_;

                $self->pool->peek;

                return $self->redirect("/builds/$uuid", $respond);
            },
          )->catch(
            sub {
                $self->handle_error(@_, $respond);
            }
          );
    };
}

1;
