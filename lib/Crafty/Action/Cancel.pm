package Crafty::Action::Cancel;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

sub run {
    my $self = shift;
    my (%params) = @_;

    my $uuid = $params{build_id};

    return sub {
        my $respond = shift;

        $self->db->build(
            $uuid,
            sub {
                my ($build) = @_;

                if ($build && ($build->{status} eq 'P' || $build->{status} eq 'N')) {
                    $self->db->finish(
                        $uuid,
                        status => 'C',
                        sub {
                            my ($new_build) = @_;

                            $self->broadcast('build', $new_build);

                            $respond->(
                                [302, [Location => "/builds/$uuid"], ['']]);
                        }
                    );
                }
                else {
                    $respond->([404, [], ['Not found']]);
                }
            }
        );
    };
}

1;
