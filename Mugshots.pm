package Mugshots;

use Moose;
use URI::Escape;
use WWW::Mechanize;
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;

my $base_search_url = 'http://mugshots.com/search.html?q=';

my $mech = WWW::Mechanize->new(
	agent => 'Madison Police Blotter Bot 1.0',
	autocheck => 0,
	cookie_jar => HTTP::Cookies->new( file => "$ENV{HOME}/.police-blotter-cookies.txt" )
);

my $scraper = scraper {
	process 'div.search-listing table', 'entries[]' => scraper {
		process 'div.name a', 'name' => 'TEXT';
		process 'img', 'images[]' => '@src';
	};
};

has 'state' => (
	is => 'rw',
	isa => 'Str',
	default => 'Wisconsin'
);

sub search {
	my $self = shift @_;
	my $query = shift @_;
	
	my $url = $base_search_url . uri_escape($query . ' ' . $self->state());
	$mech->get($url);
	my $images = [];
	
	if ($mech->success()) {
		my $content = $mech->content();
		my $results = $scraper->scrape($content);
		$images = $results->{entries};
		#print Dumper($results);
	}
	
	return $images;
}


1;