package PersonalData::DriversLicense;

use Moose;

extends 'PersonalData';

use Text::Soundex;
use Date::Parse;

my $tables = {
	"DL" => {
		"first_name" => {
			"Albert" => 20,
			"Frank" => 260,
			"Marvin" => 580,
			"Alice" => 20,
			"George" => 300,
			"Mary" => 580,
			"Ann" => 40,
			"Grace" => 300,
			"Melvin" => 600,
			"Anna" => 40,
			"Harold" => 340,
			"Mildred" => 600,
			"Anne" => 40,
			"Harriet" => 340,
			"Patricia" => 680,
			"Annie" => 40,
			"Harry" => 360,
			"Paul" => 680,
			"Arthur" => 40,
			"Hazel" => 360,
			"Richard" => 740,
			"Bernard" => 80,
			"Helen" => 380,
			"Robert" => 760,
			"Bette" => 80,
			"Henry" => 380,
			"Ruby" => 740,
			"Bettie" => 80,
			"James" => 440,
			"Ruth" => 760,
			"Betty" => 80,
			"Jane" => 440,
			"Thelma" => 820,
			"Carl" => 120,
			"Jayne" => 440,
			"Thomas" => 820,
			"Catherine" => 120,
			"Jean" => 460,
			"Walter" => 900,
			"Charles" => 140,
			"Joan" => 480,
			"Wanda" => 900,
			"Dorthy" => 180,
			"John" => 460,
			"William" => 920,
			"Edward" => 220,
			"Joseph" => 480,
			"Wilma" => 920,
			"Elizabeth" => 220,
			"Margaret" => 560,
			"Florence" => 260,
			"Martin" => 560,
			"Donald" => 180,
			"Clara" => 140
		},
		"first_initial" => {
			"A" => 0,
			"H" => 320,
			"O" => 640,
			"V" => 860,
			"B" => 60,
			"I" => 400,
			"P" => 660,
			"W" => 880,
			"C" => 100,
			"J" => 420,
			"Q" => 700,
			"X" => 940,
			"D" => 160,
			"K" => 500,
			"R" => 720,
			"Y" => 960,
			"E" => 200,
			"L" => 520,
			"S" => 780,
			"Z" => 980,
			"F" => 240,
			"M" => 540,
			"T" => 800,
			"G" => 280,
			"N" => 620,
			"U" => 840
		},
		"middle_initial" => {
			"A" => 1,
			"H" => 8,
			"O" => 14,
			"V" => 18,
			"B" => 2,
			"I" => 9,
			"P" => 15,
			"W" => 19,
			"C" => 3,
			"J" => 10,
			"Q" => 15,
			"X" => 19,
			"D" => 4,
			"K" => 11,
			"R" => 16,
			"Y" => 19,
			"E" => 5,
			"L" => 12,
			"S" => 17,
			"Z" => 19,
			"F" => 6,
			"M" => 13,
			"T" => 18,
			"G" => 7,
			"N" => 14,
			"U" => 18
		}
	}
};

# month_multiplier varies by state. Illinois uses 31. Wisconsin and Florida both use 40.
has month_multiplier => (
	is => 'rw',
	isa => 'Int',
	default => 40
);

#General: (birth_month - 1) * month_multiplier + birth_day + gender_mod
#
#Florida: (birth_month - 1) * 40 + birth_day + (male:0, female: 500)
#
#Illinois: (birth_month - 1) * 31 + birth_day + (male:0, female: 600)
#
#Wisconsin: (birth_month - 1) * 40 + birth_day + (male:0, female: 500)
has gender_value_male => (
	is => 'rw',
	isa => 'Int',
	default => 0
);

has gender_value_female => (
	is => 'rw',
	isa => 'Int',
	default => 500
);

sub gleanDL {
	my $self = shift @_;
	my $known = shift @_;
	

	my $tmp = '';
	
	my $dob = {
		'year' => '??',
		'month' => '??',
		'day' => '??'
	};
	
	if ($known->{DOB}) {
		# ($ss,$mm,$hh,$day,$month,$year,$zone)
		my @temp_date = strptime($known->{DOB});
		$dob->{year} = substr($temp_date[5], -2, 2);
		$dob->{month} = $temp_date[4] + 1;
		$dob->{day} = $temp_date[3];
	}
	
	
	my $parts = [];
	if ($known->{last_name}) {
		push @$parts, soundex($known->{last_name});
	} else {
		push @$parts, '????';
	}
	
	my $first_mid = '???';
	if ($known->{first_name} && ($known->{middle_name} || $known->{mi})) {
		my $mi = $tables->{DL}->{middle_initial}->{uc($known->{mi} ? $known->{mi} : substr($known->{middle_name}, 0, 1))};
		
		if ($tables->{DL}->{first_name}->{$known->{first_name}}) {
			$first_mid = $tables->{DL}->{first_name}->{$known->{first_name}} + $mi;
		} elsif ($tables->{DL}->{first_initial}->{substr($known->{first_name}, 0, 1)}) {
			$first_mid = $tables->{DL}->{first_initial}->{substr($known->{first_name}, 0, 1)} + $mi;
		}
	}
	#$first_mid = sprintf('%03d', $first_mid . substr($dob->{year}, 0, 1));
	$tmp = $first_mid . substr($dob->{year}, 0, 1);
	$first_mid = ('0' x (3 - length($tmp))) . $tmp;
	push @$parts, $first_mid;
	
	my $mon_day_gen = '???';
	if ($dob->{month} ne '??' && $dob->{day} ne '??' && $known->{gender}) {
		$mon_day_gen = (($dob->{month} - 1) * $self->month_multiplier()) + $dob->{day} + ($known->{gender} =~ m/[Ff]/ ? $self->gender_value_female() : $self->gender_value_male());
		#print $mon_day_gen; exit(0);
		#$mon_day_gen = substr($dob->{year}, -1, 1) . $mon_day_gen;
		
	}
	
	#$first_mid = sprintf('%03d', $first_mid . substr($dob->{year}, 0, 1));
	$tmp = $mon_day_gen;
	$mon_day_gen = ('0' x (3 - length($tmp))) . $tmp;
	push @$parts, substr($dob->{year}, -1, 1) . $mon_day_gen; # sprintf('%03d', $mon_day_gen);
	
	push @$parts, '??'; # last two are sequence/unknown
	
	
	return join('-', @$parts);
}



sub DLMonthDayGender {
	my($Month, $Day, $Gender) = @_;
	my($DateNo);

	$DateNo = ($Month - 1) * 40 + $Day;
	if($Gender eq 'F') { $DateNo += 500; }

	$DateNo = sprintf("%03d",$DateNo);

	return($DateNo);
}

1;