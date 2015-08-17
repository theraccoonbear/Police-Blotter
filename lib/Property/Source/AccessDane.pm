package Property::Source::AccessDane;

use Moose;
use Data::Printer;
use Web::Scraper;
use JSON::XS;

extends 'Property::Source';


has 'session_inited' => (
	is => 'rw',
	isa => 'Bool',
	default => 0
);


my $property_details_scraper = scraper {
	#process '#parcelDetail tr', 'fields[]' => scraper {
	#	process '//td[1]', 'label' => 'TEXT';
	#	process '//td[contains(@colspan, 2)]', 'value' => 'TEXT';
	#};
	
	process '#assessmentDetail thead th', 'years[]' => 'TEXT', 'year_col[]' => '@data-colnum';
	process '#assessmentDetail tbody tr', 'rows[]' => scraper {
		process 'td', 'values[]' => 'TEXT', 'year_col[]' => '@data-colnum';
	};
	
	#process '//div[contains(@class, \'taxDetailTable\')', 'taxDetails[]' => scraper {
	#	process 'table', 'year' => '@data-tableyear';
	#	process '//tr[1]/th', 'labels[]' => 'TEXT';
	#	process '//tr[2]/td', 'value[]' => 'TEXT';
	#	process '//tr[position() > 2]', 'extras[]' => scraper {
	#		process '//td[1]', 'label' => 'TEXT';
	#		process '//td[2]', 'value' => 'TEXT';
	#	}
	#};
}; # $property_details_scraper

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
	
	my $sr = $property_details_scraper->scrape($content);
	foreach my $fent (@{ $sr->{fields} }) {
		$parcel->{$self->trim($fent->{label})} = $self->trim($fent->{value});
	}
	foreach my $idx (@{ $sr->{year_col} }) {
		if ($idx =~ m/^\d+$/) {
			my $year = $self->trim($sr->{years}->[$idx]);
			if ($year =~ m/^\d+$/) {
				my $year_ent = {};
				foreach my $row (@{ $sr->{rows} }) {
					$year_ent->{$self->trim($row->{values}->[0])} = $self->trim($row->{values}->[$idx + 1]);
				}
				$parcel->{assessments}->{$year - 1} = $year_ent;
			}
		}
	}
	p($parcel);
	#print encode_json($sr);
	exit(0);
	#foreach my $tax_ent (@{ $sr->{taxDetails} }) {
	#	$parce->{taxes}->{$tax_ent->{year}} = 
	#}
	return $parcel;
}

sub _getSearchResults {
	my $self = shift @_;
	my $page =  $self->mech->content;
	my $result = [];
	
	if ($page =~ m/id="parcelTable"/) {
		push @$result, 'MULTIPLE'
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
	return $self->_getSearchResults();
}

sub searchByName {
	my $self = shift @_;
	my $term = shift @_;
	
	$self->_searchByType($term, 'getowners');
}

sub searchByAddress {
	my $self = shift @_;
	my $term = shift @_;
	
	my $addr = $self->_parseAddress($term);

	my $addr_ar = [];
	push @$addr_ar, $addr->{street_number};
	if (length($addr->{direction}) > 0) { push @$addr_ar, $addr->{direction}; }
	push @$addr_ar, $addr->{base_street_name};
	push @$addr_ar, $addr->{street_type};
	
	return $self->_searchByType(join(' ', @$addr_ar), 'getaddresses');
}

1;