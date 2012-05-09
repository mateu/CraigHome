use strict;
use warnings;
use 5.010;
use KiokuDB;
use KiokuDB::Backend::DBI;
use CraigSearch;
use Data::Dumper::Concise;
use CGI qw(start_html end_html);

print start_html( -title => 'Car Search' );
my $db_path     =  'db/cars.db';
my @search_names = ('local_honda_odyssey', 'local_toyota_sienna', 'local_ford_f150', 'local_truck', 'toyota_highlander');
my $db = KiokuDB->connect( "dbi:SQLite:dbname=${db_path}", );
foreach my $search_name (@search_names) {
    my $scope_object = $db->new_scope;
    my $search_results = $db->search( { search_name => $search_name } );

    my @title_words = split /_/, $search_name;
    my $title = join ' ', map { ucfirst($_) } @title_words;
    my @listings;

    # Remind me why do I have to block with ->next?
    while ( my $block = $search_results->next ) {
        foreach my $object ( @{$block} ) {
            push @listings, $object;
        }
    }

    say "<h1>$title</h1>";
    foreach my $listing ( sort { $a->amount <=> $b->amount } @listings ) {
        my $link      = $listing->link;
        my $link_text = $listing->text;
        my $amount    = $listing->amount;
        my $city      = $listing->city;
        my $miles     = $listing->mileage;
        my $mileage = $miles ? "${miles} miles" : 'miles n/a';
        # Strip out amount (display on nearby matches
        $link_text =~ s/\s+\$\d+//;
        say "<a href='$link'>$link_text</a> \$$amount : $city $mileage<br />";
    }

}

print end_html;
