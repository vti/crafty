package Crafty::Action::Index;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

sub run {
    my $self = shift;

    return sub {
        my $respond = shift;

        $self->db->builds(
            sub {
                my ($builds) = @_;

                my $content = $self->render(
                    'index.caml',
                    {
                        title  => 'Hello',
                        body   => 'there!',
                        builds => $builds
                    }
                );

                $respond->([200, [], [$content]]);
            }
        );

    };
}

1;
