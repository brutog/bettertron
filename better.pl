#!/usr/bin/perl -w

use strict; 
use WWW::Mechanize;
use JSON -support_by_pp;
use JSON qw( decode_json );
use Data::Dumper;
use Bencode qw(bdecode);
use Config::IniFiles;


my $cfg = Config::IniFiles->new( -file => "better.ini" );

#Get username and password from config file.
my $username = $cfg -> val('user', 'username');
my $password = $cfg -> val('user', 'password');

my $flacdir = $cfg -> val('dirs', 'flacdir');

my $login_url = 'http://what.cd/ajax.php?action=index';
my $mech = WWW::Mechanize->new();
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
my $passkey = $login_info->{'response'}{'passkey'};
my $authkey = $login_info->{'response'}{'authkey'};


my $better_url = 'http://what.cd/ajax.php?action=better&method=single&authkey=' . $authkey;
$mech -> get($better_url);
my $better = decode_json($mech -> content());
#print Dumper $better;


for my $href ( @{$better->{'response'}} )
{
	my $groupId = $href->{'groupId'};
	my $torrentId = $href->{'torrentId'};
	my $groupName = $href->{'groupName'};
	my $downloadUrl = $href->{'downloadUrl'};
	
	
	print "Processing Album: $groupName\n";
	print "GroupID: $groupId\n";
	print "TorrentID: $torrentId\n\n";

	my $get_torrent_url = 'http://what.cd/' . $downloadUrl;
	print "Fetching URL: $get_torrent_url\n\n";
	
	$mech -> get($get_torrent_url);
	if (! open( FOUT, "> tmp.torrent"))
	{
		die( "Could not create file: $!" );
	}
	#binmode( FOUT ); # required for Windows. Who uses Windows?
	print( FOUT $mech->response->content() );
	close( FOUT );	
	
	open FILE, "tmp.torrent" or die $!;
	binmode FILE;
	my ($buf, $data, $n);
	while (($n = read FILE, $data, 4) != 0)
        {
		$buf .= $data;
	}
	close(FILE);
	my $bencoded = $buf;
	my $torrent = bdecode ($bencoded, "true");
	my $torrentName = $torrent->{info}->{name};
	print "Torrent name from torrent file: $torrentName\n";
	
	unlink('tmp.torrent');

	my $group_url = 'http://what.cd/ajax.php?action=torrentgroup&id=' . $groupId . '&auth=' . $authkey;
	$mech -> get($group_url);
	my $group = decode_json($mech -> content());
	

	print Dumper $group;
	my $remasterTitle;

	for my $torrents( @{$group->{'response'}{'torrents'}} )
	{
		if($torrents -> {'id'} eq $torrentId)
		{
			$remasterTitle = $torrents -> {'remasterTitle'}; 
		}
		
	}

	my %existing_encodes = 
	(
        320 => '0',
        V0 => '0',
        V2 => '0',
    	);

	if(!defined $remasterTitle)
	{
		$remasterTitle = '';
	}
	
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
	my $command = "perl converter.pl ";

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
		#system($command);
	}
	$addformat_url = "http://what.cd/upload.php?groupid=" . $groupId;
	$mech -> get($addformat_url);

	
	#time to do the form post for uploading the torrent
	#if $remasterTitle is blank, we don't have to fill out edition info. 
	if($remasterTitle = '')
	{
		

		$mech->submit_form(
		form_id => 'upload_table',
		fields =>
		{
		username=>$username,
		password=>$password
		}
	else
	{
		
	}
	
);	
	
	sleep 2;
	print "----------------------------------------------\n";
}

