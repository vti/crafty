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
    my $branch  = Plack::Util::header_get($res->[1], 'X-Crafty-Build-Branch');
    my $author  = Plack::Util::header_get($res->[1], 'X-Crafty-Build-Author');
    my $message = Plack::Util::header_get($res->[1], 'X-Crafty-Build-Message');

    return $res unless $rev && $branch && $author && $message;

    return sub {
        my $respond = shift;

        my $build = Crafty::Build->new(
            project => $project,
            rev     => $rev,
            branch  => $branch,
            author  => $author,
            message => $message
        );

        $build->init;

        $self->db->save($build)->then(
            sub {
                $self->pool->peek;

                $res->[2]->[0] = JSON::encode_json({ uuid => $build->uuid, content => $res->[2]->[0] });

                $respond->($res);
            }
        )->catch(sub { $self->handle_error(@_) });
    };
}

1;
