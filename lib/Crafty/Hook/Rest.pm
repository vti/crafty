package Crafty::Hook::Rest;

use strict;
use warnings;

use Input::Validator;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{config} = $params{config};

    return $self;
}

sub parse {
    my $self = shift;
    my ($params) = @_;

    my $validator = Input::Validator->new;
    $validator->field('rev')->required(1);
    $validator->field('branch')->required(1);
    $validator->field('message')->required(1);
    $validator->field('author')->required(1);

    return unless $validator->validate($params);

    return $validator->values;
}

1;
