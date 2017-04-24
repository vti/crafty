package Crafty::Config;
use Moo;

use YAML::Tiny;
use File::Spec;
use Kwalify;

has 'base',   is => 'ro', required => 1;
has 'root',   is => 'ro', required => 1;
has 'config', is => 'ro';

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

    $self->validate($self->{config});

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

sub schema {
    my $self = shift;

    my $schema_file = "$self->{root}/schema/config.yml";

    die "Can't load schema `$schema_file`: $!\n" unless -f $schema_file;

    my $yaml = YAML::Tiny->read($schema_file);
    return $yaml->[0];
}

sub validate {
    my $self = shift;
    my ($data) = @_;

    eval { Kwalify::validate($self->schema, $data); } or do {
        my $error = $@;

        $error =~ s/HASH\(0x.*?\)/\{\}/g;
        $error =~ s/ARRAY\(0x.*?\)/\[\]/g;

        die "Looks like your config file is not valid:\n\n$error";
    };

    return $data;
}

1;
