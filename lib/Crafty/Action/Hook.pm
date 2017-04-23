package Crafty::Action::Hook;
use Moo;
extends 'Crafty::Action::Base';

use Class::Load ();
use Crafty::Build;

sub run {
    my $self = shift;
    my (%params) = @_;

    my $provider = $params{provider};
    my $project  = $params{project};

    my $project_config = $self->config->project($project);
    return [404, [], ["Unknown project `$project`"]] unless $project_config;

    my ($webhook_config) =
      grep { $_->{provider} eq $provider } @{$project_config->{webhooks} || []};
    return [404, [], ['Unknown hook provider']] unless $webhook_config;

    my $params =
      $self->_build_hook_provider($provider, config => $webhook_config)
      ->parse($self->req->parameters);
    return [400, [], ['Bad Request']] unless $params;

    return sub {
        my $respond = shift;

        my $build = Crafty::Build->new(project => $project, %$params);

        $build->init;

        $self->db->save($build)->then(
            sub {
                $self->pool->build($build);

                $respond->([200, [], [$build->uuid]]);
            }
        )->catch(sub { $self->handle_error(@_) });
    };
}

sub _build_hook_provider {
    my $self = shift;
    my ($action, @args) = @_;

    my $action_class = 'Crafty::Hook::' . ucfirst($action);

    Class::Load::load_class($action_class);

    return $action_class->new(@args);
}

1;
