package Crafty::Action::Index;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

sub run {
    my $self = shift;

    return sub {
        my $respond = shift;

        $self->db->find->then(
            sub {
                my ($builds) = @_;

                my $content = $self->render(
                    'index.caml',
                    {
                        title  => 'Hello',
                        body   => 'there!',
                        builds => [map { $_->to_hash } @$builds]
                    }
                );

                $respond->([200, [], [$content]]);
            }
        );

    };
}

1;
