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

# BitOTTer Market VWAP Tool for MPEx (bitotter_vwap.pl)
# Copyright (c) 2012 bitotter.com <modsix@gmail.com> 0xD655A630A13E8C69 

use JSON;
use LWP::UserAgent; 
use LWP::Simple qw(get);
 
my $url = "http://mpex.co/mpex-vwap.php";
my $json = new JSON;
my $json_text;
my $mpsic;

if(!$ARGV[0]) { 
	print "Usage: ./bitotter_vwap.pl [MPSIC] [usetor]\n";
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
print "..::[ BitOTTer VWAP Tool for MPEx: $ARGV[0] ]::..\n";
while (my ($code, $rolling_window) = each %$mpsic) {
	if($code eq $ARGV[0]) {
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
