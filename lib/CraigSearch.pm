package CraigSearch;
use Moose;
use namespace::autoclean;

has id => (
    is  => 'ro',
    isa => 'Int',
);

has text => (
    is  => 'ro',
    isa => 'Str',
);

has 'link' => (
    is  => 'ro',
    isa => 'Str',
);

has amount => (
    is  => 'ro',
    isa => 'Num',
);

has city => (
    is  => 'ro',
    isa => 'Str',
);

has mileage => (
    is  => 'ro',
    isa => 'Maybe[Int]',
);

has search_URL => (
    is  => 'ro',
    isa => 'Str',
);

has search_keywords => (
    is  => 'ro',
    isa => 'Str',
);

has search_name => (
    is  => 'ro',
    isa => 'Str',
);

__PACKAGE__->meta->make_immutable;
1
