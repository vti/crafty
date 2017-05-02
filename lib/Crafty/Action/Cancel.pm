package Crafty::Action::Cancel;
use Moo;
extends 'Crafty::Action::API::CancelBuild';

sub content_type { 'text/html' }

1;
