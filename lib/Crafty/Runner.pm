package Crafty::Runner;

use strict;
use warnings;

use File::Path qw(make_path);
use File::Basename qw(dirname);
use IO::Handle;
use AnyEvent::Fork;
use AnyEvent::Handle;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{stream}    = $params{stream};
    $self->{build_dir} = $params{build_dir};

    return $self;
}

sub run {
    my $self = shift;
    my (%params) = @_;

    my $build_dir = $self->{build_dir};

    make_path $build_dir;

    open my $stream, '>', $self->{stream}
      or die "Can't create `$self->{stream}`: $!";

  use File::Temp qw(tempfile);
  my $tmp = tempfile();

    $stream->autoflush(1);

    my $fork = AnyEvent::Fork->new;
    $fork->eval('
               sub run {
                  my ($fh, $ex, $build_dir, @cmd) = @_;

                  open STDOUT, ">&", $fh or die;
                  open STDERR, ">&", $fh or die;

                  chdir $build_dir;

                  print "PID=$$\n\n";
                  print "$_=$ENV{$_}\n" for sort keys %ENV;
                  print "\n";

                  print @cmd, "\n";

                  system(@cmd) or die $!;

                  print $ex $?;
               }
            ');
    $fork->send_fh($tmp);
    $fork->send_arg($build_dir);
    $fork->send_arg(@{$params{cmd}});
    $fork->run(
        run => sub {
            my ($fh) = @_;

            my $pid;

            my $handle;
            my $w;
            $handle = AnyEvent::Handle->new(
                fh       => $fh,
                on_error => sub {
                    $handle->destroy;
                    delete $self->{handle};

                    $params{on_error}->();
                },
                on_eof => sub {
                    $handle->destroy;
                    delete $self->{handle};

                    seek $tmp, 0, 0;
                    my $exit_code = <$tmp>;
                    $exit_code //= 0;
                    $exit_code >>= 8;

                    $params{on_eof}->($exit_code);
                },
                on_read => sub {
                    my $content = $_[0]->rbuf;

                    $_[0]->rbuf = '';

                    print $stream $content;
                },
            );

            $self->{handle} = $handle;
        }
    );

    return $stream;
}

1;
