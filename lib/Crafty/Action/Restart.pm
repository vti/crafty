package Crafty::Action::Restart;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

use Crafty::AppConfig;
use Crafty::Builder;

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

                if ($build && $build->{status} ne 'P') {
                    my $app_config =
                      Crafty::AppConfig->new(root => $self->{root})
                      ->load($build->{app});

                    $self->db->restart(
                        $uuid,
                        sub {
                            my ($new_build) = @_;

                            my $builder = Crafty::Builder->new(
                                app_config => $app_config,
                                root       => $self->{root},
                                db         => $self->db
                            );

                            $self->broadcast('build', $new_build);

                            $builder->build(
                                $uuid,
                                sub {
                                    my ($new_build) = @_;

                                    $self->broadcast('build', $new_build);
                                }
                            );

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
