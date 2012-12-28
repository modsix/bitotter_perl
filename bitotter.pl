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

# BitOTTer for MPEx [Perl Version for UNIX] (bitotter.pl)
# Copyright (c) 2012 bitotter.com <modsix@gmail.com> 0xD655A630A13E8C69 

use GPG;
use LWP::UserAgent;
use Term::ReadKey;
use CGI;

## Some Globals we need set: Make sure that $TMP_DIR and $PATH_TO_GPG_HOME are set correctly to your environment.
my $TMP_DIR = "/tmp";
my $PATH_TO_GPG_HOME = '~/.gnupg/';
my $URL = 'http://mpex.co';
my $MPEX_GPG_KEY_ID = "9214FC6BF1B69921"; # as of 20120730
my $BEGIN_PGP_MSG = "-----BEGIN PGP MESSAGE-----";
my $END_PGP_MSG = "-----END PGP MESSAGE-----";
my $GPG = new GPG(homedir => $PATH_TO_GPG_HOME);
die $GPG->error() if $GPG->error();

print "..::[ BitOTTer (for UNIX) ]::..\n";   
if(!$ARGV[0] && !$ARGV[1]) {
	print "Usage: ./bitotter.pl \"MPEX COMMAND\" [usetor] \n";
        print "   ex: ./bitotter.pl \"STAT\" [usetor] \n";
	print "Review this FAQ for all commands you can issue: http://polimedia.us/bitcoin/faq.html\n";
} else {

	checkForMPExKey();
	my $GPG_PUB_KEY_ID = getGPGUserID();
	my $PASSPHRASE = getPassphrase();

	my $MPEX_CMD = $ARGV[0]; # STAT|BUY|SELL|CANCEL etc.

	## Clearsign the cmd to MPEx
	$clearsigned_mpex_cmd = $GPG->clearsign($GPG_PUB_KEY_ID, $PASSPHRASE, $MPEX_CMD) or die "$! Problem Clearsigning MPEx cmd! Double check GPG keys and Passphrase!\n";

	## Encrypt the cmd to MPEx
	$encrypted_mpex_cmd = $GPG->encrypt($clearsigned_mpex_cmd, $MPEX_GPG_KEY_ID) or die "$! Problem encrypting cmd to send to MPEx!\n";

	## Send command to MPEx
	sendToMPEx();
	
	## Parse Response from MPEx
	my $PGP_REPLY = parseResponse();
	#print "$PGP_REPLY\n";  # Is set to everthing it should be in debugging
	#print "$PASSPHRASE\n"; # Is set to everthing it should be in debugging

	## Decrypt the reply from MPEx
	$decrypted_order = $GPG->decrypt($PASSPHRASE, $PGP_REPLY) or die "$! Problem decrypting reply from MPEx!! Bad Passphrase? Try to decrypt $TMP_DIR/mpex_reply.txt by hand.\n";
	if($decrypted_order) { 
		print "DECRYPTED ORDER FROM MPEx:\n$decrypted_order\n";
	}
}

sub checkForMPExKey {
	## First check to see that the MPEx key is imported already into the users keyring
	my @keyring = $GPG->list_keys() or die "$! Couldn't get the list of GPG keys on local keyring! Exiting!\n";
	my $mk_tmp = $keyring[0];
	my @keyring_keys = @$mk_tmp;
	my $key_id = "";
	my $mpex_key_found = "";

	foreach (@keyring_keys) { 
		$key_id = $_->{'key_id'};
		if(!$key_id) {
			next; # some entries could be null.
		} elsif($key_id =~ m/$MPEX_GPG_KEY_ID/) { 
			$mpex_key_found = "1";
			print "MPEx Key Found: $key_id\n";	
		}
	}

	if(!$mpex_key_found) { 
		print "Error: MPEx Public Key: $MPEX_GPG_KEY_ID Not Found on Users Keyring. Please locate on gpg.mit.edu, import and try again.\n";
		print "     : for more info check here: http://polimedia.us/bitcoin/faq.html#6\n";
		print "     :                   & here: http://polimedia.us/bitcoin/faq.html#8\n";
		exit;
	}
}

