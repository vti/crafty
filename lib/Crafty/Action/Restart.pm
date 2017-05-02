package Crafty::Action::Restart;
use Moo;
extends 'Crafty::Action::API::RestartBuild';

sub content_type { 'text/html' }

1;
