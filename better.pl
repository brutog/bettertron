#!/usr/bin/perl -w

use strict; 
use WWW::Mechanize;
use JSON -support_by_pp;
use JSON qw( decode_json );
use Data::Dumper;
use Bencode qw(bdecode);
use Config::IniFiles;
#use open IO  => ':locale';
use Encode;
use HTML::Entities;

our $mech = WWW::Mechanize->new();
our $username;
our $password;
our $flacdir;
our $transcodedir;
our $torrentdir;
our $passkey;
our $authkey;

sub chkCfg
{
	unless (-e 'better.ini')
	{
 		print "Your are running Bettertron for the first time!\n";
		print "Creating config file \"better.ini\"\n";
		print "Please read the README for how to fill out the config\n";
		open (MYFILE, '>>better.ini');
 		print MYFILE <<ENDHTML;
[user]
username=
password=

[dirs]
torrentdir=/blah/example/
flacdir=/look/another/
transcodedir=/fill/this/in/with/trailing/slashes/
ENDHTML
 		close (MYFILE);
		exit 0;
	}
	
	
}

sub getCfgValues
{
	#init config reading object
	my $cfg = Config::IniFiles->new( -file => "better.ini" );

	#Get username and password from config file.
	$username = $cfg -> val('user', 'username');
	$password = $cfg -> val('user', 'password');

	#get all the directories we'll need
	$flacdir = $cfg -> val('dirs', 'flacdir');
	$transcodedir = $cfg -> val('dirs', 'transcodedir');
	$torrentdir = $cfg -> val('dirs', 'torrentdir');

}


#this function will do our first login to what.cd. Get us persistence with cookies.
#Get our authkey for the API, passkey for torrent creation and so on.
sub initWeb
{
	my $login_url = 'http://what.cd/ajax.php?action=index';
	$mech -> cookie_jar(HTTP::Cookies->new());
	$mech -> get($login_url);
	$mech->submit_form(
	form_id => 'loginform',
	fields =>
	{
	username=>$username,
	password=>$password
	}
	);
	my $login_info = decode_json($mech -> content());
	$passkey = $login_info->{'response'}{'passkey'};
	$authkey = $login_info->{'response'}{'authkey'};
}


#get our better.pbp JSON object. In the future should be configurable.
#maybe even support the use of tags as per: 
#http://what.cd/forums.php?action=viewthread&threadid=66186&postid=3418797
sub getBetter
{
	#my $better_url = 'http://what.cd/ajax.php?action=better&method=single&authkey=' . $authkey;
	my $better_url = 'http://what.cd/ajax.php?action=better&method=snatch&filter=seeding&authkey=' . $authkey;
	$mech -> get($better_url);
	my $better;
	if($mech -> content() ne '')
	{ 
		$better = decode_json($mech -> content());
	}
	#print Dumper $better;

	return $better;
}

#better.php scraper until we have a JSON dump
sub getBetterScrape
{
	my $better_url = 'http://what.cd/better.php?method=snatch&filter=seeding';
	$mech -> get($better_url);
	my @links = $mech->find_all_links ( 
                                     url_regex => qr{torrents\.php\?id=}
                                );
	return @links;

}

