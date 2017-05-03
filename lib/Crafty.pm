package Crafty;
use Moo;

use Class::Load ();
use Routes::Tiny;
use Text::Caml;
use Plack::Builder;
use Crafty::DB;
use Crafty::Pool;
use Crafty::Password;

has 'root', is => 'ro', default => sub { '.' };
has 'config', is => 'ro', required => 1;
has 'db',
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;

    return Crafty::DB->new(
        config  => $self->config->config,
        db_file => $self->config->db_file
    );
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

    $routes->add_route('/login', name => 'Login');
    $routes->add_route('/logout', name => 'Logout', arguments => { access => 'private' });

    $routes->add_route('/',               method => 'GET',  name => 'Index');
    $routes->add_route('/builds/:uuid',   method => 'GET',  name => 'Build');
    $routes->add_route('/cancel/:uuid',   method => 'POST', name => 'Cancel', arguments => { access => 'private' });
    $routes->add_route('/download/:uuid', method => 'GET',  name => 'Download');
    $routes->add_route('/restart/:uuid',  method => 'POST', name => 'Restart', arguments => { access => 'private' });

    $routes->add_route(
        '/api/builds',
        method    => 'POST',
        name      => 'API::CreateBuild',
        arguments => { access => 'private' }
    );
    $routes->add_route('/api/builds',       method => 'GET', name => 'API::ListBuilds');
    $routes->add_route('/api/builds/:uuid', method => 'GET', name => 'API::GetBuild');
    $routes->add_route(
        '/api/builds/:uuid/cancel',
        method    => 'POST',
        name      => 'API::CancelBuild',
        arguments => { access => 'private' }
    );
    $routes->add_route(
        '/api/builds/:uuid/restart',
        method    => 'POST',
        name      => 'API::RestartBuild',
        arguments => { access => 'private' }
    );
    $routes->add_route('/api/builds/:uuid/tail', method => 'GET', name => 'API::BuildTail');
    $routes->add_route('/api/builds/:uuid/log',  method => 'GET', name => 'API::BuildLog');
    $routes->add_route('/api/events',            method => 'GET', name => 'API::WatchEvents');
    $routes->add_route(
        '/api/events',
        method    => 'POST',
        name      => 'API::CreateEvent',
        arguments => { access => 'private' }
    );

    $routes->add_route('/webhook/:provider/:project', name => 'Webhook');

    return $routes;
}

sub to_psgi {
    my $self = shift;

    my $view = $self->view;

    my $psgi = sub {
        my ($env) = @_;

        my $match = $env->{'crafty.route'};
        return [ 404, [], ['Not Found'] ] unless $match;

        my $action = $self->_build_action(
            $match->name,
            env    => $env,
            view   => $view,
            config => $self->config,
            db     => $self->db,
            pool   => $self->pool,
        );

        return $action->run(%{ $match->captures || {} });
    };

    return builder {
        enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' } 'ReverseProxy';

        enable 'Static',
          path => qr{^/(img|js|css|fonts)/},
          root => $self->root . '/public';

        enable 'Session::Cookie',
          session_key => 'crafty',
          expires     => 600,
          %{ $self->config->config->{access}->{session} // {} };

        enable '+Crafty::Middleware::Routes', routes => $self->build_routes;

        enable '+Crafty::Middleware::User', config => $self->config;

        enable '+Crafty::Middleware::Access',
          config => $self->config,
          denier => sub {
            my ($env) = @_;

            if ($env->{PATH_INFO} =~ m{^/api/}) {
                return [ 401, [], ['Authentication needed'] ];
            }

            return [ 302, [ Location => '/login' ], [] ];
          };

        return $psgi;
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
