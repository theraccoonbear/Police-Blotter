package CCAP;

use Moose;
use WWW::Mechanize;
use Web::Scraper;
use Data::Dumper;
use HTTP::Cookies;

# http://wcca.wicourts.gov/index.xsl

my $base_url = 'http://wcca.wicourts.gov/';
my $current_search_url;	

my $mech = WWW::Mechanize->new(
	agent => 'Madison Police Blotter Bot 1.0',
	autocheck => 0,
	cookie_jar => HTTP::Cookies->new( file => "$ENV{HOME}/.police-blotter-cookies.txt" )
);

sub begin {
	my $self = shift @_;
	
	$mech->get($base_url . 'index.xsl');
	if ($mech->success()) {
		my $content = $mech->content();
		if ($content =~ m/onclick="location.href='(?<url>[^']+)'/gi) {
			my $url = $base_url . $+{url};
			$mech->get($url);
			$current_search_url = $url;
			if ($mech->success()) {
				
			}
		}
	}
	
}

sub search {
	my $self = shift @_;
	my $terms = shift @_;
	
	$self->begin();
	
	$mech->submit_form(
		form_number => 1,
		fields      => {
			'partyName.lastName' => $terms->{last_name} || '',
			'partyName.firstName' => $terms->{first_name} || '',
			'partyName.middleName' => $terms->{mi} || ''
		}
	);
	
	my $content = $mech->success() ? $mech->content() : 'NO!!!!';
	
	print $content; exit(0);
	
	
}