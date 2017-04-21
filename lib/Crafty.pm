package Crafty;

use strict;
use warnings;

use Class::Load ();
use Routes::Tiny;
use Text::Caml;
use Crafty::DB;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{root}        = $params{root};
    $self->{connections} = {};
    $self->{db} = Crafty::DB->new(dbpath => "$self->{root}/data/db.db");

    return $self;
}

sub to_psgi {
    my $self = shift;

    my $routes = Routes::Tiny->new;

    $routes->add_route('/',                     name => 'Index');
    $routes->add_route('/builds/:build_id',     name => 'Build');
    $routes->add_route('/tail/:build_id',       name => 'Tail');
    $routes->add_route('/cancel/:build_id',     name => 'Cancel');
    $routes->add_route('/restart/:build_id',    name => 'Restart');
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
                db   => $self->{db},
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

1;
