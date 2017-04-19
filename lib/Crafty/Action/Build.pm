package Crafty::Action::Build;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

sub run {
    my $self = shift;
    my (%params) = @_;

    my $id = $params{build_id};

    return sub {
        my $respond = shift;

        $self->db->build(
            $id,
            sub {
                my ($build) = @_;

                if ($build) {
                    my $content = $self->render('build.caml', {build => $build});

                    $respond->([200, [], [$content]]);
                }
                else {
                    $respond->([404, [], ['Not found']]);
                }
            }
        );

    };
}

1;
