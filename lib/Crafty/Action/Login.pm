package Crafty::Action::Login;
use Moo;
extends 'Crafty::Action::Base';

use Input::Validator;
use Plack::Session;
use Crafty::Password;

sub content_type { 'text/html' }

sub build_validator {
    my $self = shift;

    my $validator = Input::Validator->new(messages => { REQUIRED => 'Required' });

    $validator->field('username')->required(1);
    $validator->field('password')->required(1);

    return $validator;
}

sub validate {
    my $self = shift;
    my ($validator, $params) = @_;

    return unless $validator->validate($params);

    my $values = $validator->values;

    my $user = $self->config->user($values->{username}, $values->{password});
    if (!$user) {
        $validator->error(username => 'Unknown credentials');
        return 0;
    }

    my $password = Crafty::Password->new(hashing => $user->{hashing}, salt => $user->{salt});

    if (!$password->equals($values->{username}, $values->{password}, $user->{password})) {
        $validator->error(username => 'Unknown credentials');
        return 0;
    }

    $self->{user} = $user;

    return 1;
}

sub run {
    my $self = shift;

    if ($self->req->method eq 'GET') {
        return $self->render(200, {});
    }
    else {
        my $validator = $self->build_validator;

        return $self->render(400, { errors => $validator->errors })
          unless $self->validate($validator, $self->req->parameters);

        my $user = $self->{user};

        my $session = Plack::Session->new($self->env);

        $session->set(username => $user->{username});

        return $self->redirect('/');
    }
}

1;
