#!/usr/bin/perl -w

use Test::More tests => 39;

# basic include test
BEGIN {use_ok('GridMon::Nagios::Downtimes');}
require_ok( 'GridMon::Nagios::Downtimes' );

# test functions with non-existing config file
my $dts = GridMon::Nagios::Downtimes->new('/non/existing/config/file');
isa_ok $dts, 'GridMon::Nagios::Downtimes';
$res = $dts->fetchDowntimeData;
ok (!$res, "fetchDowntimeData return 0");
like($dts->{ERROR}, qr/Failed opening main config file/, "got correct error message");
$res = $dts->addDowntime({});
ok (!$res, "addDowntime return 0");
like($dts->{ERROR}, qr/Failed opening main config file/, "got correct error message");

# create bogus main file
#   - test non existing status &
#   - test command file on which you can'write
if ($res = open(STD, ">nagios.cfg")) {
    $res &&= print STD "command_file=/non/existing/dir/nagios.cmd\n";
    $res &&= print STD "status_file=/non/existing/dir/nagios.status\n";
    $res &&= close STD;
}
ok ($res, "successfully created test files");
SKIP: {
    skip "failed creating test files", 5 if !$res;

    my $dts = GridMon::Nagios::Downtimes->new('nagios.cfg');
    isa_ok $dts, 'GridMon::Nagios::Downtimes';
    $res = $dts->fetchDowntimeData;
    ok (!$res, "fetchDowntimeData return 0");
    like($dts->{ERROR}, qr/Failed opening downtime file/, "got correct error message");
    $res = $dts->addDowntime({});
    ok (!$res, "addDowntime return 0");
    like($dts->{ERROR}, qr/Failed opening command file/, "got correct error message");
};

# create bogus main file
#   - test example status file with several downtimes
#   - simulate adding/removing downtimes
if ($res = open(STD, ">nagios.cfg")) {
    $res &&= print STD "status_file=nagios.status\n";
    $res &&= print STD "command_file=nagios.cmd\n";
    $res &&= close STD;
}
if ($res &&= open(STD, ">nagios.status")) {
    $res &&= print STD "
hostdowntime {
    downtime_id=1
    host_name=bogus.host
    start_time=1231419928
    end_time=1231440173
    author=test
    comment=1222#mojtest
 }
hostdowntime {
    downtime_id=2
    host_name=lupus.host
    start_time=1231419928
    end_time=1231440173
    author=test
    comment=1222#mojtest
 }
hostdowntime {
    downtime_id=3
    host_name=bogus.host
    start_time=1231419928
    end_time=1231440173
    author=test
    comment=1444#mojtest
 }
";
    $res &&= close STD;
}
unlink 'nagios.cmd';
ok ($res, "successfully created test files");

SKIP: {
    skip "failed creating test files", 25 if !$res;

    my $dts = GridMon::Nagios::Downtimes->new('nagios.cfg');
    isa_ok $dts, 'GridMon::Nagios::Downtimes';

    # fetching methods
    $res = $dts->fetchDowntimeData;
    ok ($res, "fetchDowntimeData return 1");

    @maints = sort $dts->getMaints;
    @expmaints = (1222, 1444);
    is_deeply( \@maints, \@expmaints, "getMaints return proper structure" );

    @hosts = $dts->getMaintHosts(1222);
    @exphosts = ('bogus.host','lupus.host');
    is_deeply( \@hosts, \@exphosts, "getMaintHosts return proper array" );

    ok ($dts->existsMaint(1222), "existsMaint: checking existing maint");
    ok (!$dts->existsMaint(1223), "existsMaint: checking non-existing maint");

    my $downtime = $dts->getMaintHostDowntime(1444, 'bogus.host');
    isa_ok $downtime, 'HASH';
    is ($downtime->{downtime_id}, 3, "getMaintHostDowntime returns proper ID");
    is ($downtime->{host_name}, 'bogus.host', "getMaintHostDowntime returns proper hostname");
    is ($downtime->{maintID}, 1444 , "getMaintHostDowntime returns proper maint ID");
    ok (!$dts->getMaintHostDowntime(1445, 'lupus.host'), "getMaintHostDowntime behaves good for non-existing maint entry");
    ok (!$dts->getMaintHostDowntime(1444, 'lupus.host'), "getMaintHostDowntime behaves good for non-existing host entry");
    
    # adding methods
    ok (!$dts->addDowntime({}), "addDowntime with missing data");
    like($dts->{ERROR}, qr/Missing attribute/, "got correct error message");
    $attrs = {  hostname=>'bogus.host',
                start_time=>1231419928,
                end_time=> 1231440173,
                author=>'test',
                maintID=>1555,
                comment=>'TEST_PURPOSE' };
    ok ($dts->addDowntime($attrs), "addDowntime for host");
    $attrs->{hostname} = 'test.site';
    ok ($dts->addDowntime($attrs, 1), "addDowntime for site");

    # removing methods
    ok ($dts->removeDowntime(5), "removeDowntime behaves good for non-existing downtime entry");
    ok ($dts->removeDowntime(1), "removeDowntime for downtime 1");
    ok ($dts->removeDowntimeByMaint(1), "removeDowntimeByMaint behaves good for non-existing maintenance");
    ok ($dts->removeDowntimeByMaint(1222), "removeDowntimeByMaint for maintenance 1222");

    # check content of command file
    if ($res = open(STD, "nagios.cmd")) {
        $line = <STD>;
        like ($line, qr/SCHEDULE_AND_PROPAGATE_HOST_DOWNTIME;bogus.host;$attrs->{start_time};$attrs->{end_time};1;0;0;$attrs->{author};$attrs->{maintID}\#$attrs->{comment}/, "entry in nagios.cmd for addDowntime for host");
        $line = <STD>;
        like ($line, qr/SCHEDULE_HOSTGROUP_HOST_DOWNTIME;test.site;$attrs->{start_time};$attrs->{end_time};1;0;0;$attrs->{author};$attrs->{maintID}\#$attrs->{comment}/, "entry in nagios.cmd for addDowntime for site");
        $line = <STD>;
        like ($line, qr/DEL_HOST_DOWNTIME;1/, "entry in nagios.cmd for removeDowntime for downtime 1");
        $line = <STD>;
        like ($line, qr/DEL_HOST_DOWNTIME;1/, "1. entry in nagios.cmd for removeDowntimeByMaint for maintenance 1222");
        $line = <STD>;
        like ($line, qr/DEL_HOST_DOWNTIME;2/, "2. entry in nagios.cmd for removeDowntimeByMaint for maintenance 1222");
    }
};

unlink 'nagios.cfg';
unlink 'nagios.status';
unlink 'nagios.cmd';
