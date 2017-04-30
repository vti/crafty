package Crafty::Pool;
use Moo;

has 'config', is => 'ro', required => 1;
has 'db',     is => 'ro', required => 1;

use Promises qw(deferred);
use JSON ();
use AnyEvent::Fork;
use Crafty::Log;

sub start {
    my $self = shift;

    $self->{peek} = AnyEvent->timer(
        interval => 10,
        cb       => sub {
            $self->cleanup_locked->then(
                sub {
                    return $self->cleanup_running;
                }
              )->then(
                sub {
                    $self->peek;
                }
              );
        }
    );

    return $self;
}

sub cleanup_locked {
    my $self = shift;

    return $self->db->find(where => [ status => 'L' ])->then(
        sub {
            my ($builds) = @_;

            my @uuids;
            foreach my $build (@$builds) {
                if (!$build->pid) {
                    push @uuids, $build->uuid;
                }
                elsif (!kill 0, $build->pid) {
                    push @uuids, $build->uuid;
                }
            }

            return deferred->resolve unless @uuids;

            Crafty::Log->info('Cleaning builds (%d)', scalar @uuids);

            return $self->db->update_multi(\@uuids, status => 'K');
        }
    );
}

sub cleanup_running {
    my $self = shift;

    return $self->db->find(where => [ status => 'P' ])->then(
        sub {
            my ($builds) = @_;

            my @uuids;
            foreach my $build (@$builds) {
                if (!$build->pid) {
                    push @uuids, $build->uuid;
                }
                elsif (!kill 0, $build->pid) {
                    push @uuids, $build->uuid;
                }
            }

            return deferred->resolve unless @uuids;

            Crafty::Log->info('Cleaning builds (%d)', scalar @uuids);

            return $self->db->update_multi(\@uuids, status => 'K');
        }
    );
}

sub peek {
    my $self = shift;

    return if $self->{peeking};

    my $max_workers = $self->config->{config}->{pool}->{workers} // 4;

    return $self->db->count(where => [ status => [ 'L', 'P' ] ])->then(
        sub {
            my ($count) = @_;

            if ($max_workers && $max_workers <= $count) {
                return deferred->reject;
            }

            return $self->db->find(
                where    => [ status  => 'I' ],
                order_by => [ created => 'ASC' ],
                limit    => 1
            );
        }
      )->then(
        sub {
            my ($builds) = @_;

            return deferred->reject unless @$builds;

            return $self->db->lock($builds->[0]);
        }
      )->then(
        sub {
            my ($build, $locked) = @_;

            if ($locked) {
                $self->_build($build);
            }

            delete $self->{peeking};
        }
      )->catch(
        sub {
            delete $self->{peeking};
        }
      );
}

sub _build {
    my $self = shift;
    my ($build) = @_;

    my $project_config = $self->config->project($build->project);

    Crafty::Log->info('Build %s scheduled', $build->uuid);

    if ($self->config->config->{pool}->{mode} eq 'inproc') {
        require Crafty::Worker;
        Crafty::Worker::run(
            undef,
            JSON::encode_json($self->config->config),
            JSON::encode_json($project_config),
            $build->uuid
        );
    }
    else {
        AnyEvent::Fork->new->require('Crafty::Worker')->send_arg(JSON::encode_json($self->config->config))
          ->send_arg(JSON::encode_json($project_config))->send_arg($build->uuid)->run('Crafty::Worker::run');
    }
}

sub cancel {
    my $self = shift;
    my ($build) = @_;

    Crafty::Log->info('Canceling %s', $build->uuid);

    return $self->db->load($build->uuid)->then(
        sub {
            my ($build) = @_;

            if ($build->pid && kill 0, $build->pid) {
                return $self->_kill_build($build);
            }
            else {
                return deferred->reject($build);
            }
        }
      )->then(
        sub {
            my ($build) = @_;

            $build->cancel;

            return $self->db->save($build);
        }
      )->catch(
        sub {
            my ($build) = @_;

            $build->finish('K');

            return $self->db->save($build);
        }
      );
}

sub _kill_build {
    my $self = shift;
    my ($build) = @_;

    my $uuid = $build->uuid;
    my $pid  = $build->pid;

    my $deferred = deferred;

    kill 'INT', $pid;

    my $attempts = 0;
    my $t;
    $t = AnyEvent->timer(
        interval => 0.5,
        cb       => sub {
            if (kill 0, $pid) {
                $attempts++;

                if ($attempts > 5) {
                    Crafty::Log->info('Sending KILL to build %s', $uuid);

                    kill 'KILL', $pid;

                    Crafty::Log->info('Build %s killed', $uuid);
                }
                else {
                    Crafty::Log->info('Waiting for build %s to terminate [attempt %d]', $uuid, $attempts);
                }
            }
            else {
                Crafty::Log->info('Build %s terminated', $uuid);

                undef $t;

                return $deferred->resolve($build);
            }
        }
    );

    return $deferred->promise;
}

1;
