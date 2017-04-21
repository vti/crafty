package Crafty::Builder;

use strict;
use warnings;

use Promises qw(deferred);
use Crafty::Runner;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{root}       = $params{root};
    $self->{app_config} = $params{app_config};

    return $self;
}

sub build {
    my $self = shift;
    my ($build) = @_;

    my $build_dir = sprintf "$self->{root}/data/builds/%s",     $build->uuid;
    my $stream    = sprintf "$self->{root}/data/builds/%s.log", $build->uuid;

    my $runner = Crafty::Runner->new(
        build_dir => $build_dir,
        stream    => $stream
    );
    $self->{runner} = $runner;

    my $deferred = deferred;

    foreach my $action (@{$self->{app_config}->{build}}) {
        my ($key, $value) = %$action;

        if ($key eq 'run') {
            $runner->run(
                cmd    => [$value],
                on_pid => sub {
                    my ($pid) = @_;
                },
                on_error => sub {
                    $deferred->resolve($build, 'E');
                },
                on_eof => sub {
                    my ($exit_code) = @_;

                    $deferred->resolve($build, $exit_code ? 'F' : 'S');
                }
            );
        }
    }

    return $deferred->promise;
}

1;