sub getGPGUserID {
	## User must enter search string to select their public gpg key from the keyring.
	print "GPG Public Key username [email|name|keyid|org]:\n";
	my $search_key = ReadLine 0;
	chomp($search_key);
	ReadMode(0); # normal mode

	## List off the keys
	my @lk = $GPG->list_keys() or die "$! Couldn't get list of GPG keys on local keyring! Exiting!\n";
	my $gpgkeys = $lk[0];
	my @listkeys = @$gpgkeys;
	my $uid = "";

	## Loop through the keyring and find the matching user id.
	foreach(@listkeys) {
		$uid = $_->{'user_id'};
		if(!$uid) { 
			next; # some entries could be null
		} elsif($uid =~ m/$search_key/) { 
			print "Public Key Found: $_->{'key_id'} for user: $uid\n";
			$GPG_PUB_KEY_ID	= $_->{'key_id'};
		}
	}

	## Check with the user and make sure we found the correct key on the KeyRing	
	print "Was this the correct public key id? [Y/N]:\n";
	my $correct_key = ReadLine 0;
	chomp($correct_key);	
	ReadMode(0); # normal mode

	if($correct_key =~ m/n|N/) { 
		print "Details of PGP Public Key found on KeyRing:\n";
		print "\tPublic Key Id [long format]: $GPG_PUB_KEY_ID\n";
		print "Would you like to try again? Answer 'N' if you wish to return to the terminal. [Y/N]\n";
		my $try_again = ReadLine 0;
		chomp($try_again);
		if($try_again =~ m/y|Y/) { 
			getGPGUserID();
		} else { 
			print "Exiting via request.\n";
			exit;
		}
	} elsif($correct_key =~ m/y|Y/) {
		return $GPG_PUB_KEY_ID;
	}
}

sub getPassphrase {
	## User must enter their GPG passphrase so we can continue GPG operations.
	print "Enter GPG Passphrase [will not echo back to terminal]:\n";
	ReadMode('noecho'); # do not echo back to terminal
	my $PASSPHRASE = ReadLine 0;
	chomp($PASSPHRASE);
	ReadMode(0); # return to normal mode.
	return $PASSPHRASE;
}

sub sendToMPEx {
	## Send the order to MPEx
	my $web_content;
	my $response;

	## Check to see if we should attempt to connect to MPEx via Tor Socket on port 9050
	if($ARGV[1] eq "usetor") {
		print "TOR ENABLED - Connecting to MPEx via Tor Socket...\n";
		my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NET CLR 1.1.4322)},);
		$ua->proxy([qw/ http https /] => 'socks://localhost:9050'); # Tor proxy - 9050 default
		$ua->cookie_jar({});
		$response = $ua->post($URL, {'msg' => $encrypted_mpex_cmd});
		$web_content = $response->decoded_content();	
	} else {
		print "Tor disabled - naked connection to MPEx in progress ...\n";
		my $user_agent = LWP::UserAgent->new();
		$response = $user_agent->post($URL, {'msg' => $encrypted_mpex_cmd});
		$web_content  = $response->decoded_content();
	}

	## Write out the web-content for safe keeping, incase of failure (then a person could decrypt by hand).
	open RES, ">$TMP_DIR/mpex_reply.txt" or die "$! Couldn't open the $TMP_DIR/mpex_reply.txt file for writing! Exiting!  Check $TMP_DIR permissions.\n";
	print RES $web_content;	
	close RES;
}

sub parseResponse { 
	## Open the saved web-content reply file from MPEx for parsing out the PGP message.
	## Then check to make sure what we grabbed was indeed a PGP message.
	open HTML_RES, "<$TMP_DIR/mpex_reply.txt" or die "$! Couldn't open the $TMP_DIR/mpex_reply.txt file for reading!  Exiting! Locate file and try to decrypt by hand.\n";
	my $html = "";
	while(<HTML_RES>) { $html .= $_; }
	close HTML_RES;
	my $PGP_REPLY = "";
	if(!$html) { 
		print "Error: HTML wasn't correctly read from file! Exiting! Check output file.\n";
		exit;
	} elsif($html =~ m/<body>(.*)<\/body>/sm) {  # Grab the PGP message between the body tags, like a boss.
		$PGP_REPLY = $+; 	
		if(($PGP_REPLY =~ m/$BEGIN_PGP_MSG/) && ($PGP_REPLY =~ m/$END_PGP_MSG/)) { # check to make sure we grabbed a PGP message.
			return $PGP_REPLY;
		} else {
			print "Error: PGP MESSAGE REGEX FAILURE!\n";
			print "Whatever was parsed from inbetween the <body></body> tags in MPEx return wasn't a PGP Message.\n";
			print "Check the mpex_reply.txt output file.\n";
			exit;
		}
	} 

	print "PGP MESSAGE NOT FOUND IN REPLY FROM MPEX! Check mpex_reply.txt file. Can not continue... exiting.\n";	
	exit; 
}
