package PersonalData::Person;

use Moose;
use Data::Dumper;

extends 'PersonalData';

my $props = {
	'name' => {},
	'first_name' => {},
	'mi' => {},
	'last_name' => {},
	'age' => {isa => 'Int'},
	'gender' => {default => 'M'},
	'address' => {},
	'address_2' => {},
	'city' => {},
	'state' => {},
	'phone' => {},
	'mugshots' => {isa => 'ArrayRef[HashRef]'},
	'cases' => {isa => 'ArrayRef[HashRef]'},
	'property' => {isa => 'ArrayRef[HashRef]'}
};

foreach my $p (keys %$props) {
	my %options = (
		is => 'rw',
		isa => 'Str',
		default => ''
	);
	
	my %newHash = (%options, %{$props->{$p}});
	%options = %newHash;
	
	#print "$p:\n";
	#print Dumper({%options});
	
	has $p => %options;
}

#print Dumper($props);
1;