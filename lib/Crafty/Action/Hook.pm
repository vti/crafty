package Crafty::Action::Hook;

use strict;
use warnings;

use parent 'Crafty::Action::Base';

use YAML::Tiny;
use Plack::Request;
use Crafty::Runner;

sub run {
    my $self = shift;
    my (%params) = @_;

    my $app      = $params{app};
    my $provider = $params{provider};

    my $app_config_file = "$self->{root}/apps/$app.yml";
    return [404, [], ["Unknown application `$app`"]] unless -f $app_config_file;

    my $yaml       = YAML::Tiny->read($app_config_file);
    my $app_config = $yaml->[0];

    if (!grep { $_->{provider} eq $provider } @{$app_config->{hooks} || []}) {
        return [404, [], ['Unknown hook provider']];
    }

    my $req = Plack::Request->new($self->env);

    my $params = $self->_build_action($provider, config => $app_config)
      ->parse($req->parameters);
    return [400, [], ['Bad Request']] unless $params;

    my $uuid = $self->_generate_id;

    my $build_dir = "$self->{root}/data/builds/$uuid";
    my $stream    = "$self->{root}/data/builds/$uuid.log";

    return sub {
        my $respond = shift;

        $self->db->insert(
            %$params,
            'uuid'    => $uuid,
            'app'     => $app,
            'started' => time,
            'status'  => 'P',
            sub {
                my ($id) = @_;

                my $runner = Crafty::Runner->new(
                    build_dir => $build_dir,
                    stream    => $stream
                );
                $self->{runner} = $runner;

                foreach my $action (@{$app_config->{build}}) {
                    my ($key, $value) = %$action;

                    if ($key eq 'run') {
                        $runner->run(
                            cmd    => [$value],
                            on_error => sub {
                                $self->db->finish($id, status => 'E', sub {});
                            },
                            on_eof => sub {
                                my ($exit_code) = @_;

                                $self->db->finish($id, status => $exit_code ? 'F': 'S', sub {});
                            }
                        );
                    }
                }

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
