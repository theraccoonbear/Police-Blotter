package Property::Source::AccessDane;

use Moose;
use Data::Dumper;
use Web::Scraper;

extends 'Property::Source';

my $municipalities = {
	"" => "0",
	"CITY OF EDGERTON" => "62",
	"CITY OF FITCHBURG" => "16",
	"CITY OF MADISON" => "61",
	"CITY OF MIDDLETON" => "51",
	"CITY OF MONONA" => "60",
	"CITY OF STOUGHTON" => "59",
	"CITY OF SUN PRAIRIE" => "56",
	"CITY OF VERONA" => "57",
	"TOWN OF ALBION" => "1",
	"TOWN OF BERRY" => "3",
	"TOWN OF BLACK EARTH" => "4",
	"TOWN OF BLOOMING GROVE" => "5",
	"TOWN OF BLUE MOUNDS" => "6",
	"TOWN OF BRISTOL" => "7",
	"TOWN OF BURKE" => "8",
	"TOWN OF CHRISTIANA" => "9",
	"TOWN OF COTTAGE GROVE" => "10",
	"TOWN OF CROSS PLAINS" => "11",
	"TOWN OF DANE" => "12",
	"TOWN OF DEERFIELD" => "13",
	"TOWN OF DUNKIRK" => "14",
	"TOWN OF DUNN" => "15",
	"TOWN OF MADISON" => "17",
	"TOWN OF MAZOMANIE" => "18",
	"TOWN OF MEDINA" => "19",
	"TOWN OF MIDDLETON" => "20",
	"TOWN OF MONTROSE" => "21",
	"TOWN OF OREGON" => "22",
	"TOWN OF PERRY" => "23",
	"TOWN OF PLEASANT SPRINGS" => "24",
	"TOWN OF PRIMROSE" => "25",
	"TOWN OF ROXBURY" => "26",
	"TOWN OF RUTLAND" => "27",
	"TOWN OF SPRINGDALE" => "28",
	"TOWN OF SPRINGFIELD" => "29",
	"TOWN OF SUN PRAIRIE" => "30",
	"TOWN OF VERMONT" => "31",
	"TOWN OF VERONA" => "32",
	"TOWN OF VIENNA" => "33",
	"TOWN OF WESTPORT" => "34",
	"TOWN OF WINDSOR" => "35",
	"TOWN OF YORK" => "36",
	"VILLAGE OF BELLEVILLE" => "37",
	"VILLAGE OF BLACK EARTH" => "38",
	"VILLAGE OF BLUE MOUNDS" => "39",
	"VILLAGE OF BROOKLYN" => "40",
	"VILLAGE OF CAMBRIDGE" => "41",
	"VILLAGE OF COTTAGE GROVE" => "42",
	"VILLAGE OF CROSS PLAINS" => "43",
	"VILLAGE OF DANE" => "44",
	"VILLAGE OF DEERFIELD" => "45",
	"VILLAGE OF DEFOREST" => "46",
	"VILLAGE OF MAPLE BLUFF" => "47",
	"VILLAGE OF MARSHALL" => "48",
	"VILLAGE OF MAZOMANIE" => "49",
	"VILLAGE OF MCFARLAND" => "50",
	"VILLAGE OF MOUNT HOREB" => "52",
	"VILLAGE OF OREGON" => "53",
	"VILLAGE OF ROCKDALE" => "54",
	"VILLAGE OF WAUNAKEE" => "58",
	"VILLAGE OF SHOREWOOD HILLS" => "55"
};

