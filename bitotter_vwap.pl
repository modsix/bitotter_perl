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

# BitOTTer Market VWAP Tool for MPEx (bitotter_vwap.pl) v0.02 beta
# Copyright (c) 2012, 2013 bitotter.com <modsix@gmail.com> 0xD655A630A13E8C69 

### New, revised version of the original bitotter_vwap.pl: 
### This version takes a pastebin URL of the market vwap JSON data as a parameter.  
### An IRC private message request to mpexbot with `$vwap' on freenode will return the requesting user a pastebin raw URL.  
### The JSON data can be retrieved from pastebin either via naked connection or Tor (if setup).  
### 
### Ex:
### mod6@localhost ~$ ./bitotter_vwap.pl http://pastebin.com/raw.php?i=SoMeKeYId MPSIC usetor
### or 
### mod6@localhost ~$ ./bitotter_vwap.pl http://pastebin.com/raw.php?i=SoMeKeYId S.MPOE no-tor
### or 
### mod6@localhost ~$ ./bitotter_vwap.pl http://pastebin.com/SoMeKeYId S.MPOE 

use JSON;
use LWP::UserAgent; 
use LWP::Simple qw(get);

my $TMP_DIR = "/tmp";
my $pastebin_raw_url = "";

if(($ARGV[0] =~ m/http\:\/\/pastebin\.com\/raw\.php\?i\=(.*)/) or ($ARGV[0] =~ m/http\:\/\/pastebin\.com\/(.*)/) and $ARGV[1] ne "") {
	$pastebin_key = $+;	
	$pastebin_raw_url = "http://pastebin.com/raw.php?i=" . $pastebin_key;
	getVWAP();
	displayVWAP();
} else {
	print "Usage: ./bitotter_vwap.pl <pastebin-raw-url> <MPSIC> [usetor|no-tor]\n";
	exit 1;
}

sub getVWAP {
	my $html = "";

	if($ARGV[2] =~ m/usetor/) {
		print "TOR ENABLED - Connecting to pastebin via Tor Socket...\n";
		my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NET CLR 1.1.4322)});
		$ua->proxy([qw/ http https /] => 'socks://localhost:9150'); # Tor proxy - 9150 default nao !?
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

	print "..::[ BitOTTer VWAP Tool for MPEx: $ARGV[1] ]::..\n";
	while (my ($code, $rolling_window) = each %$mpsic) {
		if($code eq $ARGV[1]) {
			print "$code:\n";
			print "\t1d avg: => $rolling_window->{'1d'}->{'avg'}\n";
			print "\t1d min: => $rolling_window->{'1d'}->{'min'}\n";
			print "\t1d max: => $rolling_window->{'1d'}->{'max'}\n";
			print "\t1d vsh: => $rolling_window->{'1d'}->{'vsh'}\n";
			print "\t1d vsa: => $rolling_window->{'1d'}->{'vsa'}\n";
			print "\t1d cnt: => $rolling_window->{'1d'}->{'cnt'}\n";
			print "\n";
			print "\t7d avg: => $rolling_window->{'7d'}->{'avg'}\n";
			print "\t7d min: => $rolling_window->{'7d'}->{'min'}\n";
			print "\t7d max: => $rolling_window->{'7d'}->{'max'}\n";
			print "\t7d vsh: => $rolling_window->{'7d'}->{'vsh'}\n";
			print "\t7d vsa: => $rolling_window->{'7d'}->{'vsa'}\n";
			print "\t7d cnt: => $rolling_window->{'7d'}->{'cnt'}\n";
			print "\n";
			print "\t30d avg: => $rolling_window->{'30d'}->{'avg'}\n";
			print "\t30d min: => $rolling_window->{'30d'}->{'min'}\n";
			print "\t30d max: => $rolling_window->{'30d'}->{'max'}\n";
			print "\t30d vsh: => $rolling_window->{'30d'}->{'vsh'}\n";
			print "\t30d vsa: => $rolling_window->{'30d'}->{'vsa'}\n";
			print "\t30d cnt: => $rolling_window->{'30d'}->{'cnt'}\n";
		} 
	}
}
