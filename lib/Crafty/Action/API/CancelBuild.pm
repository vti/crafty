package Crafty::Action::API::CancelBuild;
use Moo;
extends 'Crafty::Action::API::Base';

use Promises qw(deferred);
use Crafty::Build;

sub run {
    my $self = shift;
    my (%captures) = @_;

    my $uuid = $captures{uuid};

    return sub {
        my $respond = shift;

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                if (!$build->is_cancelable) {
                    return deferred->reject($self->render(400, { error => 'Build not cancelable' }));
                }
                else {
                    $build->cancel;

                    return $self->db->save($build);
                }
            }
          )->then(
            sub {
                my ($build) = @_;

                $self->pool->cancel($build);

                return $self->render(200, { ok => 1 }, $respond);
            }
          )->catch(
            sub {
                return $self->not_found($respond) unless @_;

                $self->handle_error(@_, $respond);
            }
          );
    };
}

1;
