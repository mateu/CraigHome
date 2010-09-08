package CraigSearch; 
use Moose;
use namespace::autoclean;

has search_id => (
    is => 'ro',
    isa => 'Str',
);
has search_URI => (
    is => 'ro',
    isa => 'Str',
);
has keywords => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
);

__PACKAGE__->meta->make_immutable;
1