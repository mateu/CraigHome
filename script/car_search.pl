use strict;
use warnings FATAL => 'all';
use 5.010;
use KiokuDB;
use KiokuDB::Backend::DBI;
use Time::HiRes qw / time /;
use Email::Stuff;
use CraigSearch;
use Encode;
use LWP::UserAgent;
use HTTP::Response::Encoding;
use HTML::TreeBuilder::XPath;
use HTML::Selector::XPath qw(selector_to_xpath);

=head1 Search Definitions

Define craigslist searches.  Given an identifier, URL to search and keywords 
to search at the URL; Populate the DB store with CraigSearch objects.

=cut

my $cities = [ 
            'missoula', 'kalispell', 'butte', 'helena',
            'bozeman',  'spokane',   'greatfalls'
        ];
my $montana_cities = [ 
            'missoula', 'kalispell', 'butte', 'helena',
            'bozeman',  'greatfalls'
        ];
my $missoula = [ 'missoula' ];

my $searches = [
#    {
#        search_name => 'local_ford_f150',
#        search_type => 'cto',
#        city        => $missoula,
#        query       => 'Ford F150',
#        min_price   => 500,
#        max_price   => 10000,
#        min_year    => 1992,
#        max_mileage => 120000,
#    },
    {
        search_name => 'local_truck',
        search_type => 'cto',
        city        => $missoula,
        query       => 'truck',
        min_price   => 500,
        max_price   => 2500,
        min_year    => 1992,
        max_mileage => 120000,
    },
];

# Connect to Kioku Data Store, nominate columns for searching and create the scope object.
my $db = KiokuDB->connect(
    "dbi:SQLite:dbname=db/cars.db",
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
    foreach my $search ( @{$searches} ) {
        my @listings = get_listings($search);
        foreach my $listing (@listings) {
            process_listing($listing);
        }
    }

    my $processing_time = time - $start_time;
    printf "Processing time; %.1f seconds \n", $processing_time;
}

sub process_listing {
    my $listing    = shift;
    my $search_URL = shift;

    my $listing_id     = listing_id($listing);
    my $listing_object = CraigSearch->new(
        amount          => $listing->{amount},
        text            => $listing->{title},
        'link'          => $listing->{link},
        search_keywords => $listing->{search_keywords},
        search_name     => $listing->{search_name},
        search_URL      => $listing->{search_URL},
        city            => $listing->{city},
        id              => $listing_id,
        mileage         => $listing->{mileage},
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
    warn "LISTING: ", Dumper $listing;
    my ($amount) = $listing->{name} =~ m{\$(\d+)};

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
    Email::Stuff->from('hunter@wisdom.webhop.org')->to('hunter@missoula.org')
      ->text_body($body)->send;
}

sub get_listings {
    my $s = shift;

    my @listings;

    # Process each city
    foreach my $city ( @{ $s->{city} } ) {
        my $URL =
"http://${city}.craigslist.org/search/$s->{search_type}?query=$s->{query}&srchType=T&minAsk=$s->{min_price}&maxAsk=$s->{max_price}";
        say $URL;
        my $ua       = LWP::UserAgent->new;
        my $response = $ua->get($URL);
        my $content  = decode $response->encoding, $response->content;
        my $tree     = HTML::TreeBuilder::XPath->new_from_content($content);
        my $xpath    = selector_to_xpath('p.row');
        my @nodes    = $tree->findnodes($xpath);

        while ( my $node = shift @nodes ) {
            my $full_text = $node->as_text;
            my ($price) = $full_text =~ /\$(\d+)/;
            my $new_tree =
              HTML::TreeBuilder::XPath->new_from_content( $node->as_HTML );
            my $link_path = selector_to_xpath('a');
            my $link_node = $new_tree->findnodes($link_path)->shift;
            my $link      = $link_node->attr('href');
            my $title     = $link_node->as_text;

            # Make sure price is removed before looking for year
            my $title_copy = $title;
            $title_copy =~ s/\$(\d+)//;
            my ($year) = $title_copy =~ /(\d{4})/;
            next if ( $year and ( $year < $s->{min_year} ) );

            # Check actual link for year or mileage
            my $listing_page    = $ua->get($link);
            my $listing_content = decode $listing_page->encoding,
              $listing_page->content;
            my $listing_tree =
              HTML::TreeBuilder::XPath->new_from_content($listing_content);
            my $xpath        = selector_to_xpath('div#userbody');
            my $listing      = $listing_tree->findnodes($xpath)->shift;
            my $listing_text = $listing->as_text;
            my ($miles) = $listing_text =~ m/([\d,]*)\s+mill?es/i;
            $miles =~ s/,//g if $miles;
            # Try miles with a k
            if (not $miles) {
                ($miles) = $listing_text =~ m/([\d,]*)\s?k\s+mill?es/i;
                $miles =~ s/,//g if $miles;; 
                $miles *= 1000 if $miles;
            }
            next if ( $miles and ( $miles > $s->{max_mileage} ) );
            #warn "MILES: $miles" if $miles;
            # Checking for a year
            ($year) = $listing_text =~ m/(\d{4})\s+/;
            next if ( $year and ( $year < $s->{min_year} ) );
         
            # Check for salvage/rebuilt title
            next if ($listing_text =~ m/rebuilt\s+title/i);
            next if ($listing_text =~ m/salvage\s+title/i);
            next if ($listing_text =~ m/title\s+is\s+not\s+clean/i);
            push @listings,
              {
                search_URL      => $URL,
                search_name     => $s->{search_name},
                search_keywords => $s->{query},
                title           => $title,
                amount          => $price,
                link            => $link,
                city            => $city,
                mileage         => $miles,
              };
        }
    }
    return @listings;
}

