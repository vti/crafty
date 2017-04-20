package Crafty::AppConfig;

use strict;
use warnings;

use YAML::Tiny;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{root} = $params{root};

    return $self;
}

sub load {
    my $self = shift;
    my ($app) = @_;

    my $app_config_file = "$self->{root}/data/apps/$app.yml";
    return unless -f $app_config_file;

    my $yaml       = YAML::Tiny->read($app_config_file);
    my $app_config = $yaml->[0];

    return $app_config;
}

1;
