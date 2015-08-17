#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib';
use HTTP::Cookies;
use Data::Printer;

use Property::Source::MadisonAssessor;
use Property::Source::AccessDane;

#my $assessor = new Property::Source::MadisonAssessor();
#
#my $results = $assessor->searchByLastName('smith');
#
#p($results);
#

my $AD = new Property::Source::AccessDane();


my $results = $AD->searchByAddress('5113 Melinda Dr, Madison, WI');
#p($results);
