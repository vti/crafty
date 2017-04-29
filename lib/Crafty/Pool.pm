package Crafty::Pool;
use Moo;

has 'config', is => 'ro', required => 1;
has 'db',     is => 'ro', required => 1;
has '_on_destroy', is => 'rw';
has '_pool',       is => 'rw';

use AnyEvent::Fork;
use AnyEvent::Fork::Pool;
use Crafty::Log;
use Crafty::Fork::Pool;

sub start {
    my $self = shift;

    $self->{status} = {};

    my $workers = $self->config->{config}->{pool}->{workers}
      // scalar AnyEvent::Fork::Pool::ncpu [4];

    my $pool =
      AnyEvent::Fork->new->require('Crafty::Pool::Worker')
      ->Crafty::Fork::Pool::run(
        'Crafty::Pool::Worker::run',
        max        => $workers,
        idle       => $workers,
        load       => 1,
        start      => 0.1,
        stop       => 2,
        on_destroy => sub {
            Crafty::Log->info('Pool destroyed');

            $self->_on_destroy->() if $self->_on_destroy;
        },
        async    => 1,
        on_error => sub {
            Crafty::Log->info('Worker exited');
        },
        on_event => sub { $self->_handle_worker_event(@_) },
        init       => 'Crafty::Pool::Worker::init',
        serialiser => $AnyEvent::Fork::RPC::JSON_SERIALISER,
      );

    $self->_pool($pool);

    Crafty::Log->info('Pool started with %s worker(s)', $workers);

    #$self->_process_prepared;

    return $self;
}

sub stop {
    my $self = shift;
    my ($done) = @_;

    if ($self->_pool) {
        if (my @queue = @Crafty::Fork::Pool::queue) {
            Crafty::Log->info('Cleaning up queue (%s)', scalar(@queue));

            @Crafty::Fork::Pool::queue = ();
        }

        my $workers = $self->{status};

        my @waitlist;
        if (%$workers) {
            foreach my $worker_pid (keys %$workers) {
                my $uuid = $workers->{$worker_pid}->{uuid};
                my $pid  = $workers->{$worker_pid}->{pid};

                if ($pid && kill 0, $pid) {
                    push @waitlist, { uuid => $uuid, pid => $pid };
                }
            }
        }

        if (@waitlist) {
            Crafty::Log->info('Waiting for workers to finish (%s)',
                scalar(@waitlist));

            $self->{t} = AnyEvent->timer(
                interval => 2,
                cb       => sub {
                    foreach my $wait (@waitlist) {
                        if (kill 0, $wait->{pid}) {
                            Crafty::Log->info("Waiting for $wait->{pid}...");
                            return;
                        }
                    }

                    delete $self->{t};

                    $self->{cv}->recv if $self->{cv};

                    $self->_on_destroy(sub { $done->() if $done });
                    $self->_pool(undef);
                }
            );
        }
        else {
            $self->{cv}->recv if $self->{cv};

            $self->_on_destroy(sub { $done->() if $done });
            $self->_pool(undef);
        }
    }

    return $self;
}

sub build {
    my $self = shift;
    my ($build, $done) = @_;

    my $project_config = $self->config->project($build->project);

    Crafty::Log->info('Build %s scheduled', $build->uuid);

    $self->_pool->(
        $self->config->{config}->{pool}, $build->to_hash,
        $project_config->{build}, $done || sub { }
    );
}

sub cancel {
    my $self = shift;
    my ($build) = @_;

    my $canceled = 0;
    foreach my $worker_id (keys %{ $self->{status} }) {
        my $worker = $self->{status}->{$worker_id};

        Crafty::Log->info('Canceling build %s', $build->uuid);

        if ($worker->{uuid} eq $build->uuid) {
            if ($worker->{status} eq 'forked') {
                $worker->{status} = 'killing';

                Crafty::Log->info('Sending INT to build %s', $build->uuid);

                $self->_kill_build($worker);
            }
            else {
                Crafty::Log->info('Build %s already finished', $build->uuid);
            }

            $canceled++;
            last;
        }
    }

    if (!$canceled) {
        Crafty::Log->info('Build %s unknown to pool, removing', $build->uuid);

        $build->finish('K');
        $self->_sync_build($build);
    }
}

sub _kill_build {
    my $self = shift;
    my ($worker) = @_;

    my $uuid = $worker->{uuid};

    kill 'INT', $worker->{pid};

    my $attempts = 0;
    $worker->{t} = AnyEvent->timer(
        interval => 0.5,
        cb       => sub {
            if (kill 0, $worker->{pid}) {
                $attempts++;

                if ($attempts > 5) {
                    Crafty::Log->info('Sending KILL to build %s', $uuid);

                    kill 'KILL', $worker->{pid};

                    Crafty::Log->info('Build %s killed', $uuid);
                }
                else {
                    Crafty::Log->info(
                        'Waiting for build %s to terminate [attempt %d]',
                        $uuid, $attempts);
                }
            }
            else {
                Crafty::Log->info('Build %s terminated', $uuid);

                delete $worker->{t};
            }
        }
    );
}

sub _process_prepared {
    my $self = shift;

    $self->db->find(
        where    => [ status  => 'I' ],
        order_by => [ started => 'ASC' ],
      )->then(
        sub {
            my ($builds) = @_;

            $self->build($_) for @$builds;
        }
      );

}

sub _handle_worker_event {
    my $self = shift;
    my ($worker_id, $ev, $uuid, @args) = @_;

    my $worker = $self->{status}->{$worker_id} //= {};

    $worker->{uuid} = $uuid;

    $self->{cv} //= AnyEvent->condvar;

    $self->{cv}->begin;

    if ($ev eq 'build.started') {
        Crafty::Log->info('Build %s started', $uuid);

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                $build->start;

                $self->_sync_build($build);
            }
        );

        $worker->{status} = 'started';
    }
    elsif ($ev eq 'build.pid') {
        my $pid = $args[0];

        Crafty::Log->info('Build %s forked (%s)', $uuid, $pid);

        $worker->{status} = 'forked';

        $worker->{pid} = $pid;

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                $build->pid($pid);

                $self->_sync_build($build);
            }
        );
    }
    elsif ($ev eq 'build.done') {
        my $exit_code = $args[0];

        my $final_status = defined $exit_code ? $exit_code ? 'F' : 'S' : 'K';

        Crafty::Log->info('Build %s finished with status %s',
            $uuid, $final_status);

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                $build->finish($final_status);

                $self->_sync_build($build);
            }
        );

        delete $self->{status}->{$worker_id}->{$uuid};
    }
    elsif ($ev eq 'build.error') {
        my $error = $args[0];

        Crafty::Log->error($error);

        Crafty::Log->info('Build %s errored', $uuid);

        $self->db->load($uuid)->then(
            sub {
                my ($build) = @_;

                $build->finish('E');

                $self->_sync_build($build);
            }
        );

        delete $self->{status}->{$worker_id}->{$uuid};
    }
}

sub _sync_build {
    my $self = shift;
    my ($build) = @_;

    $self->db->save($build)->then(sub { $self->{cv}->end });
}

1;