my $property_details_scraper = scraper {
	process '#parcelDetail tr', 'fields[]' => scraper {
		process '//td[1]', 'label' => 'TEXT';
		process '//td[contains(@colspan, 2)]', 'value' => 'TEXT';
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

my $property_list_scraper = scraper {
	
}; # $property_list_scraper


sub _getMuniCode {
	my $self = shift @_;
	my $name = shift @_;
	
	my $base_name = uc($self->trim($name));
	$name = $base_name;
	
	if (!$municipalities->{$name}) {
		$name = 'CITY OF ' . $base_name;
		if (!$municipalities->{$name}) {
			$name = 'TOWN OF ' . $base_name;
			if (!$municipalities->{$name}) {
				$name = 'VILLAGE OF ' . $base_name;
				if (!$municipalities->{$name}) {
					$name = '';
				}
			}
		}
	}
	
	my $code = $municipalities->{$name};
	
	return $code;
} # _getMuniCode()

sub _beginSearch {
	my $self = shift @_;
	my $form_name = shift @_ || 'owner';
	
	my $form_mapping = {
		'owner' => 2,
		'address' => 3
	};
	
	if (! $form_mapping->{$form_name}) {
		$form_name = 'owner';
	}
	
	
	$self->fetchPage('https://accessdane.countyofdane.com/Parcel');
	my $form = $self->mech->form_number($form_mapping->{$form_name});
} # _beginSearch()


sub _processSearchResponse {
	my $self = shift @_;
	
	my $property = {result_type => 'failure'};
	
	if ($self->mech->success) {
		my $content = $self->mech->content();
		
		
		if ($content !~ m/A matching parcel could not be found./) {
			if ($content =~ m/Parcel Detail/) {
				
				my $results = $property_details_scraper->scrape($content);
				print Dumper($results);
				exit(0);
				$property->{result_type} = 'match';
				
				
				
				#my $c1 = $results->{columns}->{col_1};
				#my $c2 = $results->{columns}->{col_2};
				#my $c3 = $results->{columns}->{col_3};
				#
				#$property->{Assessments} = $c3->{assessments};
				#$property->{Owner} = $c2->{details}->{owner};
				#$property->{Address} = $c2->{details}->{address};
				#$property->{'Parcel Number'} = $c1->{parcel_no};
				#foreach my $entry (@{ $c3->{sections} }) {
				#	my $name = defined $entry->{name_span} ? $entry->{name_span} : $entry->{name};
				#	my $sub_name = '';
				#	foreach my $fld (@{$entry->{fields}}) {
				#		$fld->{label} =~ s/\s+\(Size in sq ft\)//;
				#		if (!defined $fld->{value}) {
				#			$sub_name = $fld->{label};
				#		} else {
				#			my $key = $name . (length($sub_name) > 0 ? " / $sub_name" : '');
				#			if (! defined $property->{$key}) {
				#				$property->{$key} = {};
				#			}
				#			$property->{$key}->{$fld->{label}} = $fld->{value};
				#		} # value?
				#	} # foreach(fld)
				#} # foreach(entry)
			} else {
				$property->{result_type} = 'multiple';
				$property->{entries} = [];
				my $results = $property_list_scraper->scrape($content);
				
				foreach my $entry (@{$results->{entries}}) {
					foreach my $fld (keys %{$entry}) {
						$entry->{$fld} = $self->trim($entry->{$fld});
					} # foreach(fld)
					push @{$property->{entries}}, $entry;
				} # foreach(entry)
			} # list
		} # non-error?
	} else { # mech success?
		print Dumper($self->mech);
		print ":(\n";	
	}
	
	return $property;
} # _processSearchResponse()

sub searchByAddress {
	my $self = shift @_;
	my $p = shift @_;
	
	$self->_beginSearch('address');
	
	my $addr = $self->_parseAddress($p);
	
	$self->mech->field("Address.HouseNumber", $addr->{street_number});
	$self->mech->field("Address.PrefixDirection", $addr->{direction});
	$self->mech->field("Address.StreetName", $addr->{street_name});
	$self->mech->field("Address.StreetType", $addr->{street_type});
	$self->mech->field("Address.SelectedMunicipality", $self->_getMuniCode($addr->{city}));
	$self->mech->submit_form();
	
	my $property = $self->_processSearchResponse();
	
	return $property;
}

1;