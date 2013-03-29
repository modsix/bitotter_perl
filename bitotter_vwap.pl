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

# BitOTTer Market VWAP Tool for MPEx (bitotter_vwap.pl) v0.03 beta
# Copyright (c) 2012, 2013 bitotter.com <modsix@gmail.com> 0xD655A630A13E8C69 

### New, revised version of the original bitotter_vwap.pl: 
### This version takes a pastebin URL of the market vwap JSON data as a parameter.  
### An IRC private message request to mpexbot with `$vwap' on freenode will return the requesting user a pastebin raw URL.  
### The JSON data can be retrieved from pastebin either via naked connection or Tor (if setup).  
### 
### Ex:
### With Pastebin via mpexbot on irc.freenode.net:
### 	mod6@localhost ~$ ./bitotter_vwap.pl MPSIC http://pastebin.com/SoMeKeYId 
### 	mod6@localhost ~$ ./bitotter_vwap.pl MPSIC http://pastebin.com/SoMeKeYId usetor
### 	mod6@localhost ~$ ./bitotter_vwap.pl MPSIC http://pastebin.com/SoMeKeYId no-tor
### Without Pastebin, request VWAP feed from mpex.co directly:
### 	mod6@localhost ~$ ./bitotter_vwap.pl MPSIC usetor
### 	mod6@localhost ~$ ./bitotter_vwap.pl MPSIC no-tor

### See perl_tools README

use JSON;
use LWP::UserAgent; 
use LWP::Simple qw(get);

my $TMP_DIR = "/tmp";
my $mpex_vwap_feed = "http://mpex.co/mpex-vwap.php";
my $pastebin_raw_url = "";
my $use_pastebin = "FALSE";

if($ARGV[0] =~ m/^help$|^h(\w+)$/i) { 
	usage();
} elsif(($ARGV[1] =~ m/http\:\/\/pastebin\.com\/raw\.php\?i\=(.*)/) or ($ARGV[1] =~ m/http\:\/\/pastebin\.com\/(.*)/) and $ARGV[1] ne "") {
	$pastebin_key = $+;	
	$pastebin_raw_url = "http://pastebin.com/raw.php?i=" . $pastebin_key;
	$use_pastebin = "TRUE";
	getVWAP();
	displayVWAP();
} else { 
	getVWAP();
	displayVWAP();
}

sub usage {
	print "Usage: ./bitotter_vwap.pl <MPSIC> [pastebin-raw-url] [usetor|no-tor]\n";
	exit 1;
}

sub getVWAP {
	my $html = "";

	if(($ARGV[1] =~ m/usetor/i) or ($ARGV[2] =~ m/usetor/i)) {
		print "TOR ENABLED - Connecting to pastebin via Tor Socket...\n";
		my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NET CLR 1.1.4322)});
		$ua->proxy([qw/ http https /] => 'socks://localhost:9150'); # Tor proxy - 9150 default nao !?
		$ua->cookie_jar({});
		my $response;
		if($use_pastebin eq "TRUE") { $response = $ua->get($pastebin_raw_url); } else { $response = $ua->get($mpex_vwap_feed); }
		$html = $response->content;
	} elsif(($ARGV[1] eq "" or $ARGV[1] =~ m/no-tor/i) or ($ARGV[2] eq "" or $ARGV[2] =~ m/no-tor/i)) {
		print "TOR DISABLED! Naked connection to pastebin in progress...\n";
		my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NET CLR 1.1.4322)});
		$ua->timeout(30);
		my $response;
		if($use_pastebin eq "TRUE") { $response = $ua->get($pastebin_raw_url); } else { $response = $ua->get($mpex_vwap_feed); }
		$html = $response->content;
	}	

	open RES, ">$TMP_DIR/pastebin_vwap.txt" or die "$! Couldn't open the $TMP_DIR/pastebin_vwap.txt file for writing! Exiting! Check $TMP_DIR permissions.\n";
	print RES $html;	
	close RES;
}

sub displayVWAP {
	open JSON_VWAP, "<$TMP_DIR/pastebin_vwap.txt" or die "$! Couldn't open the $TMP_DIR/pastebin_vwap.txt file for reading!  Exiting!\n";
	my $json_vwap_data = "";
	while(<JSON_VWAP>) { $json_vwap_data .= $_; }
	close JSON_VWAP;
	
	my $json_vwap_obj = new JSON;
	my $mpsic = $json_vwap_obj->allow_unknown->relaxed->decode($json_vwap_data);

	my @interval = ('1d', '7d', '30d');
	my @stat_type = ('avg', 'min', 'max', 'vsh', 'vsa', 'cnt');

	print "..::[ BitOTTer VWAP Tool for MPEx: $ARGV[0] ]::..\n";
	while (my ($code, $rolling_window) = each %$mpsic) {
		if($code eq $ARGV[0]) {
			print "$code:\n";
			foreach $range (@interval) {
				foreach $type (@stat_type) {
					print "\t$range $type: => $rolling_window->{$range}->{$type}\n";
				}	
				print "\n";
			}
		} 
	}
}
