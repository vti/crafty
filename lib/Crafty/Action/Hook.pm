package Crafty::Action::Hook;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

use Plack::Request;
use Crafty::Build;
use Crafty::AppConfig;
use Crafty::Builder;

sub run {
    my $self = shift;
    my (%params) = @_;

    my $app      = $params{app};
    my $provider = $params{provider};

    my $app_config = Crafty::AppConfig->new(root => $self->{root})->load($app);
    return [404, [], ["Unknown application `$app`"]] unless $app_config;

    if (!grep { $_->{provider} eq $provider } @{$app_config->{hooks} || []}) {
        return [404, [], ['Unknown hook provider']];
    }

    my $req = Plack::Request->new($self->env);

    my $params = $self->_build_action($provider, config => $app_config)
      ->parse($req->parameters);
    return [400, [], ['Bad Request']] unless $params;

    return sub {
        my $respond = shift;

        my $build = Crafty::Build->new(app => $app, %$params);

        $build->init;

        $self->db->save($build)->then(
            sub {
                my ($build) = @_;

                my $builder = Crafty::Builder->new(
                    app_config => $app_config,
                    root       => $self->{root}
                );

                $self->{builder} = $builder;

                my $promise = $builder->build(
                    $build,
                    on_pid => sub {
                        my ($pid) = @_;

                        $build->start($pid);

                        $self->db->save($build);
                    }
                );

                $respond->([200, [], ['ok']]);

                return $promise;
            },
            sub {
                $respond->([500, [], ['error']]);
            }
          )->then(
            sub {
                my ($build, $status) = @_;

                $build->finish($status);

                return $self->db->save($build);
            }
          );
    };
}

sub _build_action {
    my $self = shift;
    my ($action, @args) = @_;

    my $action_class = 'Crafty::Hook::' . ucfirst($action);

    Class::Load::load_class($action_class);

    return $action_class->new(@args);
}

1;
