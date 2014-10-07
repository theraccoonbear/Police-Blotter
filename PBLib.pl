package PBLib;

@EXPORT = qw(trim);

sub trim {
	my $v = shift @_;
	$v =~ s/^\s+//;
	$v =~ s/\s+$//;
	return $v;
}


1;