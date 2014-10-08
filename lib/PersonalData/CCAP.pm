package PersonalData::CCAP;

use Moose;

extends 'PersonalData';

use WWW::Mechanize;
use Web::Scraper;
use Data::Dumper;
use HTTP::Cookies;

# http://wcca.wicourts.gov/index.xsl

my $results_scraper = scraper {
	process 'table.noClownPants tr[bgcolor], table.noClownPants tr.accentBar', 'entries[]' => scraper {
		# Case Number, Filing Date, County Name, Case Status, Name, Date of Birth
		process '//td[1]/a', 'url' => '@href', 'case_number' => 'TEXT';
		process '//td[2]/div[@class="bodySmall"]', 'filing_date' => 'TEXT';
		process '//td[3]/div[@class="bodySmall"]', 'county' => 'TEXT';
		process '//td[4]/div[@class="bodySmall"]', 'case_status' => 'TEXT';
		process '//td[5]/div[@class="bodySmall"]', 'name' => 'TEXT';
		process '//td[6]/div[@class="bodySmall"]', 'DOB' => 'TEXT';
		process '//td[7]/div[@class="bodySmall"]', 'caption' => 'TEXT';
	};
};

my $base_url = 'http://wcca.wicourts.gov/';
my $current_search_url;	

#my $self->mech() = WWW::Mechanize->new(
#	agent => 'Madison Police Blotter Bot 1.0',
#	autocheck => 0,
#	cookie_jar => HTTP::Cookies->new( file => "$ENV{HOME}/.police-blotter-cookies.txt" )
#);

sub begin {
	my $self = shift @_;
	
	$self->mech()->get($base_url . 'index.xsl');
	if ($self->mech()->success()) {
		my $content = $self->mech()->content();
		if ($content =~ m/onclick="location.href='(?<url>[^']+)'/gi) {
			my $url = $base_url . $+{url};
			$self->mech()->get($url);
			$current_search_url = $url;
			if ($self->mech()->success()) {
				
			}
		}
	}
	
}

sub search {
	my $self = shift @_;
	my $terms = shift @_;
	
	$self->begin();
	
	$self->mech()->submit_form(
		form_number => 1,
		fields      => {
			'partyName.lastName' => $terms->{last_name} || '',
			'partyName.firstName' => $terms->{first_name} || '',
			'partyName.middleName' => $terms->{mi} || ''
		}
	);
	
	my $content = '';
	my $results = [];
	if ($self->mech()->success()) {
		$content = $self->mech()->content();
		my $entries = $results_scraper->scrape($content, $base_url);
		foreach my $entry (@{$entries->{entries}}) {
			print "$entry->{name}\n";
			my @names = split(/\s*,\s*/, $entry->{name});
			my @first_mid = split(/\s+/, $names[1]);
			$entry->{last_name} = $names[0];
			$entry->{first_name} = $first_mid[0];
			$entry->{middle} = $first_mid[1] || '';
			$entry->{suffix} = $names[2] || '';
			push @$results, $entry;
		}
	}
	
	return $results;
}

sub fetchCase {
	my $self = shift @_;
	
}

1;