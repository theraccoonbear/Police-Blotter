package Property::Source::AccessDane;

use Moose;
use Data::Printer;
use Data::Dumper;
use Web::Scraper;
use JSON::XS;

extends 'Property::Source';


has 'session_inited' => (
	is => 'rw',
	isa => 'Bool',
	default => 0
);




my $property_list_scraper = scraper {
	
}; # $property_list_scraper

sub init {
	my $self = shift @_;
	if ($self->session_inited) {
		return;
	} else {
		$self->mech->get('https://accessdane.countyofdane.com/');
		$self->session_inited(1);
	}
}

sub _getParcelData {
	my $self = shift @_;
	my $content = shift @_;
	my $parcel = {
		taxes => {},
		assessments => {}
	};
	
	my $property_details_scraper = scraper {
		process '#parcelDetail tr', 'fields[]' => scraper {
			process '//td[1]', 'label' => 'TEXT';
			process '//td[contains(@colspan, 2)]', 'value' => sub {
				my $val = $_->as_HTML();
				$val =~ s/<li>/\n/g;
				$val = $self->trim($self->strip($val));
				$val =~ s/\n/, /g;
				return $val;
			};
		};
		
		process '#assessmentDetail thead th', 'years[]' => 'TEXT';
		process '#assessmentDetail tbody tr', 'rows[]' => scraper {
			process 'td', 'values[]' => 'TEXT';
		};
		
		process '//div[contains(@class, \'taxDetailTable\')', 'taxDetails[]' => scraper {
			process 'table', 'year' => '@data-tableyear';
			process '//tr[1]/th', 'labels[]' => 'TEXT';
			process '//tr[2]/td', 'value[]' => 'TEXT';
			process '//tr[position() > 2]', 'extras[]' => scraper {
				process '//td[1]', 'label' => 'TEXT';
				process '//td[2]', 'value' => 'TEXT';
			}
		};
	}; # $property_details_scraper
	
	
	my $sr = $property_details_scraper->scrape($content);
	
	foreach my $fent (@{ $sr->{fields} }) {
		my $label = $self->trim($fent->{label});
		$label =~ s/\s+/_/g;
		$parcel->{$label} = $self->trim($fent->{value});
	}
	
	my $highest_year = 0;
	my $highest_year_assessment = 0;
	my $y_idx = -1;
	foreach my $year (@{ $sr->{years} }) {
		$year = $self->trim($year);
		$y_idx++;
		if ($year =~ m/^\d{4}$/) {
			my $assess_ent = {};
			foreach my $fent (@{ $sr->{rows} }) {
				my $fname = $self->trim($fent->{values}->[0]);
				$fname =~ s/\s+/_/g;
				$assess_ent->{$fname} = $self->trim($fent->{values}->[$y_idx]);
			}
			if ($highest_year < $year && $assess_ent->{'Estimated_Fair_Market_Value'} =~ m/\d/) {
				$highest_year_assessment = $assess_ent->{'Estimated_Fair_Market_Value'};
				$highest_year = $year;
			}
			
			$parcel->{assessments}->{$year} = $assess_ent;
		}
	}
	$parcel->{'Assessed_Value'} = $highest_year_assessment;
	$parcel->{City} = $parcel->{Municipality_Name};
	$parcel->{City} =~ s/^(CITY|TOWN|VILLAGE)\s+OF\s+//gi;
	return $parcel;
}

sub _getParcelList {
	my $self = shift @_;
	my $content = shift @_;
	
	my $list_scraper = scraper {
		process '#parcelTable tbody tr', 'entries[]' => scraper {
			
			process 'td strong a', 'Parcel_Number' => 'TEXT';
			process 'td strong', 'City' => sub {
				my $html = $_->as_HTML();
				my $city = 'UNKNOWN';
				if ($html =~ m/<br[^>]*>(?<city>[^<]+)/) {
					$city = $self->trim($+{city});
					$city =~ s/(CITY|VILLAGE|TOWN)\s+OF\s+//;
				}
				return $city;
			};
			process 'td ul li', 'Owners[]' => 'TEXT';
			process 'td div', 'Address' => sub { return $self->trim($self->strip($_->as_HTML())); };
		}
	};
	
	my $results = $list_scraper->scrape($content);
	return $results->{entries} || [];
}

sub _getSearchResults {
	my $self = shift @_;
	my $page =  $self->mech->content;
	my $result = [];
	
	if ($page =~ m/Parcel Not Found/) {
		# :(
	} elsif ($page =~ m/id="parcelTable"/) {
		$result = $self->_getParcelList($page);
	} else {
		push @$result, $self->_getParcelData($page);
	}
	return $result;
}

sub _searchByType {
	my $self = shift @_;
	my $term = shift @_;
	my $type = shift @_ || 'getowners';
	
	my $types = {
		getaddresses => 'getaddresses',
		getowners => 'getowners'
	};
	
	$type = $types->{$type} || 'getowners';
	
	$self->init();
	
	my $url = 'https://accessdane.countyofdane.com/Parcel/QuickSearch';
	my $params = [
		searchButton => $type,
		searchTerm => $term,
		searchValue => ''
	];
	
	$self->mech->post($url, $params);
	return {
		data =>$self->_getSearchResults(),
		search_type => $type,
		search_term => $term
	};
}

sub searchByName {
	my $self = shift @_;
	my $term = shift @_;
	
	return $self->_searchByType($term, 'getowners');
}

sub searchByAddress {
	my $self = shift @_;
	my $term = shift @_;
	
	my $addr = $self->_parseAddress($term);
	
	my $addr_ar = [];
	push @$addr_ar, $addr->{street_number};
	if (length($addr->{direction}) > 0) { push @$addr_ar, $addr->{direction}; }
	push @$addr_ar, $addr->{street_name} || $addr->{base_street_name};
	push @$addr_ar, $addr->{street_type};
	
	return $self->_searchByType(join(' ', @$addr_ar), 'getaddresses');
}

1;