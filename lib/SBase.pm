package SBase;

use Moose;

use WWW::Mechanize;
use HTML::Entities;
use Text::Unidecode;
use Web::Scraper;
use Text::Soundex;
use Date::Parse;
use Data::Dumper;

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

sub trim {
	my $self = shift;
	my $v = unidecode(decode_entities(shift @_ || ''));
	$v =~ s/^\s+//;
	$v =~ s/\s+$//;
	return $v;
}

sub fetchPage {
	my $self = shift @_;
	my $url = shift @_;
	$self->mech()->get($url);
	return $self->mech()->success() ? $self->mech()->content() : '';
}

1;