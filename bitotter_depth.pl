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

# BitOTTer Market Depth Tool for MPEx (bitotter_depth.pl) v0.0.3 beta
# Copyright (c) 2012, 2013, 2014 bitotter.com <modsix@gmail.com> 0x721705A8B71EADAF

### New, revised version of the original bitotter_depth.pl: 
### This version takes a pastebin URL of the market depth JSON data as a parameter.  
### An IRC private message request to mpexbot with `$depth' on freenode will return the requesting user a pastebin raw URL.  
### The JSON data can be retrieved from pastebin either via naked connection or Tor (if setup).  
### 
### With Pastebin via mpexbot on irc.freenode.net:
### 	mod6@localhost ~$ ./bitotter_depth.pl MPSIC http://pastebin.com/SoMeKeYId 
### 	mod6@localhost ~$ ./bitotter_depth.pl MPSIC http://pastebin.com/SoMeKeYId usetor
### 	mod6@localhost ~$ ./bitotter_depth.pl MPSIC http://pastebin.com/SoMeKeYId no-tor
### Without Pastebin, request depth feed from mpex.co directly:
### 	mod6@localhost ~$ ./bitotter_depth.pl MPSIC usetor
### 	mod6@localhost ~$ ./bitotter_depth.pl MPSIC no-tor

use JSON;
use LWP::UserAgent; 
use LWP::Simple qw(get);

my $TMP_DIR = "/tmp";
my $mpex_depth_feed = "http://mpex.co/mpex-mktdepth.php";
my $pastebin_raw_url = "";
my $use_pastebin = "FALSE";

if(($ARGV[0] =~ m/^help$|^h(\w+)$/i) or ($ARGV[0] eq "") or ($ARGV[0] =~ m/pastebin/)) { 
	usage();
} elsif(($ARGV[1] =~ m/http\:\/\/pastebin\.com\/raw\.php\?i\=(.*)/) or ($ARGV[1] =~ m/http\:\/\/pastebin\.com\/(.*)/) and ($ARGV[1] ne "")) {
	$pastebin_key = $+;	
	$pastebin_raw_url = "http://pastebin.com/raw.php?i=" . $pastebin_key;
	$use_pastebin = "TRUE";
	getDepth();
	displayDepth();
} else {
	getDepth();
	displayDepth();
}

sub usage {
	print "Usage: ./bitotter_depth.pl <MPSIC|ALL> [pastebin-raw-url] [usetor|no-tor]\n";
	exit 1;
}

sub getDepth {
	my $html = "";

	if(($ARGV[1] =~ m/usetor/i) or ($ARGV[2] =~ m/usetor/i)) {
		print "TOR ENABLED - Connecting via Tor Socket...\n";
		my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NET CLR 1.1.4322)});
		$ua->proxy([qw/ http https /] => 'socks://localhost:9150'); # Tor proxy - 9150 default nao
		$ua->cookie_jar({});
		if($use_pastebin eq "TRUE") { $response = $ua->get($pastebin_raw_url); } else { $response = $ua->get($mpex_depth_feed); }
		$html = $response->content;
	} elsif(($ARGV[1] eq "" or $ARGV[1] eq "no-tor") or ($ARGV[2] eq "" or $ARGV[2] =~ m/no-tor/i)) {
		print "TOR DISABLED! Naked connection in progress...\n";
		my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NET CLR 1.1.4322)});
		$ua->timeout(30);
		my $response;
		if($use_pastebin eq "TRUE") { $response = $ua->get($pastebin_raw_url); } else { $response = $ua->get($mpex_depth_feed); }
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
}
