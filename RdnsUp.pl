#!/usr/bin/perl
use integer;
use strict;
use warnings;
use Getopt::Std;
$Getopt::Std::STANDARD_HELP_VERSION = 1;
our($opt_a, $opt_h, $opt_i, $opt_s);
sub VERSION_MESSAGE {
        warn 'Compare directories with DNS zone files & send updates

        @(#) RdnsUp.pl V2.4 (C) 2010-2019 by Roman Oreshnikov

This is free software, and comes with ABSOLUTELY NO WARRANTY

'
}
sub HELP_MESSAGE {
        warn 'Usage: RdnsUp.pl [options] cur_dir new_dir
Options:
  -a AD  Ignore NS for MS AD zones
  -h     Print this text
  -i     Ignore records with char "_"
  -s     Send updates to NS
Arguments:
  directory with DNS zone files

Report bugs to <r.oreshnikov@gmail.com>
'
}
sub Usage { die "Usage: RdnsUp.pl [-is] [-a ad_zones] cur_dir new_dir\n" }
#
my %N = ();	# New DNS RRs
my %O = ();	# Old DNS RRs
my %U = ();	# Update lines
#
sub Err { die "RdnsUp.pl: @_\n" }
sub Wrn { warn "RdnsUp.pl: @_\n" }
sub Check {
	$_ = shift;
	if($_ eq '@') { $_ = shift }
	elsif(/[^.]$/) { $_ .= '.' . shift }
	tr/A-Z/a-z/;
	$_
}
sub Zone {
	my ($h, $t, $n, @s) = @_;
	open IN, "$t/$n" or Err "$!. Can't open file $t/$n";
	my ($origin, $ttl, $soa) = ($n .= '.', 600, 0);
	while(<IN>) {
		next if /^;/;
		s/\s+;.*$//;
		next if /^\s*$/;
		if(/^\s/) {
			if($soa) {
				push @s, split;
				$s[-1] eq ')' and $soa = 0;
				next
			} else {
				@s = split
			}
		} elsif(/^\$ORIGIN\s+(\S+)/) {
			$origin = $1 eq '.' ? '' : $1;
			next
		} elsif(/^\$TTL\s+(\d+)/) {
			$ttl = $1;
			next
		} else {
			@s = split;
			$n = Check shift @s, $origin
		}
		if($s[0] =~ /^\d+$/) { $t = shift @s }
		else { $t = $ttl }
		shift @s if $s[0] eq 'IN';
		if($s[0] eq 'SOA') { $s[-1] eq ')' or $soa = 1; next }
		defined $opt_i and $n =~ /_/ and next;
		$s[1] = Check $s[1], $origin if $s[0] ne 'A' and $s[0] ne 'MX';
		$s[2] = Check $s[2], $origin if $s[0] eq 'MX';
		$_ = join ' ', $n, @s;
		$h->{$_} = $t
	}
	close IN
}
sub Dir {
	opendir DIR, $_[1] or Err "$!. Can't read directory $_[1]";
	foreach $_ (grep { !/^\./ } readdir DIR) { Zone @_, $_ }
	close DIR
}
#
# Main
#
getopts 'a:his' or Usage;
$#ARGV == 1 or Usage;
Wrn "Check DNS zones";
# Read DNS RRs
Dir \%O, $ARGV[0];
%O or Err "Missing current DNS RRs";
Dir \%N, $ARGV[1];
%N or Err "Missing new DNS RRs";
if(defined $opt_a) {
	my $h;
	foreach $_ (keys %O) {
		foreach $h (split /\s+/, $opt_a) {
			/^$h\. A/ and do { delete $O{$_}; last }
		}
	}
}
# Compare DNS RRs
foreach $_ (keys %N) { delete $O{$_} && delete $N{$_} if defined $O{$_} }
# Create updates
foreach $_ (keys %O) { $_ = join ' ', 'delete', $O{$_}, $_; $U{$_} = 0 }
foreach $_ (keys %N) { $_ = join ' ', 'add', $N{$_}, $_; $U{$_} = 0 }
if(%U) {
	if(defined $opt_s) {
		Wrn "Send NS updates";
		open OUT, "| /usr/bin/nsupdate" or die "$!. Can't open pipe\n";
		select((select(OUT), $| = 1)[0]); # Autoflush
	}
	foreach $_ (reverse sort keys %U) {
		s/^(\S+\s+)(\d+)\s+(\S+\s+)/$1$3$2 IN /;
		warn "update $_\n";
		print OUT "update $_\nsend\n" if defined $opt_s
	}
	if(defined $opt_s) { close OUT or Err "Can't make NS updates" }
}
Wrn "Done"
