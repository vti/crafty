package Crafty::Fork::Pool;

use common::sense;

use Scalar::Util ();

use Guard ();
use Array::Heap ();

use AnyEvent;
use AnyEvent::Fork::RPC;

# these are used for the first and last argument of events
# in the hope of not colliding. yes, I don't like it either,
# but didn't come up with an obviously better alternative.
my $magic0 = ':t6Z@HK1N%Dx@_7?=~-7NQgWDdAs6a,jFN=wLO0*jD*1%P';
my $magic1 = '<~53rexz.U`!]X[A235^"fyEoiTF\T~oH1l/N6+Djep9b~bI9`\1x%B~vWO1q*';

our $VERSION = 1.2;

our @pool;
our @queue;

sub run {
   my ($template, $function, %arg) = @_;

   my $max        = $arg{max}        || 4;
   my $idle       = $arg{idle}       || 0,
   my $load       = $arg{load}       || 2,
   my $start      = $arg{start}      || 0.1,
   my $stop       = $arg{stop}       || 10,
   my $on_event   = $arg{on_event}   || sub { },
   my $on_destroy = $arg{on_destroy};

   my @rpc = (
      async      =>        $arg{async},
      init       =>        $arg{init},
      serialiser => delete $arg{serialiser},
      on_error   =>        $arg{on_error},
   );

   my ($nidle, $start_w, $stop_w, $shutdown);
   my ($start_worker, $stop_worker, $want_start, $want_stop, $scheduler);

   my $destroy_guard = Guard::guard {
      $on_destroy->()
         if $on_destroy;
   };

   $template
      ->require ("AnyEvent::Fork::RPC::" . ($arg{async} ? "Async" : "Sync"))
      ->eval ('
           my ($magic0, $magic1) = @_;
           sub AnyEvent::Fork::Pool::retire() {
              AnyEvent::Fork::RPC::event $magic0, "quit", $magic1;
           }
        ', $magic0, $magic1)
   ;

   $start_worker = sub {
      my $proc = [0, 0, undef]; # load, index, rpc

      $proc->[2] = $template
         ->fork
         ->AnyEvent::Fork::RPC::run ($function,
              @rpc,
              on_event => sub {
                 if (@_ == 3 && $_[0] eq $magic0 && $_[2] eq $magic1) {
                    $destroy_guard if 0; # keep it alive

                    $_[1] eq "quit" and $stop_worker->($proc);
                    return;
                 }

                 &$on_event;
              },
           )
      ;

      ++$nidle;
      Array::Heap::push_heap_idx @pool, $proc;

      Scalar::Util::weaken $proc;
   };

   $stop_worker = sub {
      my $proc = shift;

      $proc->[0]
         or --$nidle;

      Array::Heap::splice_heap_idx @pool, $proc->[1]
         if defined $proc->[1];

      @$proc = 0; # tell others to leave it be
   };

   $want_start = sub {
      undef $stop_w;

      $start_w ||= AE::timer $start, $start, sub {
         if (($nidle < $idle || @queue) && @pool < $max) {
            $start_worker->();
            $scheduler->();
         } else {
            undef $start_w;
         }
      };
   };

   $want_stop = sub {
      $stop_w ||= AE::timer $stop, $stop, sub {
         $stop_worker->($pool[0])
            if $nidle;

         undef $stop_w
            if $nidle <= $idle;
      };
   };

   $scheduler = sub {
      if (@queue) {
         while (@queue) {
            @pool or $start_worker->();

            my $proc = $pool[0];

            if ($proc->[0] < $load) {
               # found free worker, increase load
               unless ($proc->[0]++) {
                  # worker became busy
                  --$nidle
                     or undef $stop_w;

                  $want_start->()
                     if $nidle < $idle && @pool < $max;
               }

               Array::Heap::adjust_heap_idx @pool, 0;

               my $job = shift @queue;
               my $ocb = pop @$job;

               $proc->[2]->(@$job, sub {
                  # reduce load
                  --$proc->[0] # worker still busy?
                     or ++$nidle > $idle # not too many idle processes?
                     or $want_stop->();

                  Array::Heap::adjust_heap_idx @pool, $proc->[1]
                     if defined $proc->[1];

                  &$ocb;

                  $scheduler->();
               });
            } else {
               $want_start->()
                  unless @pool >= $max;

               last;
            }
         }
      } elsif ($shutdown) {
         undef $_->[2]
            for @pool;

         undef $start_w;
         undef $start_worker; # frees $destroy_guard reference

         $stop_worker->($pool[0])
            while $nidle;
      }
   };

   my $shutdown_guard = Guard::guard {
      $shutdown = 1;
      $scheduler->();
   };

   $start_worker->()
      while @pool < $idle;

   sub {
      $shutdown_guard if 0; # keep it alive

      $start_worker->()
         unless @pool;

      push @queue, [@_];
      $scheduler->();
   }
}

BEGIN {
   if ($^O eq "linux") {
      *ncpu = sub(;$) {
         my ($cpus, $eus);

         if (open my $fh, "<", "/proc/cpuinfo") {
            my %id;

            while (<$fh>) {
               if (/^core id\s*:\s*(\d+)/) {
                  ++$eus;
                  undef $id{$1};
               }
            }

            $cpus = scalar keys %id;
         } else {
            $cpus = $eus = @_ ? shift : 1;
         }
         wantarray ? ($cpus, $eus) : $cpus
      };
   } elsif ($^O eq "freebsd" || $^O eq "netbsd" || $^O eq "openbsd") {
      *ncpu = sub(;$) {
         my $cpus = qx<sysctl -n hw.ncpu> * 1
                 || (@_ ? shift : 1);
         wantarray ? ($cpus, $cpus) : $cpus
      };
   } else {
      *ncpu = sub(;$) {
         my $cpus = @_ ? shift : 1;
         wantarray ? ($cpus, $cpus) : $cpus
      };
   }
}

1

