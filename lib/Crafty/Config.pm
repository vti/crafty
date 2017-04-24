package Crafty::Config;

use strict;
use warnings;

use YAML::Tiny;
use File::Spec;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{base}   = $params{base};
    $self->{config} = $params{config};

    return $self;
}

sub project {
    my $self = shift;
    my ($id) = @_;

    my $projects = $self->{config}->{projects} || [];

    my ($project) = grep { $_->{id} eq $id } @$projects;

    return $project;
}

sub db_file {
    my $self = shift;

    return $self->{config}->{db_file};
}

sub builds_dir {
    my $self = shift;

    return $self->{config}->{builds_dir};
}

sub load {
    my $self = shift;
    my ($config_file) = @_;

    die "Can't load config `$config_file`: $!\n" unless -f $config_file;

    my $yaml = YAML::Tiny->read($config_file);
    $self->{config} = $yaml->[0];

    $self->{config}->{db_file} =
      $self->resolve_path($self->{config}->{db_file}, 'db.db');
    $self->{config}->{builds_dir} =
      $self->resolve_path($self->{config}->{builds_dir}, 'builds');

    return $self->{config};
}

sub resolve_path {
    my $self = shift;
    my ($path, $default) = @_;

    $path //= $default;

    if (!File::Spec->file_name_is_absolute($path)) {
        $path = "$self->{base}/$path";
    }

    return $path;
}

sub catfile {
    my $self = shift;
    my ($option, @path) = @_;

    return File::Spec->catfile($self->{config}->{$option}, @path);
}

1;
