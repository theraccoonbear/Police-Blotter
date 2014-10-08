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
use PoliceBlotter;
use PersonalData::CCAP;
use PersonalData::Mugshots;
use PersonalData::DriversLicense;

my $pb = new PoliceBlotter(
	disable_cache => 1,
	cache_dir => $base_script_dir . 'cache/'
);
#my $mugshots = new PersonalData::Mugshots(state => 'Wisconsin');
#my $ccap = new PersonalData::CCAP();
my $dl = new PersonalData::DriversLicense();



print $dl->gleanDL({
	first_name => 'Donald',
	mi => 'C',
	last_name => 'Smith',
	DOB => '03/02/1979',
	gender => 'M'
});


print Dumper($pb->pullFeed());