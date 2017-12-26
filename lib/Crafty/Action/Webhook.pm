package Crafty::Action::Webhook;
use Moo;
extends 'Crafty::Action::Base';

use Plack::App::WrapCGI;
use Plack::Util ();
use Crafty::Build;

sub run {
    my $self = shift;
    my (%params) = @_;

    my $provider = $params{provider};
    my $project  = $params{project};

    my $project_config = $self->config->project($project);
    return [ 404, [], ['Unknown project'] ] unless $project_config;

    my ($webhook_config) =
      grep { $_->{id} eq $provider } @{ $project_config->{webhooks} || [] };
    return [ 404, [], ['Unknown hook provider'] ] unless $webhook_config;

    return [ 500, [], ['Webhook script not executable'] ]
      unless -f $webhook_config->{cgi} && -x $webhook_config->{cgi};

    my $app = Plack::App::WrapCGI->new(script => $webhook_config->{cgi}, execute => 1)->to_app;

    my $res = $app->($self->env);
    return $res unless $res->[0] == 200;

    my $rev     = Plack::Util::header_get($res->[1], 'X-Crafty-Build-Rev');
    my $ref     = Plack::Util::header_get($res->[1], 'X-Crafty-Build-Ref');
    my $author  = Plack::Util::header_get($res->[1], 'X-Crafty-Build-Author');
    my $message = Plack::Util::header_get($res->[1], 'X-Crafty-Build-Message');

    return $res unless $rev && $ref && $author && $message;

    return sub {
        my $respond = shift;

        $self->db->find(where => [ project => $project_config->{id}, rev => $rev ])->then(
            sub {
                my ($builds) = @_;

                if (@$builds) {
                    if (my $existing_rev = $project_config->{existing_rev}) {
                        if ($existing_rev eq 'ignore') {
                            $respond->($res);

                            return;
                        }
                        elsif ($existing_rev eq 'error') {
                            $self->render(400, { error => 'Build with the same rev already exists' }, $respond);

                            return;
                        }
                    }
                }

                my $build = Crafty::Build->new(
                    project => $project,
                    rev     => $rev,
                    ref     => $ref,
                    author  => $author,
                    message => $message
                );

                $build->init;

                $self->db->save($build)->then(
                    sub {
                        $self->pool->peek;

                        $respond->($res);
                    }
                )->catch(sub { $self->handle_error(@_, $respond) });
            }
          );
    };
}

1;
