use strict;
use warnings;
use 5.010;
use KiokuDB;
use KiokuDB::Backend::DBI;
use CraigHome;
use Data::Dumper::Concise;
use CGI qw(start_html end_html);

my $db             = KiokuDB->connect( "dbi:SQLite:dbname=db/craighomes.db", );
my $scope_object   = $db->new_scope;
my $search_results = $db->search( { search_name => 'montana_cabin_by_owner' } );

my $title = 'Montana Cabins by Owner';

my @cabins;
# Remind me why do I have to block with ->next?
while ( my $block = $search_results->next ) {
    foreach my $object ( @{$block} ) {
        push @cabins, $object;
    }
}

print start_html( -title => $title );
say "<h1>$title</h1>";
foreach my $cabin ( sort { $a->amount <=> $b->amount } @cabins ) {
    my $link      = $cabin->link;
    my $link_text = $cabin->text;
    say "<a href='$link'>$link_text</a><br />";
}

print end_html;
