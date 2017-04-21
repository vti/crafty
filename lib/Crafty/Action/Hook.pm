package Crafty::Action::Hook;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

use Data::UUID;
use Plack::Request;
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

    my $uuid = $self->_generate_id;

    return sub {
        my $respond = shift;

        $self->db->insert(
            %$params,
            'uuid' => $uuid,
            'app'  => $app,
            sub {
                my ($id) = @_;

                $self->broadcast('build.new', {});

                my $builder = Crafty::Builder->new(
                    app_config => $app_config,
                    root => $self->{root},
                    db   => $self->db
                );

                $builder->build(
                    $uuid,
                    sub {
                        my ($new_build) = @_;

                        $self->broadcast( 'build', $new_build );
                    }
                );

                $self->{builder} = $builder;

                $respond->([200, [], ['ok']]);
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

sub _generate_id {
    my $id = my $uuid = Data::UUID->new;
    return lc($uuid->to_string($uuid->create));
}

1;
