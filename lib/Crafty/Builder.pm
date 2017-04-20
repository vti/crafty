package Crafty::Builder;

use strict;
use warnings;

use Crafty::Runner;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{root}       = $params{root};
    $self->{db}         = $params{db};
    $self->{app_config} = $params{app_config};

    return $self;
}

sub db { shift->{db} }

sub build {
    my $self = shift;
    my ($uuid, $cb) = @_;

    my $build_dir = "$self->{root}/data/builds/$uuid";
    my $stream    = "$self->{root}/data/builds/$uuid.log";

    my $runner = Crafty::Runner->new(
        build_dir => $build_dir,
        stream    => $stream
    );
    $self->{runner} = $runner;

    $self->db->start(
        $uuid,
        sub {
            foreach my $action (@{$self->{app_config}->{build}}) {
                my ($key, $value) = %$action;

                if ($key eq 'run') {
                    $runner->run(
                        cmd    => [$value],
                        on_pid => sub {
                            my ($pid) = @_;
                        },
                        on_error => sub {
                            $self->db->finish(
                                $uuid,
                                status => 'E',
                                sub { $cb->(@_) if $cb }
                            );
                        },
                        on_eof => sub {
                            my ($exit_code) = @_;

                            $self->db->finish(
                                $uuid,
                                status => $exit_code ? 'F' : 'S',
                                sub { $cb->(@_) if $cb }
                            );
                        }
                    );
                }
            }
        }
    );
}

1;
