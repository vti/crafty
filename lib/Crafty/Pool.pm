package Crafty::Pool;
use Moo;

has 'config', is => 'ro', required => 1;
has 'db',     is => 'ro', required => 1;
has 'on_destroy', is => 'ro';
has '_pool',      is => 'rw';

use AnyEvent::Fork;
use Crafty::Log;
use Crafty::Fork::Pool;

sub start {
    my $self = shift;

    $self->{status} = {};

    my $pool =
      AnyEvent::Fork->new->require('Crafty::Pool::Worker')
      ->Crafty::Fork::Pool::run(
        'Crafty::Pool::Worker::run',    # the worker function

        # pool management
        max   => 4,     # absolute maximum # of processes
        idle  => 4,     # minimum # of idle processes
        load  => 1,     # queue at most this number of jobs per process
        start => 0.1,   # wait this many seconds before starting a new process
        stop  => 10,    # wait this many seconds before stopping an idle process
        on_destroy => sub {
            Crafty::Log->info('Pool destroyed');

            $self->on_destroy->() if $self->on_destroy;
        },              # called when object is destroyed

        # parameters passed to AnyEvent::Fork::RPC
        async    => 1,
        on_error => sub {
            warn 'Worker exited';
        },
        on_event => sub { $self->_handle_worker_event(@_) },
        init       => 'Crafty::Pool::Worker::init',
        serialiser => $AnyEvent::Fork::RPC::JSON_SERIALISER,
      );

    $self->{cv} = AnyEvent->condvar;
    $self->_pool($pool);

    Crafty::Log->info('Pool started');

    #$self->_process_prepared;

    return $self;
}

sub stop {
    my $self = shift;

    $self->{cv}->recv;

    $self->_pool(undef);

    return $self;
}

sub build {
    my $self = shift;
    my ($build, $done) = @_;

    my $project_config = $self->config->project($build->project);

    Crafty::Log->info('Build %s scheduled', $build->uuid);

    $self->_pool->($build->to_hash, $project_config->{build}, $done || sub { });
}

sub cancel {
    my $self = shift;
    my ($build) = @_;

    foreach my $worker_id (keys %{$self->{status}}) {
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
        }
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
        where    => [status  => 'I'],
        order_by => [started => 'ASC'],
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

        Crafty::Log->info('Build %s forked', $uuid);

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
        Crafty::Log->info('Build %s errored');

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

    $self->{cv}->begin;
    $self->db->save($build)->then(sub { $self->{cv}->end });
}

1;
