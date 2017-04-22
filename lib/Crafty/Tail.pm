package Crafty::Tail;

use strict;
use warnings;

use AnyEvent::Handle;
use AnyEvent::Fork;

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
               sub run {
                  my ($fh, @cmd) = @_;

                  open STDOUT, ">&", $fh or die;
                  #open STDERR, ">&", $fh or die;

                  exec @cmd or die $!;
               }
            ')->send_arg('tail', '-f', '-n', '10000', $path)->run(
        'run',
        sub {
            my ($fh) = @_;

            my $handle;
            $handle = AnyEvent::Handle->new(
                fh       => $fh,
                on_error => sub {
                    my ($handle, $fatal, $msg) = @_;

                    $handle->destroy;
                    delete $self->{handle};

                    $params{on_error}->();
                },
                on_eof => sub {
                    $handle->destroy;
                    delete $self->{handle};

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

sub DESTROY { "TAIL DESTROY" }

1;
