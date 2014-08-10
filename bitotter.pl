#!/usr/bin/perl -w

#
# Copyright (c) 2012, 2013, 2014
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

# BitOTTer for MPEx [Perl Version for UNIX] (bitotter.pl) v0.0.5
# Copyright (c) 2012, 2013, 2014 BitOTTer.com <modsix@gmail.com> 0x721705A8B71EADAF

use GPG;
use LWP::UserAgent;
use Term::ReadKey;
use CGI;

## Some Globals we need set: Make sure that $TMP_DIR and $PATH_TO_GPG_HOME are set correctly to your environment.
my $TMP_FILE = createOutputFileName();
my $TMP_DIR = "/tmp";
my $PATH_TO_GPG_HOME = "~/.gnupg/";
my $URL = "http://mpex.bz";
my $MPEX_PGP_KEY_ID = "EE2BDEF602DD2D91"; # as of 20140720
my $BEGIN_PGP_MSG = "-----BEGIN PGP MESSAGE-----";
my $END_PGP_MSG = "-----END PGP MESSAGE-----";
my $GPG = new GPG(homedir => $PATH_TO_GPG_HOME);
die $GPG->error() if $GPG->error();

sub BitOTTerMain() {
	print "..::[ BitOTTer (for UNIX) ]::..\n";   
	if(!$ARGV[0] && !$ARGV[1]) {
		print "Usage: ./bitotter.pl \"MPEx COMMAND\" [usetor] \n";
		print "   ex: ./bitotter.pl \"STAT\" [usetor] \n";
		print "Review this FAQ for all commands you can issue: http://mpex.co/faq.html\n";
	} else {
		checkForMPExKey();
		my $PGP_PUB_KEY_ID = getGPGUserID();
		my $PASSPHRASE = getPassphrase();

		my $MPEX_CMD = $ARGV[0]; # STAT|BUY|SELL|CANCEL etc.

		## Clearsign the cmd to MPEx
		$clearsigned_mpex_cmd = $GPG->clearsign($PGP_PUB_KEY_ID, $PASSPHRASE, $MPEX_CMD) or die "$! BitOTTer Error: Problem clear-signing MPEx Cmd! Double check PGP Keys and Passphrase!\n";

		## Encrypt the cmd to MPEx
		$encrypted_mpex_cmd = $GPG->encrypt($clearsigned_mpex_cmd, $MPEX_PGP_KEY_ID) or die "$! BitOTTer Error: Problem encrypting cmd to send to MPEx! Did you sign the MPEx Public Key?\n"; 

		## Send command to MPEx
		my $pgp_response = sendToMPEx();
		
		## Parse Response from MPEx
		if($pgp_response) { 
			$PGP_REPLY = parseResponse($pgp_response);
		} else {
			print "BitOTTer Error: parseRepsonse() => Check $TMP_DIR/$TMP_FILE and attempt to decrypt by hand if a PGP message is found!\n";
		}

		## Decrypt the reply from MPEx
		my $decrypted_order = $GPG->decrypt($PASSPHRASE, $PGP_REPLY) or die "$! Problem decrypting reply from MPEx!! Bad Passphrase? Try to decrypt $TMP_DIR/$TMP_FILE by hand.\n";
		if($decrypted_order) { 
			print "DECRYPTED ORDER FROM MPEx:\n$decrypted_order\n";
		} else {
			print "BitOTTer Error: Problem decrypting reply from MPEx! Please check $TMP_DIR/$TMP_FILE and decrypt by hand if possible.\n";
		}
	}
	
	exit;
}

