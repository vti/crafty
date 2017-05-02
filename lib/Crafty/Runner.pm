package Crafty::Runner;

use strict;
use warnings;

use File::Path qw(make_path);
use File::Basename qw(dirname);
use File::Temp qw(tempfile);
use JSON ();
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
    $self->{env}       = $params{env} // {};

    return $self;
}

sub run {
    my $self = shift;
    my (%params) = @_;

    my $cmds = $params{cmds};

    my $build_dir = $self->{build_dir};

    make_path $build_dir;

    open my $stream, '>', $self->{stream}
      or die "Can't create `$self->{stream}`: $!";

    my $tmp = tempfile();
    $tmp->autoflush(1);

    $stream->autoflush(1);

    my $fork = AnyEvent::Fork->new;
    $fork->eval('
               sub run {
                  my ($fh, $ex, $build_dir, $env, @cmds) = @_;

                  open STDOUT, ">&", $fh or die;
                  open STDERR, ">&", $fh or die;

                  chdir $build_dir;

                  eval {
                      require JSON;
                      $env = JSON::decode_json($env);

                      foreach my $key (keys %$env) {
                          $ENV{$key} = $env->{$key};
                      }
                  };

                  print "PID=$$\n\n";
                  print "$_=$ENV{$_}\n" for sort keys %ENV;
                  print "\n";

                  $|++;

                  my $exit_code;
                  foreach my $cmd (@cmds) {
                      print $cmd, "\n";

                      open my $pipe, "$cmd |" or die $!;

                      $SIG{INT} = sub { close $pipe; print "Killed\n"; exit 255 };

                      while (<$pipe>) {
                          print $_;
                      }
                      close $pipe;

                      $exit_code = $?;

                      last if $exit_code;
                  }

                  print $ex $exit_code;

                  print "\nExit code: $exit_code\n";

                  close $ex;
                  close $fh;
                  exit $exit_code;
               }
            ');
    $fork->send_fh($tmp);
    $fork->send_arg($build_dir);
    $fork->send_arg(JSON::encode_json($self->{env}));
    $fork->send_arg(@$cmds);
    $fork->run(
        run => sub {
            my ($fh) = @_;

            my $pid;

            my $handle;
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
                    $exit_code >>= 8 if defined $exit_code;

                    $params{on_eof}->($exit_code);
                },
                on_read => sub {
                    my $content = $_[0]->rbuf;

                    $_[0]->rbuf = '';

                    if (!$pid) {
                        ($pid) = $content =~ m/^PID=(\d+)/;

                        if ($pid) {
                            $params{on_pid}->($pid);
                        }
                    }

                    print $stream $content;
                },
            );

            $self->{handle} = $handle;
        }
    );

    return;
}

1;
