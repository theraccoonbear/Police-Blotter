package PersonalData;

use Moose;

extends 'SBase';

use WWW::Mechanize;
use Web::Scraper;
use Text::Soundex;
use Date::Parse;

my $tables = {};

has 'mech' => (
	is => 'rw',
	isa => 'WWW::Mechanize',
	default => sub {
		return WWW::Mechanize->new(
			agent => 'Madison Police Blotter Bot 1.0',
			autocheck => 0,
			cookie_jar => HTTP::Cookies->new( file => "$ENV{HOME}/.personal-data.txt" )
		);
	}
);

1;