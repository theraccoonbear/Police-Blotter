package MadisonAssessor;

use Moose;

extends 'SBase';

use HTML::Form;
use Data::Dumper;

my $street_types = ["Avenue","Ave","Boulevard","Blvd","Bnd","Circle","Cir","Cres","Ct","Drive","Dr","Gln","Grn","Hts","Hwy","Ln","Mall","Pass","Path","Pkwy","Place","Pl","Plz","Ramp","Rd","Rdg","Row","RR","Run","Spur","Sq","Street","St","Ter","Trce","Trl","Vw","Walk","Way","Xing"];
my $street_type_remap = {
	'Avenue' => 'Ave',
	'Boulevard' => 'Blvd',
	'Circle' => 'Cir',
	'Drive' => 'Dr',
	'Place' => 'Pl',
	'Street' => 'St'
};

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
		my $street_types_rgx = join('|', @$street_types);
		my $direction_rgx = '[NSEW]|NE|SE|NW|SW|North|South|East|West';
		if ($address =~
		m/
			(?<street_number>\d+)
			
			\s+
			
			(?:(?<direction_1>$direction_rgx)\s+)?
			
			(?<street_name>[^,]+?)
			
			\s+
			
			(?<street_type>$street_types_rgx)
			
			(?:\s+(?<direction_2>$direction_rgx)\s+)?
		/xi) {
			
			$ret_address = {
				street_number => $+{street_number},
				direction => ($+{direction_1} || $+{direction_2} || ''),
				street_name => $+{street_name},
				street_type => $+{street_type}
			};
			
			if ($street_type_remap->{$ret_address->{street_type}}) {
				$ret_address->{street_type} = $street_type_remap->{$ret_address->{street_type}};
			}
		
		}
	}
	
	return $ret_address;
}

sub searchByAddress {
	my $self = shift @_;
	my $p = shift @_;
	
	$self->_beginSearch('addressSearch');
	
	my $addr = $self->_parseAddress($p);
	
	$self->mech->field("HouseNum", $addr->{street_number});
	$self->mech->field("StreetDir", $addr->{direction});
	$self->mech->field("StreetName", $addr->{street_name});
	$self->mech->field("StType", $addr->{street_type});
	$self->mech->field("Unit", '');
	$self->mech->submit_form();
	if ($self->mech->success) {
		print $self->mech->content();
	} else {
		print ":(";
	}
	
	
}

sub searchByAddressRange {
	my $self = shift @_;
	$self->_beginSearch('AQ');
}

sub searchByLastName {
	my $self = shift @_;
	$self->_beginSearch('nameSearch');
}


1;