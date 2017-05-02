package Crafty::Action::API::BuildLog;
use Moo;
extends 'Crafty::Action::API::Base';

use HTTP::Date ();
use Promises qw(deferred);

sub run {
    my $self = shift;
    my (%captures) = @_;

    my $uuid = $captures{uuid};

    return sub {
        my $respond = shift;

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                my $stream = $self->config->catfile('builds_dir', $build->uuid . '.log');

                open my $fh, '<:raw', $stream
                  or return deferred->reject($self->not_found($respond));

                my @stat = stat $stream;

                return $respond->(
                    [
                        200,
                        [
                            'Content-Type'        => 'text/plain',
                            'Content-Length'      => $stat[7],
                            'Last-Modified'       => HTTP::Date::time2str($stat[9]),
                            'Content-Disposition' => "attachment; filename=$uuid.log"
                        ],
                        $fh
                    ]
                );
            },
            sub {
                return deferred->reject($self->not_found($respond));
            }
          )->catch(
            sub {
                $self->handle_error(@_, $respond);
            }
          );
    };
}

1;
