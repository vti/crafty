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

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                die 'not found' unless $build && $build->cancel;

                return $self->db->save($build);
            },
            sub {
                $respond->([404, [], ['Not found']]);
            }
          )->then(
            sub {
                my ($build) = @_;

                my $app_config =
                  Crafty::AppConfig->new(root => $self->{root})
                  ->load($build->app);

                my $builder = Crafty::Builder->new(
                    app_config => $app_config,
                    root       => $self->{root}
                );

                $self->{builder} = $builder;

                return $builder->cancel($build);
            }
          )->then(
            sub {
                my ($build) = @_;

                $respond->([302, [Location => "/builds/$uuid"], ['']]);
            },
            sub {
                $respond->([500, [], ['error']]);
            }
          );
    };
}

1;
