#!/usr/bin/perl

#
# Copyright (c) 2012, 2013
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

# BitOTTer Market Depth Tool for MPEx (bitotter_depth.pl) v0.02 beta
# Copyright (c) 2012, 2013 bitotter.com <modsix@gmail.com> 0xD655A630A13E8C69 

### New, revised version of the original bitotter_depth.pl: 
### This version takes a pastebin URL of the market depth JSON data as a parameter.  
### An IRC private message request to mpexbot with `$depth' on freenode will return the requesting user a pastebin raw URL.  
### The JSON data can be retrieved from pastebin either via naked connection or Tor (if setup).  
### 
### Ex:
### mod6@localhost ~$ ./bitotter_depth.pl http://pastebin.com/raw.php?i=SoMeKeYId ALL usetor
### or 
### mod6@localhost ~$ ./bitotter_depth.pl http://pastebin.com/raw.php?i=SoMeKeYId S.MPOE no-tor
### or 
### mod6@localhost ~$ ./bitotter_depth.pl http://pastebin.com/SoMeKeYId S.MPOE 

use JSON;
use LWP::UserAgent; 
use LWP::Simple qw(get);

my $TMP_DIR = "/tmp";
my $pastebin_raw_url = "";

if(($ARGV[0] =~ m/http\:\/\/pastebin\.com\/raw\.php\?i\=(.*)/) or ($ARGV[0] =~ m/http\:\/\/pastebin\.com\/(.*)/) and $ARGV[1] ne "") {
	$pastebin_key = $+;	
	$pastebin_raw_url = "http://pastebin.com/raw.php?i=" . $pastebin_key;
	getDepth();
	displayDepth();
} else {
	print "Usage: ./bitotter_depth.pl <pastebin-raw-url> <MPSIC|ALL> [usetor|no-tor]\n";
	exit 1;
}

sub getDepth {
	my $html = "";

	if($ARGV[2] =~ m/usetor/) {
		print "TOR ENABLED - Connecting to pastebin via Tor Socket...\n";
		my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NET CLR 1.1.4322)});
		$ua->proxy([qw/ http https /] => 'socks://localhost:9050'); # Tor proxy - 9150 default nao
		$ua->cookie_jar({});
		my $response = $ua->get($pastebin_raw_url);
		$html = $response->content;
	} elsif($ARGV[2] eq "" or $ARGV[2] eq "no-tor") {
		print "TOR DISABLED! Naked connection to pastebin in progress...\n";
		my $user_agent = LWP::UserAgent->new();
		$user_agent->timeout(30);
		my $request = HTTP::Request->new('GET', $pastebin_raw_url);
		my $response = $user_agent->request($request);
		$html = $response->content;
	}	

	open RES, ">$TMP_DIR/pastebin_depth.txt" or die "$! Couldn't open the $TMP_DIR/pastebin_depth.txt file for writing! Exiting! Check $TMP_DIR permissions.\n";
	print RES $html;	
	close RES;
}

sub displayDepth {
	open JSON_DEPTH, "<$TMP_DIR/pastebin_depth.txt" or die "$! Couldn't open the $TMP_DIR/pastebin_depth.txt file for reading!  Exiting!\n";
	my $json_depth_data = "";
	while(<JSON_DEPTH>) { $json_depth_data .= $_; }
	close JSON_DEPTH;
	
	my $json_depth_obj = new JSON;
	my $mpsic = $json_depth_obj->allow_unknown->relaxed->decode($json_depth_data);

	print "..::[ BitOTTer Market Depth for MPEx: $ARGV[1] ]::..\n";
	while (my ($code,$trade) = each %$mpsic) {
		if($ARGV[1] eq "ALL") { 
			print "MPSIC => $code:\n";
			while (my ($action,$act_ref) = each %$trade) {
				my @sorted = sort { $b->[0] <=> $a->[0] } @$act_ref;
				foreach (@sorted) {
					print "$action => Price: @$_[0]\tVolume: @$_[1]\n";
				}
			}
		} else {
			if($code eq $ARGV[1]) {
				while (my ($action,$act_ref) = each %$trade) {
					my @sorted = sort { $b->[0] <=> $a->[0] } @$act_ref;
					foreach (@sorted) {
						print "$action => Price: @$_[0]\tVolume: @$_[1]\n";	
					} 
				}
			}
		}
	}
}
