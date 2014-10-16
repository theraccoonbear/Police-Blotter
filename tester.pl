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

use MadisonAssessor;
use MadisonAssessor::Property;

my $assessor = new MadisonAssessor();

$assessor->searchByAddress('2702 Commercial Ave, Madison, WI 53704');

#my $pb = new PoliceBlotter(
#	disable_cache => 1,
#	debug_output => 1,
#	cache_dir => $base_script_dir . 'cache/'
#);

##my $mugshots = new PersonalData::Mugshots(state => 'Wisconsin');
##my $ccap = new PersonalData::CCAP();
#my $dl = new PersonalData::DriversLicense();
#
#
#
#print $dl->gleanDL({
#	first_name => 'John',
#	mi => 'M',
#	last_name => 'Doe',
#	DOB => '01/01/1950',
#	gender => 'M'
#});



#my $feed = $pb->pullFeed();
#print Dumper($feed);