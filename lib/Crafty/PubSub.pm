package Crafty::PubSub;
use Moo;

has '_pid', is => 'rw', default => sub { 0 };
has '_host',        is => 'rw';
has '_port',        is => 'rw';
has '_subscribers', is => 'ro', default => sub { {} };

use Promises qw(deferred collect);
use JSON ();
use AnyEvent::HTTP;
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

sub own {
    my $self = shift;
    my ($listen) = @_;

    $self->_pid($$);

    return $self;
}

sub address {
    my $self = shift;
    my ($listen) = @_;

    return unless $listen;

    my ($host, $port) = split /:/, $listen, 2;
    $host =~ s{^https?:\/\/}{};

    if ($host eq '0.0.0.0') {
        $host = '127.0.0.1';
    }

    $self->_host($host);
    $self->_port($port);

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
    elsif ($self->_host && $self->_port) {
        my $deferred = deferred;

        my $url = sprintf 'http://%s:%s/_event', $self->_host, $self->_port;

        my $body = JSON::encode_json([ $ev, $data ]);

        $self->_http_post(
            $url, $body,
            sub {
                $deferred->resolve;
            }
        );

        push @promises, $deferred->promise;
    }

    return collect(@promises);
}

sub _http_post {
    my $self = shift;
    my ($url, $body, $cb) = @_;

    http_post $url, $body, $cb;
}

1;
