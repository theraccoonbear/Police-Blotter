package SBase;

use Moose;

use HTTP::Cookies;
use WWW::Mechanize;
use HTML::Entities;
use Text::Unidecode;
use IO::Socket::SSL;
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
			SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
			PERL_LWP_SSL_VERIFY_HOSTNAME => 0,
			verify_hostname => 0,
			ssl_opts => {
				verify_hostname => 0
			},
			cookie_jar => new HTTP::Cookies( file => ".personal-data.txt" )
		);
	}
);

has debug_output => (
	is => 'rw',
	isa => 'Bool',
	default => 0
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