#!/usr/bin/perl -w

use Test::More tests => 37;

# basic include test
BEGIN {use_ok('GridMon::Nagios::Passive');}
require_ok( 'GridMon::Nagios::Passive' );

####
# test functions with non-existing config file
# test functions which don't depend on files
####
my $dts = GridMon::Nagios::Passive->new('/non/existing/config/file');
isa_ok $dts, 'GridMon::Nagios::Passive';

# first we run tests which don't depend on config files
# test publishPassiveResultString
$res = $dts->publishPassiveResultString();
ok (!$res, "publishPassiveResultString return 0");
like($dts->{ERROR}, qr/String for publishing must be defined/, "got correct error message");
$dts->clearError();
# test publishPassiveResult
# should fail in getPassiveResultString
$res = $dts->publishPassiveResult(undef,undef,undef,undef,'/non/existing/mode/file');
ok (!$res, "publishPassiveResult return 0");
like($dts->{ERROR}, qr/Missing attribute/, "got correct error message");
$dts->clearError();
# test getPassiveResultString
# let's fail getPassiveResultString with empty ref
$res = $dts->getPassiveResultString({});
ok (!$res, "getPassiveResultString return 0");
like($dts->{ERROR}, qr/Missing attribute/, "got correct error message");
$dts->clearError();
# let's use getPassiveResultString to get passive result
$res = $dts->getPassiveResultString({hostname=>'localhost', timestamp=>'10000', servicename=>'test', status=>0, output=>'test'});
ok ($res, "getPassiveResultString return ok");
like($res, qr/\[10000\] PROCESS_SERVICE_CHECK_RESULT;localhost;test;0;test/, "got correct result message");

# now let's do tests which require config file
$res = $dts->publishPassiveResultString('blahblah');
ok (!$res, "publishPassiveResultString return 0");
like($dts->{ERROR}, qr/Failed opening main config file/, "got correct error message");
$dts->clearError();
# this quy should fail in publishPassiveResultString
$dts->{SUBMIT_METHOD}=undef;
$res = $dts->publishPassiveResult('localhost','test',0,'test','/non/existing/mode/file');
ok (!$res, "publishPassiveResult return 0");
like($dts->{ERROR}, qr/Failed opening main config file/, "got correct error message");
$dts->clearError();

####
# create bogus main file
#   - test command file on which you can't write to
####

if ($res = open(STD, ">nagios.cfg")) {
    $res &&= print STD "command_file=/non/existing/dir/nagios.cmd\n";
    $res &&= close STD;
}
ok ($res, "successfully created test files");
SKIP: {
    skip "failed creating test files", 5 if !$res;

    my $dts = GridMon::Nagios::Passive->new('nagios.cfg');
    isa_ok $dts, 'GridMon::Nagios::Passive';

    $res = $dts->publishPassiveResultString('blahblah');
    ok (!$res, "publishPassiveResultString return 0");
    like($dts->{ERROR}, qr/Failed opening command file/, "got correct error message");
    $dts->clearError();
    # this quy should fail in publishPassiveResultString
    $res = $dts->publishPassiveResult('localhost','test',0,'test','/non/existing/mode/file');
    ok (!$res, "publishPassiveResult return 0");
    like($dts->{ERROR}, qr/Failed opening command file/, "got correct error message");
    $dts->clearError();
};

####
# create bogus main file
#   - simulate sending passive results
####

if ($res = open(STD, ">nagios.cfg")) {
    $res &&= print STD "command_file=nagios.cmd\n";
    $res &&= close STD;
}
unlink 'nagios.cmd';
ok ($res, "successfully created test files");

SKIP: {
    skip "failed creating test files", 5 if !$res;

    my $dts = GridMon::Nagios::Passive->new('nagios.cfg');
    isa_ok $dts, 'GridMon::Nagios::Passive';
    ok ($dts->publishPassiveResultString("blahblah\n"), "publishPassiveResultString return ok");
    ok ($dts->publishPassiveResult('localhost','test',0,'test','/non/existing/mode/file'), "publishPassiveResult return ok");
    # check content of command file
    if ($res = open(STD, "nagios.cmd")) {
        $line = <STD>;
        like ($line, qr/blahblah/, "entry in nagios.cmd from publishPassiveResultString");
        $line = <STD>;
        like ($line, qr/PROCESS_SERVICE_CHECK_RESULT;localhost;test;0;test/, "entry in nagios.cmd from publishPassiveResult");
        close STD;
    }
};

####
# test nagios-submit.conf
#   - simulate sending passive results
####
if ($res = open(STD, ">nagios.submit")) {
    $res &&= print STD "SUBMIT_METHOD=unknown\n";
    $res &&= close STD;
}
ok ($res, "successfully created test files");
SKIP: {
    skip "failed creating test files", 2 if !$res;

    $dts->{SUBMIT_METHOD}=undef;
    $res = $dts->publishPassiveResult('localhost','test',0,'test','nagios.submit');
    ok (!$res, "publishPassiveResult return 0");
    like ($dts->{ERROR}, qr/Unknown mechanism defined./, "got correct error message");
    $dts->clearError();
};

if ($res = open(STD, ">nagios.submit")) {
    $res &&= print STD "SUBMIT_METHOD=nsca\n";
    $res &&= close STD;
}
ok ($res, "successfully created test files");
SKIP: {
    skip "failed creating test files", 2 if !$res;

    $dts->{SUBMIT_METHOD}=undef;
    $res = $dts->publishPassiveResult('localhost','test',0,'test','nagios.submit');
    ok (!$res, "publishPassiveResult return 0");
    like ($dts->{ERROR}, qr/NSCA hostname must be defined if mechanism is/, "got correct error message");
    $dts->clearError();
};

if ($res = open(STD, ">nagios.submit")) {
    $res &&= print STD "SUBMIT_METHOD=nsca\n";
    $res &&= print STD "NSCA_HOST=www.google.com\n";
    $res &&= print STD "NSCA_PORT=11\n";
    $res &&= print STD "NSCA_CONFIG=nagios.send\n";
    $res &&= close STD;
}
if ($res &&= open(STD, ">nagios.send")) {
    $res &&= close STD;
}
ok ($res, "successfully created test files");
SKIP: {
    skip "failed creating test files", 3 if !$res;

    my $dts = GridMon::Nagios::Passive->new('nagios.cfg');
    isa_ok $dts, 'GridMon::Nagios::Passive';
    $res = $dts->publishPassiveResult('localhost','test',0,'test','nagios.submit');
    ok (!$res, "publishPassiveResult return 0");
    like ($dts->{ERROR}, qr/Error connecting to NSCA server./, "got correct error message");
    $dts->clearError();
};

unlink 'nagios.send';
unlink 'nagios.cfg';
unlink 'nagios.submit';
unlink 'nagios.cmd';
