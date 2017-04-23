package Crafty;
use Moo;

use Class::Load ();
use Routes::Tiny;
use Text::Caml;
use Crafty::DB;
use Crafty::Pool;

has 'root', is => 'ro', default => sub { '.' };
has 'config', is => 'ro', required => 1;
has 'db',
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;

    return Crafty::DB->new(db_file => $self->config->db_file);
  };
has 'view',
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;

    return Text::Caml->new(templates_path => $self->root . '/templates');
  };
has 'pool',
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;

    return Crafty::Pool->new(config => $self->config, db => $self->db);
  };

sub BUILD {
    my $self = shift;

    $self->pool->start;
}

sub build_routes {
    my $self = shift;

    my $routes = Routes::Tiny->new;

    $routes->add_route('/',                   name => 'Index');
    $routes->add_route('/builds/:build_id',   name => 'Build');
    $routes->add_route('/tail/:build_id',     name => 'Tail');
    $routes->add_route('/cancel/:build_id',   name => 'Cancel');
    $routes->add_route('/download/:build_id', name => 'Download');
    $routes->add_route('/restart/:build_id',  name => 'Restart');

    $routes->add_route('/webhook/:provider/:project', name => 'Hook');

    return $routes;
}

sub to_psgi {
    my $self = shift;

    my $routes = $self->build_routes;
    my $view   = $self->view;

    return sub {
        my ($env) = @_;

        my $path_info = $env->{PATH_INFO};

        my $match = $routes->match($path_info);

        if ($match) {
            my $action = $self->_build_action(
                $match->name,
                env    => $env,
                view   => $view,
                config => $self->config,
                db     => $self->db,
                pool   => $self->pool,
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
