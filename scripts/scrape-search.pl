#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib';
use HTTP::Cookies;
use Data::Printer;

use Property::Source::MadisonAssessor;
use Property::Source::AccessDane;


my $AD = new Property::Source::AccessDane();


my $results = $AD->searchByAddress('514 E. Wilson St, Madison, WI');
p($results);