#This function takes a groupId and torrentId as an argument and goes out and gets the appropriate JSON.
#It finds the torrent which you have in the group and gets the torrent name for transcoding
#Also gets all the edition information so we can put the transcodes on the right torrent.
sub process
{
	my $groupId = $_[0];
	my $torrentId = $_[1];

        print "GroupID: $groupId\n";
        print "TorrentID: $torrentId\n";


        my $group_url = 'http://what.cd/ajax.php?action=torrentgroup&id=' . $groupId . '&auth=' . $authkey;
        $mech -> get($group_url);
        my $group = decode_json($mech -> content());


        my $remasterTitle = '';
	my $remasterYear = '';
	my $remasterRecordLabel = '';
	my $remasterCatalogueNumber = '';
	my $media = '';
	my $torrentName = '';
	
        for my $torrents( @{$group->{'response'}{'torrents'}} )
        {
                if($torrents -> {'id'} eq $torrentId)
                {
                        $remasterTitle = $torrents -> {'remasterTitle'};
			$torrentName = decode_entities($torrents -> {'filePath'});
			$torrentName = encode('UTF-8', $torrentName);
			$remasterYear = $torrents -> {'remasterYear'};
			$remasterRecordLabel = $torrents -> {'remasterRecordLabel'};
			$remasterCatalogueNumber = $torrents -> {'remasterCatalogueNumber'};
                	$media = $torrents -> {'media'};
		}

        }
	print "RemasterTitle: $remasterTitle\n";
	print "TorrentName: $torrentName\n\n";
	my %existing_encodes =
        (
        320 => '0',
        V0 => '0',
        V2 => '0',
        );
	#print Dumper $group;

        for my $torrents( @{$group->{'response'}{'torrents'}} )
        {
                if($torrents -> {'remasterTitle'} eq $remasterTitle)
                {
                        if($torrents -> {'encoding'} eq '320')
                        {
                                $existing_encodes{'320'} = 1;
                        }
                        if($torrents -> {'encoding'} eq 'V0 (VBR)')
                        {
                                $existing_encodes{'V0'} = 1;
                        }
                        if($torrents -> {'encoding'} eq 'V2 (VBR)')
                        {
                                $existing_encodes{'V2'} = 1;
                        }
                }

        }
        my $command = "./converter.pl ";

        if($existing_encodes{'320'} == 0)
        {
                $command .= "--320 ";
        }
        if($existing_encodes{'V0'} == 0)
        {
                $command .= "--V0 ";
        }
        if($existing_encodes{'V2'} == 0)
        {
                $command .= "--V2 ";
        }

        $command .= "\"";
        $command .= $flacdir;
        $command .= $torrentName;
        $command .= "\"";

        if($existing_encodes{'320'} == 1 && $existing_encodes{'V0'} == 1 && $existing_encodes{'V2'} == 1)
        {
                print "Nothing to transcode. V2, V0, and 320 exist";
        }
	else
        {
                print "Running transcode with these options: $command\n";
                system($command);
        }
        my $addformat_url = "http://what.cd/upload.php?groupid=" . $groupId;
        $mech -> get($addformat_url);
	print "\n";
	print "Finished transcoding $torrentName\n";

        #time to do the form post for uploading the torrent
        #if $remasterTitle is blank, we don't have to fill out edition info.
        while ( (my $key, my $value) = each %existing_encodes )
	{

		my $bitrateDropdown = '';
		
		if ($existing_encodes{$key} == 0)
		{
			if($key eq 'V0' || $key eq 'V2')
			{
				$bitrateDropdown = $key . " (VBR)";	
			}
			else
			{
				$bitrateDropdown = $key;
			}
			#determine torrent file name
			my $torrentFile = $torrentName . " (" . $key . ").torrent";

			my $add_format_url = "http://what.cd/upload.php?groupid=" . $groupId;
			
			my $uploadFile = [ 
    			$torrentFile,        # The file we are uploading to upload.
    			$torrentFile,     # The filename we want to give the web server.
    			'Content-type' => 'text/plain' # Content type for bonus points.
];
				
			if($remasterYear == 0)
        		{
				print "\n";
				print "Starting Original Release upload:\n";
				print "Format: MP3\n";
				print "Bitrate: $bitrateDropdown\n";
				print "Media: $media\n";
				$mech -> get($add_format_url);
				
				$mech->form_id('upload_table');
				$mech->field('file_input', $uploadFile);
				$mech->select('format', 'MP3');
				$mech->select('bitrate', $bitrateDropdown);
				$mech->select('media', $media);
				
				$mech->submit();
			}
			else
       			{
       				print "Starting Edition Release upload:\n";
				print "Edition: $remasterTitle\n";
				print "Format: MP3\n";
                                print "Bitrate: $bitrateDropdown\n";
                                print "Media: $media\n";
				$mech -> get($add_format_url);
				
                                $mech->form_id('upload_table');
                                $mech->tick("remaster", 'on');
				$mech->field('file_input', $uploadFile);
                                $mech->field('remaster_year', $remasterYear);
                                $mech->field('remaster_title', $remasterTitle);
                                $mech->field('remaster_record_label', $remasterRecordLabel);
                                $mech->field('remaster_catalogue_number', $remasterCatalogueNumber);
                                $mech->select('format', 'MP3');
                                $mech->select('bitrate', $bitrateDropdown);
                                $mech->select('media', $media);
                                
				
				$mech->submit();
				#print $mech->content();
			}
			#move torrent to watch/torrent folder
			my $torrentFileFinal = $torrentdir . $torrentFile;
			
			my $mvCmd = "\"" . $torrentFile . "\" \"" . $torrentFileFinal . "\"";
			`mv $mvCmd`;
		}
	}
}



#main

#argument checks
if (@ARGV > 1 )
{
	print "usage: ./better.pl OR ./better.pl  'http://what.cd/torrents.php?id=1000&torrentid=1000000'";
	exit;
}
if(@ARGV == 1 && $ARGV[0] !~ m/^http:\/\//)
{
	print "usage: argument does not appear to be a URL";
	exit;	
}
chkCfg();
print "Done reading config file\n";
getCfgValues();
initWeb();
my $better = getBetter();

#processing only one torrent via argument else we process our better.php
if(@ARGV == 1)
{
	my $groupId = (split('&',(split('=', $ARGV[0]))[1]))[0];
	my $torrentId = (split('=', $ARGV[0]))[2];
	
	process($groupId, $torrentId);
}
elsif (@ARGV == 0 && defined $better)
{
	print "Using JSON API for better.php source\n";

	for my $href ( @{$better->{'response'}} )
	{
	
        	my $groupId = $href->{'groupId'};
		my $torrentId = $href->{'torrentId'};
		process($groupId, $torrentId);
	
		sleep 2;
		print "-----------------------------------------------------------\n";
	}	
}
else
{
	my @betterScrape = getBetterScrape();	
	#print Dumper(\@betterScrape);
	
	print "JSON API did not return an answer. Fall back to scraping better.php directly\n\n\n";

	foreach (@betterScrape)
	{
		my $scrapeUrl;
		foreach (@$_)
		{
			my $tmp;
			if(defined $_)
			{
				$tmp = $_;
				if($tmp =~ m/torrents\.php\?id=/)
                        	{
                                	$scrapeUrl = $_;
                                	#print "$scrapeUrl\n";
					my $groupId = (split('&',(split('=', $scrapeUrl))[1]))[0];
        				my $torrentId = (split('=', $scrapeUrl))[2];
					#print "$groupId $torrentId\n";
					process($groupId, $torrentId);
					print "-----------------------------------------------------------\n";
                        	}
			}

		}
	}
}
