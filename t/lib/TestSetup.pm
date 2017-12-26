package TestSetup;

use strict;
use warnings;

use DBI;
use AnyEvent;
use AnyEvent::DBI;
use Text::Caml;
use File::Path;
use File::Basename;
use File::Temp;
use Crafty::DB;
use Crafty::Log;
use Crafty::Config;
use Crafty::Build;
use Test::TempDir::Tiny;
use Test::MonkeyMock;

sub import {
    $Crafty::Log::QUIET = 1;
}

my $base;

sub base {
    $base ||= tempdir;
    return $base;
}

sub build_config {
    my $class = shift;
    my ($content) = @_;

    my $base = $class->base;

    open my $fh, '>', "$base/config.yml";
    if (!$content) {
        print $fh <<'EOF';
---
access:
    mode: public
    session:
        expires: 600
        secret: $ecret
    users:
        - username: api
          password: 2f5af97048388e90c2c7f7ef5fd93f10
          hashing: md5
        - username: username
          password: 0665fcae289dda92188f71c03828220b
          hashing: md5
projects:
    - id: my_project
      build:
        - date
EOF
    }
    else {
        print $fh $content;
    }
    close $fh;

    my $config = Crafty::Config->new(
        root => File::Basename::dirname(__FILE__) . '/../../',
        base => $base
    );
    $config->load("$base/config.yml");

    return $config;
}

our $db;
our $db_file;

sub build_db {
    my $class = shift;

    if (!$db_file) {
        $db_file = File::Temp->new;

        my $schema = '';

        for my $file (glob 'schema/*.sql') {
            local $/;
            open my $fh, '<', $file or die $!;
            $schema .= <$fh>;
        }

        my (@sql) = grep { !m/^--\s/ } split /;/, $schema;

        my $dbh = DBI->connect('dbi:SQLite:dbname=' . $db_file->filename);
        $dbh->do($_) for @sql;
        $dbh->disconnect;
        undef $dbh;
    }

    $db ||= Crafty::DB->new(config => {}, db_file => $db_file->filename);

    return $db;
}

sub cleanup_db {
    my $class = shift;

    if ($db_file) {
        my $dbh = DBI->connect('dbi:SQLite:dbname=' . $db_file->filename);
        $dbh->do('DELETE FROM builds');
        $dbh->disconnect;
        undef $dbh;
    }
}

sub build_view {
    my $class = shift;

    my $view = Text::Caml->new(templates_path => 'templates');

    return $view;
}

sub build_action {
    my $class = shift;
    my ($action, %params) = @_;

    $params{config} //= TestSetup->build_config;
    $params{db}     //= TestSetup->build_db;
    $params{view}   //= TestSetup->build_view;
    $params{pool}   //= $class->mock_pool();

    my $action_class = 'Crafty::Action::' . $action;

    return $action_class->new(%params);
}

sub mock_pool {
    my $class = shift;

    my $mock = Test::MonkeyMock->new;

    $mock->mock(start  => sub { });
    $mock->mock(peek   => sub { });
    $mock->mock(cancel => sub { });

    return $mock;
}

sub create_build {
    my $class = shift;

    my $build = Crafty::Build->new(
        project => 'test',
        rev     => '123',
        ref     => 'refs/heads/master',
        author  => 'vti',
        message => 'fix',
        @_
    );

    my $cv = AnyEvent->condvar;

    TestSetup->build_db->save($build)->done(sub { $cv->send(@_) }, sub { $cv->send });

    ($build) = $cv->recv;

    return $build;
}

sub load_build {
    my $class = shift;
    my ($uuid) = @_;

    my $cv = AnyEvent->condvar;

    TestSetup->build_db->load($uuid)->done(sub { $cv->send(@_) }, sub { $cv->send });

    my ($build) = $cv->recv;

    return $build;
}

sub write_file {
    my $class = shift;
    my ($path, $content) = @_;

    File::Path::make_path(File::Basename::dirname($path));

    open my $fh, '>', $path or die $!;
    print $fh $content if defined $content;
    close $fh;
}

sub END {
    $db = undef;
}

1;
