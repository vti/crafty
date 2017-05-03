package Crafty::PubSub;
use Moo;

has '_sock',        is => 'rw';
has '_pid',         is => 'rw', default => sub { 0 };
has '_subscribers', is => 'ro', default => sub { {} };

use Promises qw(deferred collect);
use JSON ();
use AnyEvent::HTTP;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Crafty::Log;

our $INSTANCE;

sub clear {
    my ($class) = @_;

    $INSTANCE = undef;

    return $class;
}

sub instance {
    my ($class) = @_;

    $INSTANCE ||= $class->new;

    return $INSTANCE;
}

sub listen {
    my $self = shift;
    my ($sock) = @_;

    $self->_pid($$);
    $self->_sock($sock);

    if ($self->_sock) {
        Crafty::Log->info('Creating sock file %s', $self->_sock);

        $self->{server} = tcp_server 'unix/', $self->_sock, sub {
            my ($fh) = @_ or die "Can't open sock file: $!";

            my $handle;
            $handle = AnyEvent::Handle->new(
                fh       => $fh,
                on_error => sub {
                    $_[0]->destroy;
                },
                on_eof => sub {
                    $handle->destroy;
                },
                on_read => sub {
                    my $content = $_[0]->rbuf;

                    $handle->push_read(
                        json => sub {
                            my ($handle, $msg) = @_;

                            $self->publish(@$msg);
                        }
                    );
                }
            );
        }, sub {
            Crafty::Log->info('Sock created');
        };
    }

    return $self;
}

sub connect {
    my $self = shift;
    my ($sock) = @_;

    $self->_sock($sock);

    return $self;
}

sub subscribe {
    my $self = shift;
    my ($ev, $cb) = @_;

    push @{ $self->_subscribers->{$ev} }, $cb;

    return $self;
}

sub publish {
    my $self = shift;
    my ($ev, $data) = @_;

    my @promises;

    if ($self->_pid == $$) {
        my @subscribers = @{ $self->_subscribers->{$ev} || [] };
        push @subscribers, @{ $self->_subscribers->{'*'} || [] };

        foreach my $subscriber (@subscribers) {
            push @promises, $subscriber->($ev, $data);
        }
    }
    elsif ($self->_sock) {
        push @promises, $self->_push_event([$ev, $data]);
    }

    return collect(@promises);
}

sub _push_event {
    my $self = shift;
    my ($body) = @_;

    my $deferred = deferred;

    tcp_connect 'unix/', $self->_sock, sub {
        my ($fh) = @_ or return $deferred->reject;

        my $handle;
        $handle = AnyEvent::Handle->new(
            fh       => $fh,
            on_error => sub {
                $_[0]->destroy;
            },
            on_eof => sub {
                $handle->destroy;
            }
        );

        $handle->push_write(json => $body);

        return $deferred->resolve;
    };

    return $deferred->promise;
}

1;
