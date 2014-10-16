package MadisonAssessor;

use Moose;

extends 'SBase';

use HTML::Form;
use Data::Dumper;
use Lingua::EN::AddressParse;
use Web::Scraper;

my %address_parse_args = (
  country     => 'United States',
  auto_clean  => 1,
  force_case  => 1,
  abbreviate_subcountry => 0,
  abbreviated_subcountry_only => 1,
  force_post_code => 0
);
 
my $addr_parser = Lingua::EN::AddressParse->new(%address_parse_args);

my $street_types = ["Avenue","Ave","Boulevard","Blvd","Bnd","Circle","Cir","Cres","Ct","Drive","Dr","Gln","Grn","Hts","Hwy","Ln","Mall","Pass","Path","Pkwy","Place","Pl","Plz","Ramp","Rd","Rdg","Row","RR","Run","Spur","Sq","Street","St","Ter","Trce","Trl","Vw","Walk","Way","Xing"];
my $street_type_remap = {
	'Avenue' => 'Ave',
	'Boulevard' => 'Blvd',
	'Circle' => 'Cir',
	'Drive' => 'Dr',
	'Place' => 'Pl',
	'Street' => 'St'
};
my $street_dir_remap = {
	'east' => 'E',
	'west' => 'W',
	'north' => 'N',
	'south' => 'S'
};

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
				process '//thead/*/th/*/span[contains(@class, \'pull-left\')]', 'name_span' => 'TEXT';
				process '//thead/*/th', 'name' => 'TEXT';
				process '//tbody/tr', 'fields[]' => scraper {
					process '//th', 'label' => 'TEXT';
					process '//td', 'value' => 'TEXT';
				};
			};
		};	
	};
}; # property_details_scraper

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

sub _parseAddress {
	my $self = shift @_;
	my $address = shift @_;
	
	my $ret_address = {
		street_number => '',
		direction => '',
		street_name => '',
		street_type => ''
	};
	
	if (ref($address) eq 'HASH') {
		$ret_address = $address;
	} else {
		my $error = $addr_parser->parse($address);
		
		$ret_address = {$addr_parser->components};
		$ret_address->{original} = $address;
		$ret_address->{state} = $ret_address->{subcountry} || 'WI';
		$ret_address->{city} = $ret_address->{suburb} || 'Madison';
		$ret_address->{street_number} = $ret_address->{property_identifier} || '';
		$ret_address->{street_name} = $ret_address->{street} || '';
		delete $ret_address->{subcountry};
		delete $ret_address->{suburb};
		delete $ret_address->{property_identifier};
		delete $ret_address->{street};
		delete $ret_address->{street_direction};
		delete $ret_address->{country};
		delete $ret_address->{pre_cursor};
		delete $ret_address->{po_box_type};
		delete $ret_address->{post_box};
		delete $ret_address->{road_box};
		delete $ret_address->{sub_property_identifier};
		delete $ret_address->{property_name};
		
		if ($street_type_remap->{$ret_address->{street_type}}) {
			$ret_address->{street_type} = $street_type_remap->{$ret_address->{street_type}};
		}
		$ret_address->{direction} = '';
		
		if ($ret_address->{street_name} =~ /^(?<direction>[NSEW]|North|South|East|West)\s+(?<street>.+)$/gi) {
			$ret_address->{direction} = $+{direction};
			$ret_address->{street_name} = $+{street};
		} elsif ($ret_address->{street_name} =~ /^(?<street>.+?)\s+(?<direction>[NSEW]|North|South|East|West)$/gi) {
			$ret_address->{direction} = $+{direction};
			$ret_address->{street_name} = $+{street};
		}
		
		if ($street_dir_remap->{lc($ret_address->{direction})}) {
			$ret_address->{direction} = $street_dir_remap->{lc($ret_address->{direction})};
		}
	}
	
	return $ret_address;
} # _parseAddress

sub searchByAddress {
	my $self = shift @_;
	my $p = shift @_;
	
	my $addr = $self->_parseAddress($p);
	my $property = {};
	
	$self->_beginSearch('addressSearch');
	
	$self->mech->field("HouseNum", $addr->{street_number});
	$self->mech->field("StreetDir", $addr->{direction});
	$self->mech->field("StreetName", $addr->{street_name});
	$self->mech->field("StType", $addr->{street_type});
	$self->mech->field("Unit", '');
	$self->mech->submit_form();
	if ($self->mech->success) {
		my $content = $self->mech->content();
		if ($content !~ m/There was an error encountered on the requested page./) {
			my $results = $property_details_scraper->scrape($content);
			print Dumper($results);
		}
	}
	
	return $property;
}

sub searchByAddressRange {
	my $self = shift @_;
	$self->_beginSearch('AQ');
}

sub searchByLastName {
	my $self = shift @_;
	$self->_beginSearch('nameSearch');
}

__PACKAGE__->meta->make_immutable;

1;