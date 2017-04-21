package Crafty::Action::Build;

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

                my $content =
                  $self->render('build.caml', {build => $build->to_hash});

                $respond->([200, [], [$content]]);
            },
            sub {
                $respond->([404, [], ['Not found']]);
            }
        );
    };
}

1;
