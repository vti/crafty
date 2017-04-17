package Crafty;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Fork;
use Text::Caml;
use JSON       ();
use Data::UUID ();
use Crafty::DB;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    $self->{connections} = {};
    $self->{workers}     = {};
    $self->{db}          = Crafty::DB->new;

    return $self;
}

sub new_conn {
    my $self = shift;
    my ($conn, $env) = @_;

    my $connections = $self->{connections};

    $connections->{"$conn"} = {
        conn      => $conn,
        heartbeat => AnyEvent->timer(
            interval => 30,
            cb       => sub {
                eval {
                    $conn->push('');
                    1;
                } or do {
                    delete $connections->{"$conn"};
                };
            }
        )
    };
}

sub hook {
    my $self = shift;
    my ($env) = @_;

    my $id = $self->_generate_id;

    $self->{db}->insert();

    AnyEvent::Fork->new->require('Crafty::Worker')
      ->send_arg('date; sleep 1; date; sleep 1; date')->run(
        'Crafty::Worker::work',
        sub {
            my ($fh) = @_;

            my $io;
            $io = AnyEvent::Handle->new(
                fh       => $fh,
                on_error => sub {
                    my ($hdl, $fatal, $msg) = @_;

                    delete $self->{workers}->{"$io"};

                    warn 'ERORR';

                    $hdl->destroy;
                },
                on_eof => sub {
                    my ($hdl) = @_;

                    delete $self->{workers}->{"$io"};

                    warn 'EOF';

                    $hdl->destroy;
                }
            );

            $self->{workers}->{"$io"} = $io;

            $io->on_read(
                sub {
                    my $output = $_[0]->rbuf;
                    $_[0]->rbuf = '';

                    $self->broadcast('build.status', $id, {output => $output});
                }
            );

        }
      );

    return [200, [], ['ok']];
}

sub to_psgi {
    my $self = shift;

    my $view = Text::Caml->new(templates_path => 'templates');

    return sub {
        my ($env) = @_;

        my $path_info = $env->{PATH_INFO};

        my $content;
        if ($path_info =~ m{^/builds/(.*)}) {
            $content = 'build';
        }
        else {
            $content = $view->render_file('index.caml',
                {title => 'Hello', body => 'there!'});
        }

        my $output = $view->render_file('layout.caml', {content => $content});

        return [200, [], [$output]];
    };
}

sub broadcast {
    my $self = shift;
    my ($event, $id, $data) = @_;

    $data //= {};

    $self->_broadcast({type => $event, data => {id => $id, %$data}});
}

sub _broadcast {
    my $self = shift;
    my ($event) = @_;

    $event = JSON::encode_json($event);

    my $connections = $self->{connections};

    my @conn_keys = keys %$connections;

    foreach my $conn_key (@conn_keys) {
        my $conn_info = $connections->{$conn_key};
        my $conn      = $conn_info->{conn};

        eval {
            $conn->push($event);
            1;
        } or do {
            delete $connections->{$conn_key};
            $conn->close;
        };
    }
}

sub _generate_id {
    my $id = my $uuid = Data::UUID->new;
    return lc($uuid->to_string($uuid->create));
}

1;
