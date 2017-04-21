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

                if ($build && $build->cancel) {
                    return $self->db->save($build);
                }
                else {
                    die 'not found';
                }
            },
            sub {
                $respond->([404, [], ['Not found']]);
            }
          )->then(
            sub {
                my ($build) = @_;

                $respond->([302, [Location => "/builds/$uuid"], ['']]);
            }
          );
    };
}

1;
