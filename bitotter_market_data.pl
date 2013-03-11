#!/usr/bin/perl 

#
# Copyright (c) 2012,2013
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

# BitOTTer Market Data Display Tool for MPEx (bitotter_market_data.pl)
# Copyright (c) 2012,2013 bitotter.com <modsix@gmail.com> 0xD655A630A13E8C69 

use JSON;
use LWP::UserAgent; 
use LWP::Simple qw(get);
use POE;
use POE::Component::IRC;

## Globals 
my $TMP_DIR = "/tmp";
my $pastebin_raw_url = "http://pastebin.com/raw.php?i="; 
my $irc_botcontrol_nick = "YOUR_REGISTERED_OTC_IRCNICK_HERE";
my $mpexbot = "mpexbot";
my $pastebin_key = "";
my $req_mpsic = "";
my $req_type = "";

## IRC Settings
my $irc_client_name = "BitOTTer_Perl_Client";
my $irc_nick = "BitOTTer" . $$ % 1000;
my $irc_username = "BitOTTer";
my $irc_name = "BitOTTer Perl Client for MPEx IRC Bots";
my $irc_server = "irc.freenode.net";
my $irc_channel = "#bitcoin-assets";
my $irc_port = "6667";

# Init the IRC Client:
my $irc = POE::Component::IRC->spawn() or die "Failed to launch the local IRC Client! Exiting! Need some help? Find mod6 on irc.freenode.net #BitOTTer or #bitcoin-assets\n $!";

# Create the bot session.
POE::Session->create(
	inline_states => {
		_start     => \&bitotter_start,
		irc_001    => \&on_connect,
		irc_msg	   => \&on_private
	}
);

sub bitotter_start {
	$irc->yield(register => "all");
	$irc->yield(
		connect => { 
			Nick     => $irc_nick,
			Server   => $irc_server,
			Port     => $irc_port,
			Username => $irc_username,
			Ircname  => $irc_name 
		}
	);
}

sub on_connect {
	sleep(3);
	$irc->yield(join => $irc_channel);
}

sub on_private { 
	## Prepare for mpexbot response
	my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
	my $nick = (split /!/, $who)[0];
	my $channel = $where->[0];
		
	if($nick eq $irc_botcontrol_nick && $what =~ m/DEPTH/i) { 
		($req_type, $req_mpsic) = split /\|/, $what;
		$irc->yield(privmsg => $mpexbot, "\$depth"); 
		sleep(10); # Give mpexbot 10 seconds to process.
	} elsif($nick eq $irc_botcontrol_nick && $what =~ m/VWAP/i) {
		($req_type, $req_mpsic) = split /\|/, $what;
		$irc->yield(privmsg => $mpexbot, "\$vwap"); 
		sleep(10); # Give mpexbot 10 seconds to process.
	} elsif($nick eq $mpexbot && $what =~ m/http:\/\/pastebin.com\/(.*)/) {
		$pastebin_key = $+;	
		if($req_type eq "DEPTH") { 
			getDepth();
			displayDepth();
		} elsif($req_type eq "VWAP") { 
			getVWAP();
			displayVWAP();
		} else {
			$irc->yield(privmsg => $irc_botcontrol_nick, "CMD NOT FOUND: Didn't match DEPTH|VWAP!"); 
		}		
	} else {
		$irc->yield(privmsg => $irc_botcontrol_nick, "CMD NOT FOUND!"); 
	}
}

sub getDepth {
	my $tmp_raw_url = $pastebin_raw_url;
	if($pastebin_key ne "") { 
		$tmp_raw_url .= $pastebin_key;
	}
	
	my $user_agent = LWP::UserAgent->new();
	$user_agent->timeout(30);

	my $request = HTTP::Request->new('GET', $tmp_raw_url);
	my $response = $user_agent->request($request);
	my $html = $response->content;
	
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

	print "..::[ BitOTTer Market Depth for MPEx: $req_mpsic ]::..\n";
	while (my ($code,$trade) = each %$mpsic) {
		if($req_mpsic eq "ALL") { 
			print "MPSIC => $code:\n";
			while (my ($action,$act_ref) = each %$trade) {
				my @sorted = sort { $b->[0] <=> $a->[0] } @$act_ref;
				foreach (@sorted) {
					print "$action => Price: @$_[0]\tVolume: @$_[1]\n";
				}
			}
		} else {
			if($code eq $req_mpsic) {
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

sub getVWAP {
	my $tmp_raw_url = $pastebin_raw_url;
	if($pastebin_key ne "") { 
		$tmp_raw_url .= $pastebin_key;
	}
	
	my $user_agent = LWP::UserAgent->new();
	$user_agent->timeout(30);

	my $request = HTTP::Request->new('GET', $tmp_raw_url);
	my $response = $user_agent->request($request);
	my $html = $response->content;
	
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

	print "..::[ BitOTTer VWAP Tool for MPEx: $req_mpsic ]::..\n";
	while (my ($code, $rolling_window) = each %$mpsic) {
		if($code eq $req_mpsic) {
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

$poe_kernel->run();
exit 0;
