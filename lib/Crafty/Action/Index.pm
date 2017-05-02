package Crafty::Action::Index;
use Moo;
extends 'Crafty::Action::API::ListBuilds';

sub content_type { 'text/html' }

1;
