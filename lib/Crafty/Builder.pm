package Crafty::Builder;
use Moo;

use Promises qw(deferred);
use AnyEvent;
use Crafty::Runner;

has 'config', is => 'ro', required => 1;
has 'db',     is => 'ro', required => 1;

sub watch {
    my $self = shift;

    $self->{t} = AnyEvent->timer(
        interval => 5,
        cb       => sub {
            warn 'INTERVAL';
            eval {
                $self->work_on_prepared;
                $self->work_on_canceled;
            } or do {
                warn $@
            };
        }
    );
}

sub work_on_prepared {
    my $self = shift;

    my $max_builders = 5;

    $self->db->find(where => [status => 'P'])->then(
        sub {
            my ($builds) = @_;

            if ($max_builders > @$builds) {
                return $self->db->find(
                    where    => [status  => 'I'],
                    order_by => [started => 'ASC'],
                    limit    => $max_builders - @$builds
                );
            }
            else {
                return deferred->reject;
            }
        }
      )->then(
        sub {
            my ($builds) = @_;

            foreach my $build (@$builds) {
                $self->build(
                    $build,
                    on_pid => sub {
                        my ($pid) = @_;

                        $build->start($pid);

                        $self->db->save($build);
                    }
                  )->then(
                    sub {
                        my ($build, $status) = @_;

                        $build->finish($status);

                        $self->db->save($build);
                    }
                  );
            }
        }
      );
}

sub work_on_canceled {
    my $self = shift;

    warn 'CANCEL';

    $self->db->find(where => [status => 'C'])->then(
        sub {
            my ($builds) = @_;

            Crafty::Log->info("Canceling %s build(s)", scalar(@$builds));

            foreach my $build (@$builds) {
                $self->cancel($build)->then(
                    sub {
                        $build->finish('K');

                        $self->db->save($build);
                    }
                );
            }
        }
    );
}

sub build {
    my $self = shift;
    my ($build, %params) = @_;

    my $build_dir = $self->config->catfile('builds_dir', $build->uuid);
    my $stream    = $self->config->catfile('builds_dir', $build->uuid . '.log');

    my $runner = Crafty::Runner->new(
        build_dir => $build_dir,
        stream    => $stream
    );
    $self->{runner} = $runner;

    my $project_config = $self->config->project($build->project);

    my $deferred = deferred;

    foreach my $action (@{$project_config->{build}}) {
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

    return deffered->resolve($build) unless my $pid = $build->pid;

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
