package PersonalData::Mugshots;

use Moose;

extends 'PersonalData';

use URI::Escape;
use WWW::Mechanize;
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;

my $base_search_url = 'http://mugshots.com/search.html?q=';


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
	$self->mech()->get($url);
	my $images = [];
	
	if ($self->mech()->success()) {
		my $content = $self->mech()->content();
		my $results = $scraper->scrape($content);
		$images = $results->{entries};
		#print Dumper($results);
	}
	
	return $images;
}


1;