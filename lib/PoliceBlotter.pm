package PoliceBlotter;

use Moose;
use Moose::Util::TypeConstraints;

extends 'SBase';

use strict;
use warnings;
use File::Slurp;
use WWW::Mechanize;
use HTTP::Cookies;
use Web::Scraper;
use JSON::XS;
use XML::Simple;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex);
use Cwd 'abs_path';
use File::Basename;
use Date::Parse;
use Text::Unidecode;
use XML::RSS;
use HTML::Entities;

use PersonalData::Mugshots;
use PersonalData::Person;

my $base_url = 'http://www.cityofmadison.com';
my $blotter_rss_url = $base_url . '/police/newsroom/incidentreports/rss.cfm?a=71';
my $blotter_url = $base_url . '/police/newsroom/incidentreports/';

my $json = JSON::XS->new->ascii->pretty->allow_nonref;

$json->allow_blessed(1);
$json->convert_blessed(1);

my $index_scraper = scraper {
	process 'div.incident-reports', 'entries[]' => scraper {
		process 'div.date a', 'created' => 'TEXT';
		process 'div.date a', 'url' => '@href';
		process 'div.agency a', 'incident' => 'TEXT';
		process 'div.casenumber a', 'case_number' => 'TEXT';
		process 'div.address a', 'address' => 'TEXT';
		process 'div.updated a', 'updated' => 'TEXT';
	};
};

my $detail_scraper = scraper {
	process 'div.incident-report-detail', 'report' => scraper {
		process 'div.clearfix', 'fields[]' => scraper {
			process 'h3', 'label' => 'TEXT';
			process 'span.span5', 'value' => 'HTML';
		};
	};
};

has find_mugshots => (
	is => 'rw',
	isa => 'Bool',
	default => 1
);

has mugshots => (
	is => 'rw',
	isa => 'PersonalData::Mugshots',
	default => sub {
		return new PersonalData::Mugshots();
	}
);

has cache_dir => (
	is => 'rw',
	default => '',
	isa => subtype {
		as 'Str',
		where {
			/\/$/ && -d;
		}
	}
);

has disable_cache => (
	is => 'rw',
	isa => 'Bool',
	default => 0
);

sub pullFeed {
	my $self = shift @_;

	my $feed = [];
	
	if (my $page = $self->fetchPage($blotter_url)) {
		my $results = $index_scraper->scrape($page);
		
		foreach my $entry (@{$results->{entries}}) {
			$entry->{created} = $self->trim($entry->{created});
			
			if ($entry->{created}) {
				foreach my $field (keys %$entry) {
					$entry->{$field} = $self->trim($entry->{$field});
				}
				
				$entry->{created_ts} = str2time($self->trim($entry->{created}));
				$entry->{updated_ts} = length($self->trim($entry->{updated})) > 0 ? str2time($self->trim($entry->{updated})) : 1 == 0;
				$entry->{link} = $blotter_url . $self->trim($entry->{url});
				$entry->{md5} = md5_hex($entry->{link} . '-' . ($entry->{updated} ? $entry->{updated} : $entry->{created_ts}));
				
				my $cache_file = $self->cache_dir() . $entry->{md5} . '.json';
				
				if (-f $cache_file && !$self->disable_cache()) {
					$entry = decode_json(read_file($cache_file));
				} else {
					$self->mech()->get($entry->{link});
					if ($self->mech()->success) {
						my $detail_content = $self->mech()->content();
						my $details = $detail_scraper->scrape($detail_content);
						foreach my $field (@{$details->{report}->{fields}}) {
							$field->{label} =~ s/[^A-Za-z]+//g;
							$entry->{'detail_' . lc($field->{label})} = $self->trim($field->{value});
						}
						$entry->{detail_incidentdate} =~ s/ - / /;
						$entry->{detail_incidentdate} =~ s/ (AM|PM)/$1/;
						$entry->{detail_incidentdate_ts} = str2time($entry->{detail_incidentdate});
						
						
						if ($entry->{detail_arrested}) {
							$entry->{arrests} = $self->parseArrests($entry->{detail_arrested}); #$arrests;
						} # arrests?
						
					} # fetched blotter entry detail OK?
					write_file($cache_file, $json->encode($entry));
					push @$feed, $entry;
					if ($self->debug_output) {
						print STDERR Dumper($entry);
					}
					
				} # use cache?
			} # has created date
		} # foreach(entry)
	} # fetched feed page OK?
	
	return $feed;
} # pullFeed()

sub parseArrests {
	my $self = shift @_;
	my $details = shift @_;
	
	
	my $arrested = [split(/<br[^>]*>/, $details)];
	my $arrests = [];
	
	my $idx = 0;
	
	foreach my $line (@$arrested) {
		$idx++;
		my $ar = {
			name => '...',
			age => '...',
			gender => 'M',
			race => '...'
		};
		
		my $race_map = {
			'W' => 'White',
			'B' => 'Black',
			'A' => 'Asian',
			'H' => 'Hispanic',
			'L' => 'Hispanic'
		};
		
		if ($line =~ m/
		\b
		(?<gender>[MF]) # Male Female
		\/? 						# optional slash separator 
		(?<race>[WBHLA])
		\b/ix) {
			$ar->{race} = $race_map->{$+{race}};
		}
		if ($line =~ m/(?<name>[A-Za-z.\s]+),/xi) { $ar->{name} = $+{name}; }
		if ($line =~ m/age\s+(?<age>\d{2})/i || $line =~ m/(?<age>\d{2})\s+(?:YOA|years|yrs)/xi) { $ar->{age} = $+{age}; }
		
		if ($self->debug_output) {
			print STDERR "Arrest Line $idx: $line\n";
			print STDERR Dumper($ar);
		}
		
		
		if ($ar->{name} ne '...' && $ar->{age} ne '...') {
			$ar->{name} = $self->trim($ar->{name});
			$ar->{name} =~ s/[^A-Za-z0-9]+/ /gi;
			my @parts = split(/\s+/, $ar->{name}, 3);
			if (scalar @parts == 2) {
				$ar->{first_name} = $parts[0];
				$ar->{last_name} = $parts[1];
			} elsif (scalar @parts == 3) {
				$ar->{first_name} = $parts[0];
				$ar->{mi} = $parts[1];
				$ar->{last_name} = $parts[2];
			} # name style?
			
			
			
			my $arrested_person = new PersonalData::Person(%$ar);						
			
			if ($self->find_mugshots()) {
				$arrested_person->findMugshots();
				#$ar->{mugshots} = $self->mugshots->search($ar->{name});
			} # pull mugshots?
			
			push @$arrests, $arrested_person; #$ar;
		} # parsed name and age?
	} # foreach(arrest)
	
	#$entry->{arrests} = $arrests;
	return $arrests;
}

1;