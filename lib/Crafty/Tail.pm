package Crafty::Tail;
use Moo;

use File::Temp qw(tempfile);
use AnyEvent::Handle;
use AnyEvent::Fork;

sub tail {
    my $self = shift;
    my ($path, %params) = @_;

    my $pid_fh = tempfile();
    $pid_fh->autoflush(1);

    $self->{pid_fh} = $pid_fh;

    my $fork = AnyEvent::Fork->new->eval('
               sub run {
                  my ($fh, $pid_fh, @cmd) = @_;

                  print $pid_fh $$;
                  close $pid_fh;

                  open STDOUT, ">&", $fh or die;
                  open STDERR, ">&", $fh or die;

                  exec @cmd or die $!;
               }
            ');

    $fork->send_fh($pid_fh);
    $fork->send_arg('tail', '-f', '-n', '10000', $path);

    $fork->run(
        run => sub {
            my ($fh) = @_;

            my $handle;
            $handle = AnyEvent::Handle->new(
                fh       => $fh,
                on_error => sub {
                    my ($handle, $fatal, $msg) = @_;

                    $handle->destroy;
                    delete $self->{handle};

                    $params{on_error}->();
                },
                on_eof => sub {
                    $handle->destroy;
                    delete $self->{handle};

                    $params{on_eof}->();
                },
                on_read => sub {
                    my $content = $_[0]->rbuf;

                    $_[0]->rbuf = "";

                    $params{on_read}->($content);
                },
            );

            $self->{handle} = $handle;
        }
    );

    return $self;
}

sub stop {
    my $self = shift;

    my $pid_fh = delete $self->{pid_fh};
    seek $pid_fh, 0, 0;
    my ($pid) = <$pid_fh>;

    if ($pid && kill 0, $pid) {
        kill 'INT', $pid;
    }

    $self->{handle}->destroy;
    delete $self->{handle};

    return $self;
}

1;
