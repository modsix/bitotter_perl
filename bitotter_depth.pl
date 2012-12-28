#!/usr/bin/perl

#
# Copyright (c) 2012
# BITOTTER (http://www.bitotter.com) All rights reserved.
#
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#       This product includes software developed by BITOTTER,
#       http://www.bitotter.com
# 4. Neither the name "BITOTTER" nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY BITOTTER ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL BITOTTER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

# BitOTTer Market Depth Tool for MPEx (bitotter_depth.pl)
# Copyright (c) 2012 bitotter.com <modsix@gmail.com> 0xD655A630A13E8C69 

use LWP::UserAgent; 
use LWP::Simple qw(get);
use JSON;

my $url = "http://mpex.co/mpex-mktdepth.php";
my $json = new JSON;
my $json_text;
my $mpsic;


if(!$ARGV[0]) { 
	print "Usage: ./bitotter_depth.pl [MPSIC|ALL] [usetor]\n";
	exit(1);
} elsif($ARGV[1] eq "usetor") {
	print "TOR ENABLED - Connecting to MPEx via Tor Socket...\n";
	my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NET CLR 1.1.4322)},);
	$ua->proxy([qw/ http https /] => 'socks://localhost:9050'); # Tor proxy - 9050 default
	$ua->cookie_jar({});
	my $rsp = $ua->get($url);
	$json_text = $rsp->content;
	$mpsic = $json->allow_unknown->relaxed->decode($json_text);
} else { 
	print "Tor disabled - naked connection to MPEx in progress ...\n";
	$json_text = get($url);
	$mpsic = $json->allow_unknown->relaxed->decode($json_text);
} 
print "..::[ BitOTTer Market Depth for MPEx: $ARGV[0] ]::..\n";
while (my ($code,$trade) = each %$mpsic) {
	if($ARGV[0] eq "ALL") { 
		print "MPSIC => $code:\n";
		while (my ($action,$act_ref) = each %$trade) {
			my @sorted = sort { $b->[0] <=> $a->[0] } @$act_ref;
			foreach (@sorted) {
				print "$action => Price: @$_[0]\tVolume: @$_[1]\n";
			}
		}
	} else {
		if($code eq $ARGV[0]) {
			while (my ($action,$act_ref) = each %$trade) {
				my @sorted = sort { $b->[0] <=> $a->[0] } @$act_ref;
				foreach (@sorted) {
					print "$action => Price: @$_[0]\tVolume: @$_[1]\n";	
				} 
			}
		}
	}
}