sub checkForMPExKey {
	## First check to see that the MPEx key is imported already into the users keyring
	my @keyring = $GPG->list_keys() or die "$! BitOTTer Error: checkForMPExKey() => Couldn't get the list of GPG keys on local keyring! Exiting!\n";
	my $mk_tmp = $keyring[0];
	my @keyring_keys = @$mk_tmp;
	my $key_id = "";
	my $mpex_key_found = "";

	foreach (@keyring_keys) { 
		$key_id = $_->{'key_id'};
		if(!$key_id) {
			next; # some entries could be null.
		} elsif($key_id =~ m/$MPEX_PGP_KEY_ID/) { 
			$mpex_key_found = "1";
			print "MPEx Key Found: $key_id\n";	
		}
	}

	if(!$mpex_key_found) { 
		print "BitOTTer Error: checkForMPExKey() => MPEx Public Key: $MPEX_PGP_KEY_ID Not Found on Users Keyring.\n"; 
		print "Please locate on gpg.mit.edu, import and try again.\n";
		print "     : for more info check here: http://mpex.co/faq.html#6\n";
		print "     :                   & here: http://mpex.co/faq.html#8\n";
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
	my @lk = $GPG->list_keys() or die "$! BitOTTer Error: getGPGUserID() => Couldn't get list of GPG keys on local keyring! Exiting!\n";
	my $gpgkeys = $lk[0];
	my @listkeys = @$gpgkeys;
	my $uid = "";

	## Loop through the keyring and find the matching user id.
	foreach(@listkeys) {
		$uid = $_->{'user_id'};
		if(!$uid) { 
			next; # some entries could be null
		} elsif($uid =~ m/$search_key/i) { 
			print "Public Key Found: $_->{'key_id'} for user: $uid\n";
			$PGP_PUB_KEY_ID	= $_->{'key_id'};
		}
	}

	## Check with the user and make sure we found the correct key on the KeyRing	
	print "Was this the correct public key id? [Y/N]:\n";
	my $correct_key = ReadLine 0;
	chomp($correct_key);	
	ReadMode(0); # normal mode

	if($correct_key =~ m/n/i) { 
		print "Details of PGP Public Key found on KeyRing:\n";
		print "\tPublic Key Id [long format]: $PGP_PUB_KEY_ID\n";
		print "Would you like to try again? Answer 'N' if you wish to return to the terminal. [Y/N]\n";
		my $try_again = ReadLine 0;
		chomp($try_again);
		if($try_again =~ m/y/i) { 
			getGPGUserID();
		} else { 
			print "Exiting via request.\n";
			exit;
		}
	} elsif($correct_key =~ m/y/i) {
		return $PGP_PUB_KEY_ID;
	} else {
		print "Unknown repsonse, please try again.\n";	
		getGPGUserID();
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

	## Check to see if we should attempt to connect to MPEx via Tor Socket on port 9150
	if(defined $ARGV[1] && $ARGV[1] eq "usetor") {
		print "TOR ENABLED - Connecting to MPEx via Tor Socket...\n";
		my $ua = LWP::UserAgent->new(agent => q{Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; YPC 3.2.0; .NET CLR 1.1.4322)},);
		$ua->proxy([qw/ http https /] => 'socks://localhost:9150'); # Tor proxy - 9150 new default port number !?
		$ua->cookie_jar({});
		$response = $ua->post($URL, {'msg' => $encrypted_mpex_cmd});
		$web_content = $response->decoded_content();	
	} else {
		print "Tor disabled - Naked connection to MPEx in progress...\n";
		my $user_agent = LWP::UserAgent->new();
		$response = $user_agent->post($URL, {'msg' => $encrypted_mpex_cmd});
		$web_content  = $response->decoded_content();
	}

	## Write out the web-content for safe keeping - a person could decrypt by hand.
	open RES, ">$TMP_DIR/$TMP_FILE" or die "$! BitOTTer Error: sendToMPEx() => Couldn't open the $TMP_DIR/$TMP_FILE file for writing! Exiting! Check $TMP_DIR permissions.\n";
	print RES $web_content;	
	close RES;
	return $web_content;
}

sub parseResponse { 
	## Open the saved web-content reply file from MPEx for parsing out the PGP message.
	## Then check to make sure what we grabbed was indeed a PGP message.

	my $pgp = $_[0]; # Get the pgp_response from the array of parameters.

	## If we don't match a $pgp message through the function parameter, attempt to open the $TMP_DIR/$TMP_FILE as a last resort to grab the PGP messagen.
	if($pgp !~ m/$BEGIN_PGP_MSG/) {
		open PGP_RES, "<$TMP_DIR/$TMP_FILE" or die "$! BitOTTer Error: parseResponse() => Couldn't open the $TMP_DIR/$TMP_FILE file for reading! Exiting! Attempt to decrypt $TMP_DIR/$TMP_FILE by hand.\n";
		while(<PGP_RES>) { $pgp .= $_; }
		close PGP_RES;
		if($pgp =~ m/$BEGIN_PGP_MSG/) { return $pgp; } 
	} elsif($pgp =~ m/$BEGIN_PGP_MSG/) { ## If we do match a PGP message, go ahead an return it for decryption
		return $pgp;
	} else {
		print "BitOTTer Error: parseResponse() => PGP MESSAGE REGEX FAILURE!\n";
		print "Parsed response message from MPEx did not match a PGP Message.\n";
		print "Check $TMP_DIR/$TMP_FILE output file and attempt to decrypt $TMP_DIR/$TMP_FILE by hand.\n";
	}

	exit; 
}

sub createOutputFileName {
	@DMY = (localtime)[3..5]; # Grab 3,4,5 for D/M/Y values from localtime

	my $date = "";
	my $month = "";
	my $YYYYMMDD = "";
	my $outputFilename = "";

	if($DMY[0] < 10) { $date = "0" . $DMY[0]; } else { $date = $DMY[0]; }
	$DMY[1] += 1;  # Month values start at 0, increment by 1 for actual month numerical value.
	if($DMY[1] < 10) { $month = "0" . $DMY[1]; } else { $month = $DMY[1]; }

	$YYYYMMDD .= $DMY[2] + 1900; # Required for four digit year: http://perldoc.perl.org/functions/localtime.html
	$YYYYMMDD .= $month;
	$YYYYMMDD .= $date;
	
	## Append the current date in YYYYMMDD format, in additionally add the current UNIXTIME (time) to output filename.
	$outputFileName = "mpex_reply_" . $YYYYMMDD . "_" . time . ".txt";
	return $outputFileName;
} 

BitOTTerMain();
