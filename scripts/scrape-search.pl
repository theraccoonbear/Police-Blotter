#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib';
use HTTP::Cookies;
use Data::Printer;
use Web::Scraper;
use WWW::Mechanize;
use Property::Source::MadisonAssessor;
use Property::Source::AccessDane;

my $mech = WWW::Mechanize->new();

my $AD = new Property::Source::AccessDane();

my $people = [];
my $earth_scraper = scraper {
    process '.overlay', 'people[]' => scraper {
        process 'div', 'name' => sub {
            my $h = $_->as_HTML();
            if ($h =~ m/.*?<[^>]+>(?<name>[^<]+)/) {
                push @$people, [split(/ /, $+{name})];
            }
            return $h;
        };
    };
};

$mech->get('http://www.earthlinginteractive.com/about');
my $page = $mech->content;
$earth_scraper->scrape($page);
print "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
foreach my $p (@$people) {
    my $addr = $AD->searchByName($p->[0] . ' ' . $p->[1]);
    print "$p->[0] $p->[1] : ";
    if (scalar @{ $addr->{data} } == 0) {
        print "NO MATCHES"
    } elsif (scalar @{ $addr->{data} } == 1) {
        print "$addr->{data}->[0]->{Primary_Address}, $addr->{data}->[0]->{City}\n";
    } else {
        print "\n";
        for (my $i = 0; $i < scalar @{ $addr->{data} } && $i < 5; $i++) {
            my $ent = $addr->{data}->[$i];
            print "  - $ent->{Address}, $ent->{City}\n";
        }
    }
    
    print "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"
}
