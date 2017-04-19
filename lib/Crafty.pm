package Crafty;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Fork;
use Class::Load ();
use Routes::Tiny;
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

sub to_psgi {
    my $self = shift;

    my $routes = Routes::Tiny->new;

    $routes->add_route('/',                     name => 'Index');
    $routes->add_route('/builds/:build_id',     name => 'Build');
    $routes->add_route('/tail/:build_id',       name => 'Tail');
    $routes->add_route('/hooks/:app/:provider', name => 'Hook');

    my $view = Text::Caml->new(templates_path => "$self->{root}/templates");

    return sub {
        my ($env) = @_;

        my $path_info = $env->{PATH_INFO};

        my $match = $routes->match($path_info);

        if ($match) {
            my $action = $self->_build_action(
                $match->name,
                env  => $env,
                view => $view,
                root => $self->{root},
                db   => $self->{db}
            );

            return $action->run(%{$match->captures || {}});
        }
        else {
            return [404, [], ['Not Found']];
        }
    };
}

sub _build_action {
    my $self = shift;
    my ($action, @args) = @_;

    my $action_class = __PACKAGE__ . '::Action::' . $action;

    Class::Load::load_class($action_class);

    return $action_class->new(@args);
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

1;
