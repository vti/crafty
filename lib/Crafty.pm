package Crafty;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Fork;
use Text::Caml;
use JSON       ();
use Data::UUID ();
use Crafty::DB;
use Crafty::Tail;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{root}        = $params{root};
    $self->{connections} = {};
    $self->{workers}     = {};
    $self->{db}          = Crafty::DB->new(dbpath => "$self->{root}/data/db.db");

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

sub tail {
    my $self = shift;
    my ($conn, $env) = @_;

    my $connections = $self->{tails};

    my $tail = Crafty::Tail->new;
    $tail->tail(
        '/tmp/tail',
        on_error => sub {
            warn 'error';
            $conn->push(JSON::encode_json({type => 'error'}));
            $conn->close;
            delete $connections->{"$conn"};
        },
        on_eof => sub {
            warn 'eof';
            $conn->push(JSON::encode_json({type => 'eof'}));
            $conn->close;
            delete $connections->{"$conn"};
        },
        on_read => sub {
            my ($content) = @_;

            $content =~ s{\n}{\\n}g;

            $conn->push(JSON::encode_json({type => 'output', data => $content}));
        }
    );

    $connections->{"$conn"} = {
        conn      => $conn,
        tail      => $tail,
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
      ->send_arg('seq 1 10 | while read i; do date; sleep 1; done')->run(
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

    my $view = Text::Caml->new(templates_path => "$root/templates");

    return sub {
        my ($env) = @_;

        my $path_info = $env->{PATH_INFO};

        my $content;
        if ($path_info =~ m{^/builds/(.*)}) {
            my $id = $1;

            return sub {
                my $respond = shift;

                $self->{db}->build(
                    $id,
                    sub {
                        my ($build) = @_;

                        if ($build) {
                            $content = $view->render_file('build.caml',
                                {build => $build});

                            my $output = $view->render_file('layout.caml',
                                {content => $content});

                            $respond->([200, [], [$output]]);
                        }
                        else {
                            $respond->([404, [], ['Not found']]);
                        }
                    }
                );

            };
        }
        elsif ($path_info eq '/') {
            return sub {
                my $respond = shift;

                $self->{db}->builds(
                    sub {
                        my ($builds) = @_;

                        $content = $view->render_file(
                            'index.caml',
                            {
                                title  => 'Hello',
                                body   => 'there!',
                                builds => $builds
                            }
                        );

                        my $output = $view->render_file('layout.caml',
                            {content => $content});

                        $respond->([200, [], [$output]]);
                    }
                );

            };
        }
        else {
            return [404, [], ['Not found']];
        }

        #my $output = $view->render_file('layout.caml', {content => $content});

        #return [200, [], [$output]];
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
