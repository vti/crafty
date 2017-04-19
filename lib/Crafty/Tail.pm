package Crafty::Tail;

use strict;
use warnings;

use AnyEvent::Handle;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub tail {
    my $self = shift;
    my ($path, %params) = @_;

    AnyEvent::Fork->new->eval('
               # compile a helper function for later use
               sub run {
                  my ($fh, @cmd) = @_;

                  # perl will clear close-on-exec on STDOUT/STDERR
                  open STDOUT, ">&", $fh or die;
                  #open STDERR, ">&", $fh or die;

                  exec @cmd;
               }
            ')->send_arg('tail', '-f', '-n', '+1', $path)->run(
        'run',
        sub {
            my ($fh) = @_;

            my $handle;
            $handle = AnyEvent::Handle->new(
                fh       => $fh,
                on_error => sub {
                    $handle->destroy;

                    $params{on_error}->();
                },
                on_eof => sub {
                    $handle->destroy;

                    $params{on_eof}->();
                },
                on_read => sub {
                    my $content = $_[0]->rbuf;

                    $_[0]->rbuf = "";

                    $params{on_read}->($content);
                },
            );

            $self->{handle} = $handle;
        }
    );

    return $self;
}

1;
