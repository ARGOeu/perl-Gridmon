#!/usr/bin/perl -w

use Test::More tests => 4;

#use lib 'lib'; if (-d 't') { chdir 't'; }

BEGIN {use_ok('GridMon::MsgCache');}

use File::Path;

rmtree ("log");
ok mkdir ("log");
ok mkdir ("log/qdir");
my $cache = GridMon::MsgCache->new({ dir => 'log/qdir' });
ok ($cache);

