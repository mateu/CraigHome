use Scrappy qw/:syntax/;
use strict;
use warnings;
use KiokuDB;
use KiokuDB::Backend::DBI;
use Time::HiRes qw / time /;
use Email::Stuff;
use CraigHome;
use Data::Dumper::Concise;

=head1 Search Definitions

Define craigslist searches.  Given an identifier, URL to search and keywords to search at the URL;
Populate the DB store with CraigHome objects.

=cut

my %search_definitions = (
    1 => {
        search_name => 'mso_rattlesnake_by_owner',
        search_URIs => ['http://missoula.craigslist.org/reo/'],
        keywords    => [qw/ rattlesnake /],
        max_price   => 325000,
        min_price   => 1,
    },
    2 => {
        search_name => 'montana_cabin_by_owner',
        search_URIs => [
            'http://missoula.craigslist.org/reo/', 'http://montana.craigslist.org/reo/',
            'http://bozeman.craigslist.org/reo/'
        ],
        keywords  => [qw/ cabin /],
        max_price => 60000,
        min_price => 1,
    },
    3 => {
        search_name => 'bozeman_radiant_heat_by_owner',
        search_URIs => ['http://bozeman.craigslist.org/reo/'],
        keywords    => [qw/ radiant heat /],
        max_price   => 275000,
        min_price   => 1,
    },
    0 => {
        search_name => 'missoula_sienna',
        search_URIs => ['http://missoula.craigslist.org/cto/'],
        keywords    => [qw/ sienna /],
        max_price   => 16000,
        min_price   => 1,
    },
);

# Connect to Kioku Data Store, nominate columns for searching and create the scope object.
my $db = KiokuDB->connect(
    "dbi:SQLite:dbname=db/craighomes.db",
    create  => 1,
    columns => [
        search_name => {
            data_type   => "varchar",
            is_nullable => 0,           # probably important
        },
        amount => {
            data_type   => "int",
            is_nullable => 0,           # probably important
        },
    ]
);
my $scope_object = $db->new_scope;

# Run main logic
main();

##--- subs below
sub main {

    my $start_time = time;

    init;
    user_agent
      'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2.8) Gecko/20100722 Firefox/3.6.8';

    # Do the searches
    foreach my $search_definition ( values %search_definitions ) {

        # A search definition can have mulitple search URLs (for the same keywords)
        foreach my $search_URL ( @{ $search_definition->{search_URIs} } ) {
            process_search( $search_URL, $search_definition );
        }
    }

    my $processing_time = time - $start_time;
    printf "Processing time; %.1f seconds \n", $processing_time;
}

sub process_search {
    my $search_URL        = shift;
    my $search_definition = shift;

    get $search_URL;
    my $keywords_string = join ' ', @{ $search_definition->{keywords} };
    my $search_name = $search_definition->{search_name};
    form fields => {
        'minAsk' => $search_definition->{min_price},
        'maxAsk' => $search_definition->{max_price},
        'query'  => $keywords_string,
    };

    print "Processing search: ", $search_definition->{search_name},
      " at URL: ${search_URL} with keywords: $keywords_string\n";

    # Process each listing, looking for keyword match.
    # NOTE: This part is fragile since it depends on a particulary HTML Tree.
    # Got to love the loaded bareword.
    if (loaded) {
        var listings => grab 'p a', { name => 'TEXT', link => '@href' };
        var listings_textos => grab 'p', { name => 'TEXT' };
        foreach my $listing ( list var->{listings} ) {
            process_listing( $listing, $search_URL, $keywords_string, $search_name );
        }
    }
}

sub process_listing {
    my $listing         = shift;
    my $search_URL      = shift;
    my $keywords_string = shift;
    my $search_name     = shift;

    my $listing_amount = listing_amount($listing);
    my $listing_id     = listing_id($listing);
    my $listing_object = CraigHome->new(
        amount          => $listing_amount,
        text            => $listing->{name},
        'link'          => $listing->{link},
        id              => $listing_id,
        search_URL      => $search_URL,
        search_keywords => $keywords_string,
        search_name     => $search_name,
    );
    if ( is_new_listing_id($listing_id) ) {
        listing_report($listing_object);
        $db->store( $listing_id => $listing_object );
    }
}

sub listing_report {
    my $listing_object = shift;

    print "New listing found with id: ", $listing_object->id, ' Info: ';
    print $listing_object->text, "\n";
    return;
}

sub listing_amount {
    my $listing = shift;
    my ($amount) = $listing->{name} =~ m{^\$(\d+)};

    return $amount;
}

sub listing_id {
    my $listing = shift;
    my ($listing_id) = $listing->{link} =~ m/(\d+)\.html$/;

    return $listing_id;
}

sub is_new_listing_id {
    my $listing_id = shift;

    return !$db->lookup($listing_id) ? 1 : 0;
}

sub by_listing_amount ($$) {
    my ( $listing_a, $listing_b ) = @_;

    my ($amount_a) = $listing_a->{name} =~ m{^\$(\d+)};
    my ($amount_b) = $listing_b->{name} =~ m{^\$(\d+)};

    return $amount_a <=> $amount_b;
}

sub email_listings {

    # Prepare the message
    my $body = <<'END_MSG';
        massage.
END_MSG

    # Create and send the email in one shot
    Email::Stuff->from('hunter@wisdom.webhop.org')->to('hunter@missoula.org')->text_body($body)
      ->send;
}
