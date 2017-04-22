package Crafty::Action::Download;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

use HTTP::Date ();

sub run {
    my $self = shift;
    my (%params) = @_;

    my $uuid = $params{build_id};

    return sub {
        my $respond = shift;

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                my $stream = sprintf "$self->{root}/data/builds/%s.log", $build->uuid;

                open my $fh, '<:raw', $stream
                  or return $respond->([404, [], ['Not Found']]);

                my @stat = stat $stream;

                $respond->(
                    [
                        200,
                        [
                            'Content-Type'   => 'text/plain',
                            'Content-Length' => $stat[7],
                            'Last-Modified'  => HTTP::Date::time2str($stat[9]),
                            'Content-Disposition' => "attachment; filename=$uuid.log"
                        ],
                        $fh
                    ]
                );
            },
            sub {
                $respond->([404, [], ['Not found']]);
            }
          );
    };
}

1;
