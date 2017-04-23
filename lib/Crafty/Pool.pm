package Crafty::Pool;
use Moo;

has 'config', is => 'ro', required => 1;
has 'db',     is => 'ro', required => 1;
has '_pool',  is => 'rw';

use AnyEvent::Fork;
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
            warn 'DESTROY';
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

    $self->_pool($pool);

    #$self->_process_prepared;

    return $self;
}

sub build {
    my $self = shift;
    my ($build) = @_;

    my @pool  = @Crafty::Fork::Pool::pool;
    my @queue = @Crafty::Fork::Pool::queue;

    Crafty::Log->info('Build %s scheduled', $build->uuid);

    $self->_pool->($build->to_hash, sub { });
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

                kill 'INT', $worker->{pid};

                my $attempts = 0;
                $worker->{t} = AnyEvent->timer(
                    interval => 0.5,
                    cb       => sub {
                        if (kill 0, $worker->{pid}) {
                            $attempts++;

                            if ($attempts > 5) {
                                Crafty::Log->info('Sending KILL to build %s',
                                    $build->uuid);

                                kill 'KILL', $worker->{pid};

                                Crafty::Log->info('Build %s killed',
                                    $build->uuid);
                            }
                            else {
                                Crafty::Log->info(
'Waiting for build %s to terminate [attempt %d]',
                                    $build->uuid, $attempts
                                );
                            }
                        }
                        else {
                            Crafty::Log->info('Build %s terminated',
                                $build->uuid);

                            delete $worker->{t};
                        }
                    }
                );
            }
            else {
                Crafty::Log->info('Build %s already finished', $build->uuid);
            }
        }
    }
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

                $self->db->save($build);
            }
        );

        $worker->{status} = 'started';
    }
    elsif ($ev eq 'build.pid') {
        Crafty::Log->info('Build %s forked', $uuid);

        $worker->{status} = 'forked';

        $worker->{pid} = $args[0];
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

                $self->db->save($build);
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

                $self->db->save($build);
            }
        );

        delete $self->{status}->{$worker_id}->{$uuid};
    }
}

1;
