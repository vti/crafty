package Crafty::Builder;

use strict;
use warnings;

use Promises qw(deferred);
use AnyEvent;
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
    my ($build, %params) = @_;

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

                    $params{on_pid}->($pid) if $params{on_pid};
                },
                on_error => sub {
                    $deferred->resolve($build, 'E');
                },
                on_eof => sub {
                    my ($exit_code) = @_;

                    if (defined $exit_code) {
                        $deferred->resolve($build, $exit_code ? 'F' : 'S');
                    }
                    else {
                        $deferred->resolve($build, 'K');
                    }
                }
            );
        }
    }

    return $deferred->promise;
}

sub cancel {
    my $self = shift;
    my ($build) = @_;

    return deffered->promise->resolve unless my $pid = $build->pid;

    my $deferred = deferred;

    kill 'INT', $pid;

    $self->{t} = AnyEvent->timer(
        after => 1,
        cb    => sub {
            if (kill 0, $pid) {
                kill 'KILL', $pid;
            }

            $deferred->resolve($build);
        }
    );

    return $deferred->promise;
}

1;
