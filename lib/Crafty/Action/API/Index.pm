package Crafty::Action::API::Index;
use Moo;
extends 'Crafty::Action::API::Base';

sub run {
    my $self = shift;

    $self->render(
        200,
        {
            title         => 'Crafty REST API',
            documentation => 'https://github.com/vti/crafty',
            resources     => [
                {
                    href   => '/api',
                    rel    => 'index',
                    method => 'GET'
                },
                {
                    href   => '/api/builds',
                    rel    => 'builds',
                    method => 'GET'
                },
                {
                    href   => '/api/builds',
                    rel    => 'create_build',
                    method => 'POST'
                },
                {
                    href   => '/api/builds/:uuid',
                    rel    => 'build',
                    method => 'GET'
                },
                {
                    href   => '/api/builds/:uuid/cancel',
                    rel    => 'cancel_build',
                    method => 'POST'
                },
                {
                    href   => '/api/builds/:uuid/log',
                    rel    => 'build_log',
                    method => 'GET'
                },
                {
                    href   => '/api/builds/:uuid/tail',
                    rel    => 'build_tail',
                    method => 'GET'
                },
                {
                    href   => '/api/events',
                    rel    => 'events',
                    method => 'GET'
                },
                {
                    href   => '/api/events',
                    rel    => 'create_event',
                    method => 'POST'
                },
            ]
        }
    );
}

1;
