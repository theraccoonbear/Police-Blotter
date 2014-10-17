package Property::Source::MadisonAssessor;

use Moose;

extends 'Property::Source';

use HTML::Form;
use Data::Dumper;
use Web::Scraper;

my $property_details_scraper = scraper {
	process '(//div[contains(@class, \'container\')]/div[contains(@class, \'row\')])[2]', 'columns' => scraper {
		process '(//div[contains(@class, \'span2\')])[1]', "col_1" => scraper {
			process '//li[contains(@class, \'nav-indent\')][2]', 'parcel_no[]' => 'TEXT';
		};
		
		process '(//div[contains(@class, \'span2\')])[2]', "col_2" => scraper {
			process '//div[contains(@class, \'clearfix\') and position() = 1 and contains(., \'Owner\')]', 'details' => scraper {
				process '//p[1]', 'owner' => 'TEXT';
				process '//p[2]', 'address' => 'TEXT';
			}
		};
		process '//div[contains(@class, \'span8\')]', "col_3" => scraper {
			process '//table[1]/tbody/tr[not(contains(@class, \'title-gray\'))]', 'assessments[]' => scraper {
				process '//td[1]', 'year' => 'TEXT';
				process '//td[2]', 'land' => 'TEXT';
				process '//td[3]', 'improvements' => 'TEXT';
				process '//td[4]', 'total' => 'TEXT';
			};
			process '//table[position() > 1]', 'sections[]' => scraper {
				process '//thead/*/th/span[contains(@class, \'pull-left\')]', 'name_span' => 'TEXT';
				process '//thead/*/th', 'name' => 'HTML';
				process '//tbody/tr', 'fields[]' => scraper {
					process '//th', 'label' => 'TEXT';
					process '//td', 'value' => 'TEXT';
				};
			};
		};	
	};
}; # property_details_scraper

my $property_list_scraper = scraper {
	process '//table[contains(@class, \'table\')]/tbody/tr', 'entries[]' => scraper {
		process '//td[1]/a', 'parcel_number' => 'TEXT', 'url' => '@href';
		process '//td[2]', 'address' => 'TEXT';
		process '//td[3]', 'owner' => 'TEXT';
	};
};

my $sales_conveyance_scraper = scraper {
	
}; # sales_conveyance_scraper

has 'searchForm' => (
	is => 'rw',
	isa => 'HTML::Form'
);



sub _beginSearch {
	my $self = shift @_;
	my $form_name = shift @_;
	
	my $form_url = 'http://www.cityofmadison.com/assessor/property/';
	
	$self->fetchPage($form_url);
	
	$self->searchForm($self->mech->form_name($form_name));
}



sub _processSearchResponse {
	my $self = shift @_;
	
	
	my $property = {result_type => 'failure'};
	
	if ($self->mech->success) {
		my $content = $self->mech->content();
		if ($content !~ m/There was an error encountered on the requested page./) {
			if ($content =~ m/Property Details/) {
				
				my $results = $property_details_scraper->scrape($content);
				
				$property->{result_type} = 'match';
				
				my $c1 = $results->{columns}->{col_1};
				my $c2 = $results->{columns}->{col_2};
				my $c3 = $results->{columns}->{col_3};
				
				$property->{Assessments} = $c3->{assessments};
				$property->{Owner} = $c2->{details}->{owner};
				$property->{Address} = $c2->{details}->{address};
				$property->{'Parcel Number'} = $c1->{parcel_no};
				foreach my $entry (@{ $c3->{sections} }) {
					my $name = defined $entry->{name_span} ? $entry->{name_span} : $entry->{name};
					my $sub_name = '';
					foreach my $fld (@{$entry->{fields}}) {
						$fld->{label} =~ s/\s+\(Size in sq ft\)//;
						if (!defined $fld->{value}) {
							$sub_name = $fld->{label};
						} else {
							my $key = $name . (length($sub_name) > 0 ? " / $sub_name" : '');
							if (! defined $property->{$key}) {
								$property->{$key} = {};
							}
							$property->{$key}->{$fld->{label}} = $fld->{value};
						} # value?
					} # foreach(fld)
				} # foreach(entry)
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
	} # mech success?
	
	return $property;
} # _processSearchResults

sub searchByAddress {
	my $self = shift @_;
	my $p = shift @_;
	
	my $addr = $self->_parseAddress($p);
	
	$self->_beginSearch('addressSearch');
	
	$self->mech->field("HouseNum", $addr->{street_number});
	$self->mech->field("StreetDir", $addr->{direction});
	$self->mech->field("StreetName", $addr->{street_name});
	$self->mech->field("StType", $addr->{street_type});
	$self->mech->field("Unit", '');
	$self->mech->submit_form();
	
	my $property = $self->_processSearchResponse();
	
	return $property;
}

sub searchByAddressRange {
	my $self = shift @_;
	my $addr = shift @_;
	
	$self->_beginSearch('AQ');
	
	$self->mech->field("HouseNum1", $addr->{street_number_1} || 1);
	$self->mech->field("HouseNum2", $addr->{street_number_2} || 9999);
	$self->mech->field("StreetDir", $addr->{direction});
	$self->mech->field("StreetName", $addr->{street_name});
	$self->mech->field("StType", $addr->{street_type});
	$self->mech->field("Unit", '');
	$self->mech->submit_form();
	
	my $property = $self->_processSearchResponse();
	
	return $property;
	
}

sub searchByLastName {
	my $self = shift @_;
	my $name = shift @_;
	
	$self->_beginSearch('nameSearch');
	
	$self->mech->field("LastName", $name);
	$self->mech->submit_form();
	
	my $property = $self->_processSearchResponse();
	
	return $property;
}

__PACKAGE__->meta->make_immutable;

1;