#!/usr/bin/perl
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

my $previous_fh = select(STDOUT);
$| = 1;
select($previous_fh);

my $disable_cache = 1;

my $location;
my $base_script_dir;

BEGIN {
	$location = __FILE__;
	$base_script_dir = dirname($location);
	if (-f $location && -l $location) {
		$location = abs_path($location);
		$base_script_dir = dirname($location);
	}
	$base_script_dir .= '/';
	unshift @INC, $base_script_dir . 'lib';
}


use PersonalData;
use PersonalData::Person;
use PersonalData::CCAP;
use PersonalData::Mugshots;
use PersonalData::DriversLicense;


sub trim {
	my $v = unidecode(decode_entities(shift @_ || ''));
	$v =~ s/^\s+//;
	$v =~ s/\s+$//;
	return $v;
}

my $mech = WWW::Mechanize->new(
	agent => 'Madison Police Blotter Bot 1.0',
	autocheck => 0,
	cookie_jar => HTTP::Cookies->new( file => "$ENV{HOME}/.police-blotter-cookies.txt" )
);

my $mugshots = new PersonalData::Mugshots(state => 'Wisconsin');
my $ccap = new PersonalData::CCAP();
my $dl = new PersonalData::DriversLicense();



my $base_url = 'http://www.cityofmadison.com';
my $blotter_rss_url = $base_url . '/police/newsroom/incidentreports/rss.cfm?a=71';
my $blotter_url = $base_url . '/police/newsroom/incidentreports/';


$mech->get($blotter_url);

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

if ($mech->success()) {
	my $page = $mech->content();
	
	my $results = $index_scraper->scrape($page);
	
	foreach my $entry (@{$results->{entries}}) {
		$entry->{created} = trim($entry->{created});
		
		if ($entry->{created}) {
			
			
			foreach my $field (keys %$entry) {
				$entry->{$field} = trim($entry->{$field});
			}
			
			$entry->{created_ts} = str2time(trim($entry->{created}));
			$entry->{updated_ts} = length(trim($entry->{updated})) > 0 ? str2time(trim($entry->{updated})) : 1 == 0;
			$entry->{link} = $blotter_url . trim($entry->{url});
			$entry->{md5} = md5_hex($entry->{link} . '-' . ($entry->{updated} ? $entry->{updated} : $entry->{created_ts}));
			
			my $cache_file = $base_script_dir .  'cache/' . $entry->{md5} . '.json';
			
			if (-f $cache_file && !$disable_cache) {
				$entry = decode_json(read_file($cache_file));
			} else {
				$mech->get($entry->{link});
				if ($mech->success) {
					my $detail_content = $mech->content();
					my $details = $detail_scraper->scrape($detail_content);
					foreach my $field (@{$details->{report}->{fields}}) {
						$field->{label} =~ s/[^A-Za-z]+//g;
						$entry->{'detail_' . lc($field->{label})} = trim($field->{value});
					}
					$entry->{detail_incidentdate} =~ s/ - / /;
					$entry->{detail_incidentdate} =~ s/ (AM|PM)/$1/;
					$entry->{detail_incidentdate_ts} = str2time($entry->{detail_incidentdate});
					
					
					if ($entry->{detail_arrested}) {
						my $arrested = [split(/<br[^>]*>/, $entry->{detail_arrested})];
						my $arrests = [];
						
						foreach my $line (@$arrested) {
							my $ar = {
								name => '...',
								age => '...',
								gender => 'M'
							};
							if ($line =~ m/(?<name>[^,]+),.+(age\s+\d{2}|\d{2}\sYOA)/i) { $ar->{name} = $+{name}; }
							if ($line =~ m/age\s+(?<age>\d{2})/i || $line =~ m/(?<age>[\d]{2})\sYOA/i) { $ar->{age} = $+{age}; }
							if ($ar->{name} ne '...' && $ar->{age} ne '...') {
								$ar->{name} = trim($ar->{name});
								$ar->{name} =~ s/[^A-Za-z0-9]+/ /gi;
								my @parts = split(/\s+/, $ar->{name});
								if (scalar @parts == 2) {
									$ar->{first_name} = $parts[0];
									$ar->{last_name} = $parts[1];
								} elsif (scalar @parts == 3) {
									$ar->{first_name} = $parts[0];
									$ar->{mi} = $parts[1];
									$ar->{last_name} = $parts[2];
								}
								
								$ar->{mugshots} = $mugshots->search($ar->{name});
								
								push @$arrests, $ar;
							}
						}
						
						$entry->{arrests} = $arrests;
					}
					
				}
				write_file($cache_file, encode_json($entry));
			}
			
			print Dumper($entry);
		}
	}
	
}

