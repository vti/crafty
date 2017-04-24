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
use Crafty::Config;
use Crafty::Build;
use Test::TempDir::Tiny;
use Test::MonkeyMock;

my $base;
sub base {
    $base ||= tempdir;
    return $base;
}

sub build_config {
    my $class = shift;

    my $base = $class->base;

    open my $fh, '>', "$base/config.yml";
    print $fh <<'EOF';
---
projects:
    - id: my_project
      webhooks:
        - provider: rest
      build:
        - run: date
EOF
    close $fh;

    my $config = Crafty::Config->new(base => $base);
    $config->load("$base/config.yml");

    return $config;
}

our $db;
our $db_file;

sub build_db {
    my $class = shift;

    if (!$db_file) {
        $db_file = File::Temp->new;

        my $schema = do {
            local $/;
            open my $fh, '<', 'schema/00schema.sql' or die $!;
            <$fh>;
        };
        my (@sql) = split /;/, $schema;

        my $dbh = DBI->connect('dbi:SQLite:dbname=' . $db_file->filename);
        $dbh->do($_) for @sql;
        $dbh->disconnect;
        undef $dbh;
    }

    $db ||= Crafty::DB->new(db_file => $db_file->filename);

    return $db;
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

    $mock->mock(build => sub {});
    $mock->mock(start => sub {});

    return $mock;
}

sub create_build {
    my $class = shift;

    my $build = Crafty::Build->new(
        project => 'test',
        rev     => '123',
        branch  => 'master',
        author  => 'vti',
        message => 'fix',
        status  => 'S',
        @_
    );

    my $cv = AnyEvent->condvar;

    TestSetup->build_db->save($build)
      ->done(sub { $cv->send(@_) }, sub { $cv->send });

    ($build) = $cv->recv;

    return $build;
}

sub load_build {
    my $class = shift;
    my ($uuid) = @_;

    my $cv = AnyEvent->condvar;

    TestSetup->build_db->load($uuid)
      ->done(sub { $cv->send(@_) }, sub { $cv->send });

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
