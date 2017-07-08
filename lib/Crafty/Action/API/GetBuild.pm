package Crafty::Action::API::GetBuild;
use Moo;
extends 'Crafty::Action::API::Base';

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

                $self->render(
                    200,
                    {
                        build => {
                            %{ $build->to_hash },
                            links => [
                                { href => '/api/builds/' . $build->uuid . '/log',    rel => 'build_log' },
                                { href => '/api/builds/' . $build->uuid . '/cancel', rel => 'cancel_build' },
                            ]
                        }
                    },
                    $respond
                );
            }
          )->catch(
            sub {
                return $self->not_found($respond) unless @_;

                $self->handle_error(@_);
            }
          );
    };
}

1;
