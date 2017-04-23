package Crafty::Action::Download;
use Moo;
extends 'Crafty::Action::Base';

use HTTP::Date ();
use Promises qw(deferred);

sub run {
    my $self = shift;
    my (%params) = @_;

    my $uuid = $params{build_id};

    return sub {
        my $respond = shift;

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                my $stream =
                  $self->config->catfile('builds_dir', $build->uuid . '.log');

                open my $fh, '<:raw', $stream
                  or return deferred->reject($self->not_found);

                my @stat = stat $stream;

                return $respond->(
                    [
                        200,
                        [
                            'Content-Type'   => 'text/plain',
                            'Content-Length' => $stat[7],
                            'Last-Modified'  => HTTP::Date::time2str($stat[9]),
                            'Content-Disposition' =>
                              "attachment; filename=$uuid.log"
                        ],
                        $fh
                    ]
                );
            },
            sub {
                return deferred->reject($self->not_found);
            }
          )->catch(
            sub {
                $self->handle_error(@_, $respond);
            }
          );
    };
}

1;
