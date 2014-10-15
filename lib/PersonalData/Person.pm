package PersonalData::Person;

use Moose;
use Data::Dumper;
use PersonalData::Mugshots;
use PersonalData::DriversLicense;

extends 'PersonalData';

my $props = {
	'name' => {},
	'first_name' => {},
	'mi' => {},
	'last_name' => {},
	'age' => {isa => 'Int'},
	'gender' => {default => 'M'},
	'race' => {default => 'W'},
	'DL' => {},
	'address' => {},
	'address_2' => {},
	'city' => {},
	'state' => {},
	'phone' => {},
	'mugshots' => {isa => 'ArrayRef[HashRef]', default => sub { return []; }},
	'cases' => {isa => 'ArrayRef[HashRef]', default => sub { return []; }},
	'property' => {isa => 'ArrayRef[HashRef]', default => sub { return []; }}
};

has _mugshot_search => (
	is => 'rw',
	isa => 'PersonalData::Mugshots',
	default => sub {
		return new PersonalData::Mugshots();
	}
);

has _DL_helper => (
	is => 'rw',
	isa => 'PersonalData::DriversLicense',
	default => sub {
		return new PersonalData::DriversLicense();
	}
);

foreach my $p (keys %$props) {
	my %options = (
		is => 'rw',
		isa => 'Str',
		default => ''
	);
	
	my %newHash = (%options, %{$props->{$p}});
	%options = %newHash;
	
	
	has $p => %options;
}

sub BUILD {
	my $self = shift @_;
	
	#if (length($self->DL) < 1) {
		$self->DL($self->_DL_helper->gleanDL($self->TO_JSON()));
	#}
}

sub fleshOut {
	my $self = shift @_;
	my $fields = shift @_;
	
	foreach my $fld_name (keys %$fields) {
		$self->$fld_name($fields->{$fld_name});
	}
}

sub findMugshots {
	my $self = shift @_;
	
	$self->mugshots($self->_mugshot_search->search($self->name));
}

sub TO_JSON {
	my $self = shift @_;
	
	my $fields = {};
	foreach my $p (keys %$props) {
		$fields->{$p} = $self->$p;
	}
	return $fields;
}

1;