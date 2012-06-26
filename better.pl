#!/usr/bin/perl -w

use strict; 
use WWW::Mechanize;
use JSON -support_by_pp;
use JSON qw( decode_json );
use Data::Dumper;
use Bencode qw(bdecode);


#please enter your what.cd username and password here
my $username = "";
my $password = "";

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
	#binmode( FOUT ); # required for Windows
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

	#$group->

	sleep 2;
	print "----------------------------------------------\n";
}

