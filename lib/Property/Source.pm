package Property::Source;

use Moose;
use Lingua::EN::AddressParse;

extends 'Property';

our $street_types = ["Avenue","Ave","Boulevard","Blvd","Bnd","Circle","Cir","Cres","Ct","Drive","Dr","Gln","Grn","Hts","Hwy","Ln","Mall","Pass","Path","Pkwy","Place","Pl","Plz","Ramp","Rd","Rdg","Row","RR","Run","Spur","Sq","Street","St","Ter","Trce","Trl","Vw","Walk","Way","Xing"];
our $street_type_remap = {
	'Avenue' => 'Ave',
	'Boulevard' => 'Blvd',
	'Circle' => 'Cir',
	'Drive' => 'Dr',
	'Place' => 'Pl',
	'Street' => 'St'
};
our $street_dir_remap = {
	'east' => 'E',
	'west' => 'W',
	'north' => 'N',
	'south' => 'S'
};

my %address_parse_args = (
  country     => 'United States',
  auto_clean  => 1,
  force_case  => 1,
  abbreviate_subcountry => 0,
  abbreviated_subcountry_only => 1,
  force_post_code => 0
);

my $addr_parser = Lingua::EN::AddressParse->new(%address_parse_args);

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

1;