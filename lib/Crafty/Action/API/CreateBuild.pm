package Crafty::Action::API::CreateBuild;
use Moo;
extends 'Crafty::Action::API::Base';

use Input::Validator;
use Crafty::Build;

sub build_validator {
    my $self = shift;

    my $validator = Input::Validator->new(messages => { REQUIRED => 'Required' });

    $validator->field('project')->required(1);
    $validator->field('rev')->required(1);
    $validator->field('branch')->required(1);
    $validator->field('message')->required(1);
    $validator->field('author')->required(1);

    return $validator;
}

sub validate {
    my $self = shift;
    my ($validator, $params) = @_;

    return unless $validator->validate($params);

    my $values = $validator->values;

    my $project_config = $self->config->project($values->{project});
    unless ($project_config) {
        $validator->error('project', 'Unknown project');
        return 0;
    }

    return 1;
}

sub run {
    my $self = shift;
    my (%captures) = @_;

    my $validator = $self->build_validator;

    my $content_type = $self->req->header('Content-Type') // '';

    my $params = {};
    if ($content_type eq 'application/x-www-form-urlencoded') {
        $params = $self->req->parameters;
    }
    elsif ($content_type eq 'application/json') {
        eval { $params = JSON::decode_json($self->req->content); } or do {
            return $self->render(400, { error => 'Invalid JSON' });
        };
    }

    return $self->render(422, { error => 'Invalid fields', fields => $validator->errors })
      unless $self->validate($validator, $params);

    return sub {
        my $respond = shift;

        my $build = Crafty::Build->new(%$params);

        $build->init;

        $self->db->save($build)->then(
            sub {
                $self->pool->peek;

                $self->render(201, { uuid => $build->uuid }, $respond);
            }
        )->catch(sub { $self->handle_error(@_) });
    };
}

1;
