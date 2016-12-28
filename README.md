# Bettertron

bettertron is a tool that will scan your better.php. It will check a specified directory for your seeded FLACs and transcode them into the needed MP3 bitrates. It is edition aware and will transcode all the needed bitrates for the edition you are seeding, regardless of better.php.

### How to use

bettertron uses several command line tools that are expected to exist:

* lame
* flac
* mktorrent

If you are running ubuntu/debian, this command should get all of them:
`apt-get install mktorrent flac lame`

This project uses some pre-existing perl modules from CPAN. To install them in Ubuntu/debian (and probaly anything else) in one line:
`sudo perl -MCPAN -e 'install WWW::Mechanize, JSON, JSON::XS, Data::Dumper, Config::IniFiles, Bencode, Crypt::SSLeay'`

After that, simply run the better.pl script once. It will generate a config file called better.ini
Fill it out with the following information:
* username and password refer to your apollo.rip username and password
* torrentdir is where bettertron will create torrents for your transcodes
* flacdir is where bettertron will look for your already existing and seeded flacs
* transcodedir is where your flac transcodes will end up


### SEEDBOXES:

It's possible that you may not have privileges to install these cpan modules on your seedbox. A helpful user said these steps work on whatbox:

```
curl -L http://cpanmin.us | perl - App::cpanminus
~/perl5/bin/cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
echo eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib) >> ~/.bashrc
cpanm WWW::Mechanize JSON JSON::XS Data::Dumper Config::IniFiles Bencode Crypt::SSLeay
```

### TODO:

* Handle torrent upload errors more gracefully (had a couple rejected due to thumb.db restriction. Imagine 1982/original release/CD media will be a problem also)
* Better error or unexpected condition handling.
* Consider including perl modules with the package so that it can run more "stand alone". Useful for seeboxes or other situations where you don't have root
