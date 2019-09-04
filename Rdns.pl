#! /usr/bin/perl
use integer;
use strict;
use warnings;
use Getopt::Std;
$Getopt::Std::STANDARD_HELP_VERSION = 1;
our($opt_c, $opt_d, $opt_h, $opt_l, $opt_s, $opt_t);
use POSIX qw(strftime);
sub VERSION_MESSAGE {
	warn 'Name server zones admin tool

	@(#) Rdns.pl V2.4 (C) 2010-2019 by Roman Oreshnikov

This is free software, and comes with ABSOLUTELY NO WARRANTY

'
}
sub HELP_MESSAGE {
	warn 'Usage: Rdns.pl [options] arguments
Options:
  -c CMD  Create file CMD for get primary zones by dig(1)
  -d DIR  Create primary zones files in directory DIR
  -h      Print this text
  -l LST  Create file LST with primary zones list
  -s SQL  Create SQLite command file SQL
  -t TAB  Create HTML connection table TAB
Arguments:
  file[s] with definition data

Report bugs to <r.oreshnikov@gmail.com>
'
}
sub Usage {
die "Usage: Rdns.pl [-c cmd] [-d dir] [-l lst] [-s sql] [-t tab] cfg [...]\n"
}
#
# Constants
#
my $MaxE = 20;	# Limit for errors
my %KeyS = (	# Keywords subroutines
	'$ORIGIN'	=>	\&doOrigin,
	'$TTL'		=>	\&doTtl,
	'.NS'		=>	\&doNS,
	'.Admin'	=>	\&doAdmin,
	'.Timers'	=>	\&doTimers,
	'.Zone'		=>	\&doZone,
	'.Null'		=>	\&doZone,
	'.Skip'		=>	\&doZone,
	'.Auto'		=>	\&doAuto,
	'.Join'		=>	\&doJoin
);
my %KeyI = (	# RR types keywords
	'A'	=>	\&chkA,
	'CNAME'	=>	\&chkCNAME,
	'MX'	=>	\&chkMX,
	'NS'	=>	\&chkNS,
	'PTR'	=>	\&chkPTR,
	'SOA'	=>	\&chkSOA,
	'SRV'	=>	\&chkSRV,
	'TXT'	=>	\&chkTXT
);
#
# Variables
#
my $err = $MaxE;			# Errors counter
my $org	= '.';				# Current ORIGIN
my $ttl	= 10800;			# Current TTL
my $adm	= 'root.localhost.';		# SOA Contact
my @soa = (86400, 43200, 604800, 10800);	# SOA Timers
my @nsl = ('localhost.');		# Current NS list
my $opt;				# Current description
#
# Data
#
my %Zone	= ();	# Mask => Zone => Options
my %Skip	= ();	# Domain => 'y'
my %Null	= ();	# Domain => 'y'
my %SOA		= ();	# Domain => SOA => TTL
my %RR		= ();	# Domain => Type => Data => TTL
my %DB		= ();	# Domain => Host => Type => Data => TTL
my %Host	= ();	# Host => Port	=> (Line, IP, Mac, Opt, Tm, Id)
my %Line	= ();	# Line => (Host1/Port1, Host2/Port2)
#
# Subroutines
#
sub Wrn { warn "Rdns.pl: @_\n" }
sub Err { die "Rdns.pl: @_. Terminated\n" }
sub ip2int { unpack("I", pack("C4", reverse split(/\./, $_[0]))) }
sub int2ip { join '.', reverse unpack("C4", pack("I", $_[0])) }
sub ip2arpa {
	my @s = ('in-addr.arpa.', split /\./, $_[0]);
	join '.', reverse @s[0 .. ($_[1] + 7 >> 3)]
}
sub arpa2ip {
	$_[0] =~ /^(.*)\.?in-addr\.arpa\.?$/;
	$1 eq '' and return('0.0.0.0', 0);
	my @s = (reverse(split /\./, $1), 0, 0, 0);
	return(join('.', @s[0 .. 3]), $#s - 2 << 3)
}
sub isMac { return $_[0] =~ /^[\da-f]{4}\.[\da-f]{4}\.[\da-f]{4}$/i }
sub isArpa { return $_[0] =~ /^(.*\.)?in-addr\.arpa\.?$/ }
sub isIP { return $_[0] =~ /^(0|([1-9]\d?)|(1\d{2})|(2[0-4]\d)|(25[0-5]))(\.(0|([1-9]\d?)|(1\d{2})|(2[0-4]\d)|(25[0-5]))){3}$/ }
sub isDomain { return($_[0] =~ /^(\w(-?\w)*\.?)+$/ and not isIP($_[0])) }
sub isSubDomain { return($_[1] eq '.' or $_[0] =~ /\Q.$_[1]\E$/) }
sub addOrigin {
	my $h = $_[0] =~ /\.$/ ? $_[0] : $_[0] . ($org eq '.' ? '.' : ".$org");
	$h =~ tr/[A-Z]/[a-z]/;
	return $h
}
sub by_domain {
	my($x, $y, @A, @B);
	@A = split /\./, $a;
	@B = split /\./, $b;
	return $x if $x = (@A <=> @B);
	for(;@A;) {
		$x = pop @A;
		$y = pop @B;
		if($x =~ /\D/ or $y =~ /\D/) { return $x if $x = ($x cmp $y) }
		else { return $x if $x = ($x <=> $y) }
	}
	return 0
}
#
# Error subroutines
#
sub e_RR { return "Illegal RR format" }
sub e_DN { return "$_[0] - is not domain name" }
sub e_RG { return "$_[0] - already registered" }
sub e_AG { return "$_[0] - wrong number of arguments" }
sub e_VF { return "$_[0] - illegal value for $_[1]" }
#
# Utils subroutines
#
sub chkTtl {
	return "$_[0] - value too small" if $_[0] < 60*5;
	return "$_[0] - value too big" if $_[0] > 60*60*24*366;
	return 0
}
sub setDomain {
	$#_ == 2 or return e_AG $_[1];
	isDomain $_[2] or return e_DN $_[2];
	$_ = addOrigin $_[2];
	return e_VF $_, $_[1] if isArpa $_;
	${$_[0]} = $_;
	return 0
}
sub setTime {
	return e_VF $_[2], $_[1] if $_[2] =~ /(\D)|(^0)/;
	return "$_ for $_[1]" if $_ = chkTtl($_[2]);
	${$_[0]} = $_[2];
	return 0
}
sub regA {
	defined $RR{$_[0]}{'A'}{$_} or $RR{$_[0]}{'A'}{$_} = $ttl;
	s/(\d+).(\d+).(\d+).(\d+)/$4.$3.$2.$1.in-addr.arpa./;
	defined $RR{$_}{'PTR'} or $RR{$_}{'PTR'}{$_[0]} = $ttl
}
sub regLine {
	if($_[0] eq '?') { return '' }
	elsif(not defined $Line{$_[0]}) { $Line{$_[0]} = [($_[1])] }
	elsif(defined $Line{$_[0]}[1]) { return "$_[0] - multiple use" }
	else { $Line{$_[0]}[1] = $_[1] }
	return '' 
}
#
# Keyword subroutines
#
sub doAdmin { setDomain \$adm, @_ }
sub doOrigin {
	$#_ == 1 or return e_AG $_[0];
	if(isDomain $_[1]) {
		$_[1] =~ /\.$/ or return "Argument for $_[0] must end with dot"
	} elsif($_[1] ne '.') {
		return e_DN $_[1]
	}
	$org = $_[1];
	return 0
}
sub doTtl {
	$#_ == 1 or return e_AG $_[0];
	setTime \$ttl, @_
}
sub doTimers {
	$#_ == 4 or return e_AG $_[0];
	return $_ if $_ = setTime \$soa[0], 'SOA refresh', $_[1];
	return $_ if $_ = setTime \$soa[1], 'SOA retry', $_[2];
	return $_ if $_ = setTime \$soa[2], 'SOA expire', $_[3];
	setTime \$soa[3], 'SOA negttl', $_[4]
}
sub doNS {
	$#_ < 1 and return e_AG $_[0];
	my ($h, @n);
	foreach $_ (@_[1 .. $#_]) {
		return $_ if $_ = setDomain \$h, $_[0], $_;
		push @n, $h
	}
	@nsl = (@n);
	return 0
}
sub doZone {
	return e_AG $_[0] if $#_ < 1 or ($_[0] ne '.Zone' and $#_ > 1);
	$_[1] =~ /^([^\/]+)(.*)$/;
	my($n, $m, @s) = ($1, $2);
	if($m or isIP $n) {
		@s = (split(/\./, $n), 0, 0, 0);
		$n = join '.', @s[0..3];
		$#s < 7 and isIP $n or return "$_[1] - illegal IP zone";
		$m or $m = '/32';
		$m =~ s/^\/((0)|([1-9]\d?))$/$1/ or
			return "$m - invalid bitmask";
		$m < 33 or return "Bitmask must be in range from 0 to 32";
		my $i = ip2int $n;
		return "$m - bitmask too big for network $n" if
			$i & ~(-1 << 32 - $m)
	} elsif(isDomain $n or $n eq '.') {
		$m = -1;
		$n = addOrigin $n;
		($n, $m) = arpa2ip $n if isArpa $n
	} else {
		return "$_[1] - bad argument for $_[0]"
	}
	if($_[0] eq '.Zone') { @s = ($ttl, @soa, $adm, @nsl) }
	else { @s = ($ttl, 0) }
	foreach $_ (@_[2 .. $#_]) {
		isDomain $_ or return e_VF $_, "zone NameServer";
		$_ = addOrigin $_;
		return "$_ - illegal zone NameServer" if isArpa $_;
		push @s, $_
	}
	return ($m < 0 ? $n : "$n/$m") . " - zone already registered" if
		defined $Zone{$m}{$n};
	$Zone{$m}{$n} = [@s];
	return 0
}
sub doAuto {
	$#_ > 2 or return e_AG $_[0];
	my ($h, $d, $i, $b, $e, $f) = @_;
	isDomain $d or return e_DN $d;
	return "$d - illegal domain for $_[0]" if isArpa $d = addOrigin $d;
	$d =~ /^([^\.]+)\.(.*)$/;
	($e, $f, $d) = (2, $1, $2);
	if($i =~ /^(-?)(\d+)$/) {
		$f .= $1 . '%0' . length($i = $2) . 'd';
		$e++
	}
	isIP $_[$e] and isIP $_[++$e] or return "$_[$e] - illegal IP address";
	($b, $e) = (ip2int($_[$e-1]), ip2int($_[$e]));
	$b <= $e or return "The initial IP address is greater than the final";
	do {
		$h = sprintf "$f.$d", $i++;
		return e_RG $h if defined $Host{$h};
		$_ = int2ip $b;
		regA $h
	} while(++$b <= $e)
}
sub doJoin {
	$#_ == 2 or return e_AG $_[0];
	return $_ if $_ = regLine $_[1], " $_[2]";
	return $_ if $_ = regLine $_[2], " $_[1]"
}
sub doDefault {
	my($m, $n, $x, $h, $p, $l, $t, %i, %a);
	$_ = shift;
	if($_ eq '@') {
		($h, $p) = ($org, '')
	} else {
		/^([^\/]+)(.*)$/;
		($h, $p) = ($1, $2);
		isDomain $h or return e_DN $h;
		$h = addOrigin $h
	}
	$_ = shift;
	if(defined $_ and not $p and /^[1-9]\d*$/) {
		return $t if $t = chkTtl $_;
		$t = $_;
		$p = undef;
		$_ = shift
	}
	if(defined $_ and not $p and $_ eq 'IN') {
		$p = undef;
		$_ = shift
	}
	if(defined $_ and not $p) {
		my $r = $KeyI{$_};
		return &$r($h, defined $t ? $t : $ttl, @_) if defined $r;
		return e_RR if not defined $p
	}
	if(defined $p) {
		return e_RG "$h$p" if defined $Host{$h}{$p};
		while(defined $_) {
			if(isIP $_) {
				return "$_ - reuse of IP" if defined $i{$_};
				$i{$_} = 1;
				regA $h
			} elsif(isMac $_) {
				return "$_ - extra MAC-address" if defined $m;
				tr/[A-Z]/[a-z]/;
				$m = $_
			} elsif(not defined $l) {
				return $l if $l = regLine $_, "$h$p";
				$l = $_ eq '?' ? '' : $_
			} else {
				return "$_ - reuse of option" if defined $a{$_};
				$a{$_} = 1
			}
			$_ = shift
		}
		if($_ = $opt) {
			s/\s+;.*//;
			/^\s+#(\S*)\s*(.*)/;
			($x, $n) = ($1, $2)
		}
		defined $l or $l = '';
		defined $m or $m = '';
		defined $x or $x = '';
		defined $n or $n = '';
		$Host{$h}{$p} = [($l, join(' ', sort by_domain keys %i), $m,
			join(' ', sort keys %a), $x, $n)]
	}
	return 0
}
#
# Check RR types subroutines
#
sub chkA {
	$#_ == 2 or return e_RR;
	isIP $_[2] or return "$_[2] - illegal IP address";
	$_ = $RR{$_[0]}{'A'}{$_[2]};
	return e_RG "$_[0] $_ IN A $_[2]" if defined $_;
	$RR{$_[0]}{'A'}{$_[2]} = $_[1];
	return 0
}
sub chkCNAME {
	$#_ == 2 or return e_RR;
	isDomain $_[2] or return e_DN $_[2];
	$_ = $RR{$_[0]}{'CNAME'};
	my($d, $t);
	return e_RG "$_[0] $t IN CNAME $d" if defined $_ and
		($d, $t) = each %$_;
	$d = addOrigin $_[2];
	$_ = isArpa($_[0]) ? -1 : 0;
	isArpa $_[0] and ++$_;
	return "$d - illegal CNAME for $_[0]" if $_;
	$RR{$_[0]}{'CNAME'}{$d} = $_[1];
	return 0
}
sub chkNS {
	$#_ == 2 or return e_RR;
	isDomain $_[2] or return e_DN $_[2];
	my $d = addOrigin $_[2];
	return "$d - illegal domain for NS" if isArpa $d;
	$_ = $RR{$_[0]}{'NS'}{$d};
	return e_RG "$_[0] $_ IN NS $d" if defined $_;
	$RR{$_[0]}{'NS'}{$d} = $_[1];
	return 0
}
sub chkPTR {
	$#_ == 2 or return e_RR;
	isDomain $_[2] or return e_DN $_[2];
	my $d = addOrigin $_[2];
	isArpa $d or return "$d - illegal domain for PTR";
	$_ = $RR{$_[0]}{'PTR'}{$d};
	return e_RG "$_[0] $_ IN PTR $d" if defined $_;
	$RR{$_[0]}{'PTR'}{$d} = $_[1];
	return 0
}
sub chkMX {
	$#_ == 3 or return e_RR;
	return "$2 - illegal priority for MX RR" if $_[2] =~ /(\D)|(^0\d+)/;
	isDomain $_[3] or return e_DN $_[3];
	my $d = addOrigin $_[3];
	return "Illegal use MX RR for $_[0]" if isArpa $d;
	$_ = $RR{$_[0]}{'MX'};
	if(defined $_) {
		my($k, $t, $p, $m);
		while(($k, $t) = each(%$_)) {
			($p, $m) = split / /, $k;
			return e_RG "$_[0] $t IN MX $k" if $m eq $d
		}
	}
	$RR{$_[0]}{'MX'}{"$_[2] $d"} = $_[1];
	return 0
}
sub chkSOA { return 0 }
sub chkSRV { return 0 }
sub chkTXT { return 0 }
#
# Check data subroutines
#
sub addZone {
	my($z, $p) = @_;
	if($p->[1]) { defined $SOA{$z} or $SOA{$z} = [(@$p[0 .. 6])] }
	else { $Skip{$z} = 'y'; return }
	$_ = @$p - 1;
	foreach $_ (@$p[6 .. $_]) {
		defined $RR{$z}{'NS'}{$_} or $RR{$z}{'NS'}{$_} = $p->[0]
	}
}
sub chkZones {
	my($m, $d, $z, $i, $v);
	foreach $m (sort { $a <=> $b } keys %Zone) {
		if($m < 0) {
			while(($d, $v) = each(%{$Zone{$m}})) { addZone $d, $v }
			next
		}
		$z = ~(-1 << 8 - ($m & 7));
		while(($d, $v) = each(%{$Zone{$m}})) {
			$_ = ip2arpa $d, $m;
			if($z == 255) { addZone $_, $v; next }
			/^(\d+)(.*)$/;
			($i, $d) = ($1, $2);
			do { addZone "$i$d", $v } while(++$i & $z)
		}
	}
	%Zone = ()
}
sub NStoDB {
	my($d, $n, $p, $h) = @_;
	defined ($p = $RR{$n}{'A'}) or return 1;
	$_ = $n;
	if(isSubDomain $_, $d) {
		s/\Q.$d\E$// or s/\.$//;
		foreach $h (keys %$p) { $DB{$d}{$_}{'A'}{$h} = $p->{$h} }
	}
	$_ = $d;
	while(s/^[^\.]*\.(.*)$/$1/) {
		last if defined $SOA{$_} or defined $Skip{$_} or $_ eq ''
	}
	$d =~ /^(.+)\Q.$_\E$/;
	$_ = '.' if $_ eq '';
	defined $SOA{$_} or return 0;
	$DB{$_}{$1?$1:''}{'NS'}{$n} = $RR{$d}{'NS'}{$n};
	$d = $_;
	$_ = $n;
	if(isSubDomain $_, $d) {
		s/\Q.$d\E$// or s/\.$//;
		foreach $h (keys %$p) { $DB{$d}{$_}{'A'}{$h} = $p->{$h} }
	}
	return 0
}
sub chkRR {
	my ($d, $h, $c, $r, $p, %B) = @_;
	$c = 0;
	foreach $r (keys %{$RR{$d}}) {
		foreach $_ (keys %{$RR{$d}{$r}}) {
			if(++$c == 0) {
				Wrn "$d - domain already defined as CNAME";
				--$err; return
			}
			if($r eq 'NS') {
				if(NStoDB($d, $_) and not defined $B{$_}) {
					Wrn "$_ - no IP address for NameServer";
					--$err or return;
					$B{$_} = 1
				}
			} elsif($r eq 'CNAME') {
				if($c > 1) {
					Wrn "$d - is define as CNAME, but",
						"it have records other type";
					--$err; return
				}
				$c = -1;
				if(defined ($p = $RR{$_})) {
					if(defined $p->{'CNAME'}) {
						Wrn "$d - is CNAME to",
							"CNAME $_";
						--$err; return
					}
					$h = isArpa($d) ? 0 : -1;
					$h++ if defined $p->{'A'};
					$h or next;
					Wrn "$d - is CNAME to $_",
						"without A RR";
					--$err; return
				} else {
					Wrn "$d - is CNAME to unregistered RR"
				}
			} elsif($r eq 'MX') {
				next
			}
		}
	}
}
sub RRtoDB {
	my($d, $h);
	foreach $d (keys %RR) {
		$_ = $d; $h = '';
		while(not defined $SOA{$_} and not defined $Skip{$_} and $_ ne '') {
			 s/^[^\.]*\.(.*)$/$1/
		}
		if($d =~ /^(.+)\Q.$_\E$/) { $_ = '.' if $_ eq ''; $h = $1 }
		$DB{$_}{$h} = $RR{$d} if defined $SOA{$_};
		chkRR $d
	}
}
#
# Result subroutines
#
sub NewFile {
	open OUT, ">$_[0]" or Err "$_[0] - can't create file";
	Wrn $_[1] if defined $_[1]
}
sub resultZ {
	Wrn "Creating zone files in $opt_d";
	my($s, $z, $n, $h, $r, $t, $o);
	$s = strftime("%Y%m%d00", gmtime);
	foreach $z (keys %SOA) {
		$z =~ /(.*)\.$/;
		$_ = "$opt_d/" . ($1 ne '' ? $1 : 'Root');
		NewFile $_;
		$_ = $SOA{$z};
		$ttl = $_->[0];
		if(($o = $z) eq '.') {
			$n = '.';
			$_->[5] =~ s/\.$//;
			$_->[6] =~ s/\.$//
		} else {
			$n = '@';
			$_->[5] =~ s/\Q.$o\E$//;
			if($_->[6] eq $o) { $_->[6] = '@' } 
			else { $_->[6] =~ s/\Q.$o\E$// }
		}
		print OUT "\$TTL\t$ttl\n$n\tIN\tSOA\t",
			join(' ', $_->[6], $_->[5]),
			join "\n\t\t\t", ' (', $s, @$_[1..4], ")\n";
		foreach $h (sort by_domain keys %{$DB{$z}}) {
			($n, $_) = $h =~ /^([^\.]+)\.(.+)$/ ?
			($1, $2 . ($z eq '.' ? '.' : ".$z")) : ($h, $z);
			$n .= "\t" if length $n < 8;
			print OUT "\$ORIGIN\t$o\n" if $o ne $_ and $o = $_;
			foreach $r (sort keys %{$DB{$z}{$h}}) {
				foreach $_ (sort keys %{$DB{$z}{$h}{$r}}) {
					$t = $DB{$z}{$h}{$r}{$_};
					print OUT "\$TTL\t$ttl\n" if
						$t != $ttl and $ttl = $t;
					if($r ne 'TXT') {
						if($_ eq $o) {
							$_ = '@'
						} elsif($o ne '.') {
							s/\Q.$o\E$//
						} else {
							s/\.$//
						}
					}
					print OUT "$n\t$r\t$_\n";
					$n = "\t"
				}
			}
		}
		close OUT
	}
}
sub resultL {
	NewFile $opt_l, "Create primary zones list $opt_l";
	my $z;
	foreach $_ (sort by_domain keys %SOA) {
		s/\.$//;
		if($_ eq '') { $_ = '.'; $z = 'Root' }
		else { $z = $_ }
		print OUT "zone \"$_\" { type master; file \"$z\"; };\n"
	}
	close OUT
}
sub resultC {
	NewFile $opt_c, "Create zones request script $opt_c";
	my ($n, $z);
	foreach $_ (sort by_domain keys %SOA) {
		$n = $SOA{$_}[6];
		$n =~ /\.$/ or $n =~ s/$/.$_/;
		$n =~ s/\.$//;
		s/\.$//;
		if($_ eq '') { $_ = '.'; $z = 'Root' }
		else { $z = $_ }
		print OUT "dig axfr \@$n $_ >$z\n"
	}
	close OUT
}
sub Row { # Row \&print_row(@fields)
	my ($f, $h, $p, $d, $l) = @_;
	foreach $h (sort by_domain keys %Host) {
		$d = $h;
		$d =~ s/\.$//;
		foreach $p (sort keys %{$Host{$h}}) {
			my %c = ("$h$p" => 1);
			$l = $Host{$h}{$p}[0];
			$_ = $l eq '' ? '' : " $l";
			while(/^ /) {
				$c{$_} = 1;
				s/^ //;
				not defined $c{$_ = $Line{$l = $_}[0]} or
					defined($_ = $Line{$l}[1]) or $_ = ''
			}
			if(/\//) { s/\.(\/.*)$/$1/ }
			else { s/\.$// }
			&$f("$d$p", $_, @{$Host{$h}{$p}})
		}
	}
}
sub HtmlRow { print OUT join('<TD>','<TR>', @_), "\n" }
sub SqlRow {
	my @r = @_;
	map { if($_ eq '') { $_ = 'NULL' } else { s/'/''/g; $_ = "'$_'" } } @r;
	print OUT "INSERT INTO db VALUES(", join(',', @r), ");\n"
}
sub resultT {
	NewFile $opt_t, "Create connection table $opt_t";
	print OUT "<!DOCTYPE html>\n<HTML LANG=\"ru\">\n<HEAD>\n",
		'<META HTTP-EQUIV="Content-Language" CONTENT="ru" />', "\n",
		'<META HTTP-EQUIV="Content-Type" ',
			'CONTENT="text/html; charset=utf-8" />', "\n",
		"<TITLE>Connection table</TITLE>\n</HEAD>\n<BODY>\n",
		"<TABLE BORDER=1 CELLSPACING=0 CELLPADING=0>\n",
		'<TR><TH>Source<TH>Destination<TH>Line<TH>IP Address',
		"<TH>MAC Address<TH>Options<TH>Timestamp<TH>Description\n";
	Row(\&HtmlRow);
	print OUT "</TABLE>\n</BODY>\n</HTML>\n";
	close OUT
}
sub resultS {
	NewFile $opt_s, "Create SQLite3 command file $opt_s";
	print OUT "BEGIN TRANSACTION;\n",
		"CREATE TABLE db (src,dst,line,ip,mac,opt,ts,sys);\n";
	Row(\&SqlRow);
	print OUT "END TRANSACTION;\n";
	close OUT
}
#
# Main
#
getopts 'c:d:hl:s:t:' or Usage;
if(defined $opt_h) { HELP_MESSAGE; exit }
$#ARGV >= 0 or Usage;
Wrn "Reading data";
foreach $_ (@ARGV) {
	open IN, $_ or Err "$_ - $!";
	my ($f, $p, @s) = $_;
	while(<IN>) {
		s/(\s+[;#].*)$//;
		$opt = $1;
		@s = split and $s[0] !~ /^[#;]/ or next;
		$p = $KeyS{$s[0]};
		$_ = defined $p ? &$p(@s) : doDefault(@s);
		$_ or next;
		warn "$f\[$.\]: $_\n";
		--$err or last
	}
	close IN;
	$err or last
}
if($err == $MaxE) {
	Wrn "Checking data";
	chkZones;
	RRtoDB
}
$err == $MaxE or Err "Errors in the data";
umask 02;
resultZ if defined $opt_d;
resultL if defined $opt_l;
resultC if defined $opt_c;
resultS if defined $opt_s;
resultT if defined $opt_t;
Wrn "Done"
