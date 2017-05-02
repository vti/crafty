package Crafty::Action::API::Base;
use Moo;

use Plack::Request;
use JSON ();

has 'config', is => 'ro', required => 1;
has 'env',    is => 'ro', required => 1;
has 'db',     is => 'ro', required => 1;
has 'pool',   is => 'ro';
has 'view',   is => 'ro', required => 1;
has 'req',
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;

    return Plack::Request->new($self->env);
  };

sub content_type { 'application/json' }

sub render {
    my $self = shift;
    my ($code, $body, $respond) = @_;

    my $headers = [];

    if ($self->content_type eq 'text/html') {
        if ($body && ref $body && !$body->{ok}) {
            my $template = lc((split /::/, ref($self))[-1]) . '.caml';

            my $content = $self->view->render_file($template, $body);
            $body = $self->view->render_file('layout.caml', { content => $content });
        }
    }
    elsif ($self->content_type eq 'application/json') {
        push @$headers, 'Content-Type' => 'application/json';

        $body = JSON::encode_json($body);
    }
    else {
        die 'Unknown content type';
    }

    my $res = [ $code, $headers, [$body] ];

    return $respond ? $respond->($res) : $res;
}

sub not_found {
    my $self = shift;
    my ($respond) = @_;

    return $self->render(404, { error => 'Not Found' }, $respond);
}

sub redirect {
    my $self = shift;
    my ($url, $respond) = @_;

    my $res = [ 302, [ Location => $url ], [''] ];

    return $respond ? $respond->($res) : $res;
}

sub handle_error {
    my $self = shift;
    my ($error, $respond) = @_;

    Crafty::Log->error(@_) unless ref $error;

    my $res;
    eval { $res = ref $error ? $error : $self->render(500, { error => 'System error' }); } or do {
        Crafty::Log->error($@);

        $res = [ 500, [], ['System error'] ];
    };

    return $respond ? $respond->($res) : $res;
}

1;
