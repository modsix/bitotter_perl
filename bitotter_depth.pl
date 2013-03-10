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

# BitOTTer Market Depth Tool for MPEx (bitotter_depth.pl)
# Copyright (c) 2012,2013 bitotter.com <modsix@gmail.com> 0xD655A630A13E8C69 

use JSON;
use LWP::UserAgent; 
use LWP::Simple qw(get);
use POE;
use POE::Component::IRC;

## Globals 
my $TMP_DIR = "/tmp";
my $pastebin_raw_url = "http://pastebin.com/raw.php?i="; #pastebin key needs to be appended to the end like: http://pastebin.com/raw.php?i=C1dT6RrM
my $pastebin_key = "";

if(!$ARGV[0]) { 
	print "Usage: ./bitotter_vwap.pl [MPSIC]\n";
	exit 1;
} 

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
    irc_public => \&on_public,
  },
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
	$irc->yield(join => $irc_channel);

	sleep(1);

	## Send $vwap command to mpexbot:
	$irc->yield(privmsg => $irc_channel, "\$depth");
}

sub on_public {
	## Prepare for mpexbot response
	my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
	my $nick = (split /!/, $who)[0];
	my $channel = $where->[0];
	
	## XXX TESTING ONLY: if($sender =~ m/mod6/) { 
	if($sender =~ m/mpexbot/) { 
		$irc->yield(privmsg => $irc_channel, 'Something is wrong here, not communicating with mpexbot!');
		$irc->yield(quit => $irc_channel);
	}

	if($what =~ m/http:\/\/pastebin.com\/(.*)/) { 
		## Get the response pastebin/dpaste URL 
		$pastebin_key = $+;	
	}

	## Get the Depth From the constructed URI
	getDepth();
	## Display the parsed JSON per MPSIC
	displayDepth();

	$irc->yield(quit => $irc_channel);
}

sub getDepth {

	if($pastebin_key ne "") { 
		$pastebin_raw_url .= $pastebin_key;
	}
	
	my $user_agent = LWP::UserAgent->new();
	$user_agent->timeout(30);

	my $request = HTTP::Request->new('GET', $pastebin_raw_url);
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
	
	my $json = new JSON;
	my $mpsic = $json->allow_unknown->relaxed->decode($json_depth_data);

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
