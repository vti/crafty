package Crafty::Password;
use Moo;

has 'hashing', is => 'ro', required => 1;
has 'salt',    is => 'ro', default  => '';

use Digest::Bcrypt;
use Digest::SHA qw(sha1_hex);
use Digest::MD5 qw(md5_hex);

sub hash {
    my $self = shift;
    my ($username, $password) = @_;

    my $salt = $self->salt // '';

    my $hash = "$username:$salt:$password";

    if ($self->hashing eq 'bcrypt') {
        $salt .= ' ' while length $salt < 16;

        my $bcrypt = Digest::Bcrypt->new(cost => 12, salt => $salt);
        $bcrypt->add($hash);
        $hash = $bcrypt->hexdigest;
    }
    elsif ($self->hashing eq 'sha1') {
        $hash = sha1_hex($hash);
    }
    elsif ($self->hashing eq 'md5') {
        $hash = md5_hex($hash);
    }
    else {
        die "Unknown hashing\n";
    }

    return $hash;
}

sub equals {
    my $self = shift;
    my ($username, $password, $expected_hash) = @_;

    my $hash = $self->hash($username, $password);

    return $hash eq $expected_hash;
}

1;
