package Crafty::Worker;
use Moo;

use POSIX ();
use JSON  ();
use Crafty::PubSub;
use Crafty::DB;
use Crafty::Runner;
use Crafty::Build;
use Crafty::Config;

has 'config',         is => 'ro', required => 1;
has 'project_config', is => 'ro', required => 1;
has 'uuid',           is => 'ro', required => 1;
has 'db',
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;

    return Crafty::DB->new(
        config  => $self->config,
        db_file => $self->config->{db_file}
    );
  };

sub run {
    my ($fh, $config, $project_config, $uuid) = @_;

    $config         = JSON::decode_json($config);
    $project_config = JSON::decode_json($project_config);

    Crafty::PubSub->instance->address($config->{listen});

    __PACKAGE__->new(
        config         => $config,
        project_config => $project_config,
        uuid           => $uuid
    )->process;

    return;
}

sub process {
    my $self = shift;

    my $uuid = $self->uuid;

    my $config = $self->config;

    if ($config->{pool}->{mode} && $config->{pool}->{mode} eq 'detach') {
        $0 = 'Crafty Worker ' . $uuid . ' [D]';

        $self->_detach(sub { $self->_run });
    }
    else {
        $0 = 'Crafty Worker ' . $uuid;

        $self->_run;
    }
}

sub _detach {
    my $self = shift;
    my ($cb) = @_;

    my $pid = fork;

    die "Can't fork" if !defined $pid;

    POSIX::setsid or die "setsid: $!";

    if ($pid) {
        exit 0;
    }
    else {
        umask 0;

        foreach (0 .. (POSIX::sysconf(&POSIX::_SC_OPEN_MAX) || 1024)) {
            POSIX::close $_;
        }

        open(STDIN,  "</dev/null");
        open(STDOUT, ">/dev/null");
        open(STDERR, ">&STDOUT");

        $cb->();
    }
}

sub _run {
    my $self = shift;

    my $uuid           = $self->uuid;
    my $project_config = $self->project_config;

    my $cv = AnyEvent->condvar;

    my $builds_dir = $self->config->{builds_dir};

    $self->db->load($uuid)->then(
        sub {
            my ($build) = @_;

            $build->start;

            return $self->db->save($build);
        }
      )->then(
        sub {
            my ($build) = @_;

            my $runner = Crafty::Runner->new(
                stream    => $builds_dir . '/' . $uuid . '.log',
                build_dir => $builds_dir . '/' . $uuid,
                env       => $build->to_env
            );

            $runner->run(
                cmds   => $project_config->{build},
                on_pid => sub {
                    my ($pid) = @_;

                    $self->db->update_field($uuid, pid => $pid);
                },
                on_eof => sub {
                    my ($exit_code) = @_;

                    my $final_status = defined $exit_code ? $exit_code ? 'F' : 'S' : 'K';

                    $build->finish($final_status);

                    $self->db->save($build)->then(
                        sub {
                            $cv->send($build);
                        }
                    );
                },
                on_error => sub {
                    $build->finish('E');

                    $self->db->save($build)->then(
                        sub {
                            $cv->send($build);
                        }
                    );
                }
            );
        }
      )->catch(
        sub {
            $cv->send;
        }
      );

    my ($build) = $cv->recv;

    if ($build) {
        $cv = AnyEvent->condvar;

        if ($project_config->{post}) {
            my $runner = Crafty::Runner->new(
                stream    => $builds_dir . '/' . $uuid . '.log',
                build_dir => $builds_dir . '/' . $uuid,
                env       => $build->to_env
            );

            $runner->run(
                cmds   => $project_config->{post},
                on_pid => sub {
                },
                on_eof => sub {
                    $cv->send;
                },
                on_error => sub {
                    $cv->send;
                }
            );
        }

        $cv->wait;
    }
}

1;
