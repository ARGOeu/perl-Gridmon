#! /usr/bin/perl -w
#
# Set of common functions used in Nagios plugins
# Copyright (c) 2007 Emir Imamagic
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Changes and Modifications
# =========================
# 21-Mar-2007 - Created; 
#               Parts of Nagios utils.pm are taken in order to make 
#               plugins Nagios-agnostic
#
# 11-Jan-2008 - Added wrapper processCommand for safe execution of shell commands

package GridMon::sgutils;

use Sys::Hostname;
use Date::Format;
use GridMon::Nagios::Passive;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw($DEFAULT_NAGIOS_CFG $SERVICEURI $SERVICETYPE $METRICNAME $SRM_PATH $GLOBUS_TCP_PORT_RANGE $GLOBUS_LOCATION $EDG_LOCATION $LCG_LOCATION $GLITE_LOCATION $TIMEOUT $VONAME $OUTPUT_TYPE @METRICS %ERRORS %OUTPUT_TYPES %COMMANDS &print_revision &support &printOutput &checkCommands &checkCommand &checkProxy &createProxy &printWLCGList &checkHost &checkEnvironment &checkMetric &print_revision_short &processCommand);

#########################
##
##   CHANGEME: change software directories here!
##
#########################

# We should have /etc/java/java.conf with the location of java
sub find_java() {
    my $JAVA_CONF="/etc/java/java.conf";
    my $dir="";
    open(IN, "<$JAVA_CONF") || return "";
    while(<IN>) {
	next if /^\s*#/;
	if(/^\s*export\s*JAVA_HOME\s*=\s*([^\s]*)$/) {
	    $dir = $1;
	}
    }
    return $dir;
}

$GLOBUS_LOCATION = $ENV{GLOBUS_LOCATION} || "/usr";
$GLITE_LOCATION = $ENV{GLITE_LOCATION} || "/opt/glite";
$LCG_LOCATION = $ENV{LCG_LOCATION} || "/opt/lcg";
$EDG_LOCATION = $ENV{EDG_LOCATION} || "/opt/edg";
$VDT_LOCATION = $ENV{VDT_LOCATION} || "/opt";
$SRM_PATH = $ENV{SRM_PATH} || "/opt/d-cache/srm";
$JAVA_HOME = $ENV{JAVA_HOME} || find_java();
$GLOBUS_TCP_PORT_RANGE = $ENV{GLOBUS_TCP_PORT_RANGE} || "20000,25000";
my $HOME = $ENV{HOME} || '/var/log/nagios';

#########################
#########################

#########################
#########################

#########################
##
##   Global variables
##
#########################

%ERRORS=(OK=>0,
            WARNING=>1,
            CRITICAL=>2,
            UNKNOWN=>3,
            DEPENDENT=>4);

%ERRORS_REV=(0=>'OK',
            1=>'WARNING',
            2=>'CRITICAL',
            3=>'UNKNOWN');            

%OUTPUT_TYPES=( NAGIOS=>0,
                WLCG=>1,
                NAGIOS3=>2,
                NAGIOS_PASSIVE=>3);

$COMMANDS{GRID_PROXY_INFO} = "$GLOBUS_LOCATION/bin/grid-proxy-info";
$COMMANDS{GRID_PROXY_INIT} = "$GLOBUS_LOCATION/bin/grid-proxy-init";
$COMMANDS{VOMS_PROXY_INIT} = "$GLITE_LOCATION/bin/voms-proxy-init";
$COMMANDS{VOMS_PROXY_INFO} = "$GLITE_LOCATION/bin/voms-proxy-info";

$MAX_PLUGINOUTPUT_LENGTH = 332;

$TIMEOUT = 60;
$VONAME = undef;
$OUTPUT_TYPE = undef;
@METRICS = undef;

$SERVICEURI = undef;
$SERVICETYPE = undef;
$METRICNAME = undef;
my $PROBESPECVER = '0.91';

my $DEFAULT_COMMAND_FILE = "/var/log/nagios/rw/nagios.cmd";
$DEFAULT_NAGIOS_CFG = "/etc/nagios/nagios.cfg";

#########################
#########################
 
#########################
##
##   Change default output type here!
##
#########################
$OUTPUT_TYPE = $OUTPUT_TYPES{WLCG};

#########################
##
##   Set environment variables based on known variables
##
#########################

#$ENV{GLOBUS_LOCATION}=$GLOBUS_LOCATION;
#$ENV{GLITE_LOCATION}=$GLITE_LOCATION;
#$ENV{LCG_LOCATION}=$LCG_LOCATION;
#$ENV{EDG_LOCATION} = $EDG_LOCATION;
#$ENV{SRM_PATH}=$SRM_PATH;
#$ENV{JAVA_HOME}=$JAVA_HOME;
#$ENV{LD_LIBRARY_PATH}="$GLOBUS_LOCATION/lib:$GLITE_LOCATION/lib:$LCG_LOCATION/lib:$EDG_LOCATION/lib";
#$ENV{GLOBUS_TCP_PORT_RANGE}=$GLOBUS_TCP_PORT_RANGE;
#$ENV{PATH}="/usr/local/bin:/usr/bin:/bin:$GLOBUS_LOCATION/bin:$GLITE_LOCATION/bin:$JAVA_HOME/bin";
#$ENV{PYTHONPATH}="$GLITE_LOCATION/lib/python2.3/site-packages:$GLITE_LOCATION/lib/python:$GLITE_LOCATION/lib/python2.3/site-packages/amga:$LCG_LOCATION/lib/python:$LCG_LOCATION/lib/python2.3/site-packages";
#$ENV{HOME}=$HOME;
# Modifications to work on gLite 3.1 UI
#$ENV{PYTHONPATH}="$ENV{PYTHONPATH}:/opt/fpconst/lib/python2.3/site-packages:/opt/SOAPpy/lib/python2.3/site-packages";
#$ENV{LD_LIBRARY_PATH}="$ENV{LD_LIBRARY_PATH}:/opt/c-ares/lib:/opt/xerces-c/lib:/opt/log4cxx/lib:/opt/c-ares/lib:/opt/d-cache/dcap/lib";

#########################
#########################

#########################
##
##   Helper functions
##
#########################

sub checkCommands() {
    foreach my $command (values %COMMANDS) {
        checkCommand ($command);    
    }
    1;
}	

sub checkCommand ($) {
    my $command = shift;
    if (! -f $command) {
        printOutput ($ERRORS{UNKNOWN}, "Command $command doesn't exist.\n");
    }

    if (! -x $command) {
        printOutput ($ERRORS{UNKNOWN}, "Command $command is not executable.\n");
    }
    
    1;
}

sub checkEnvironment {
    foreach my $env (@_){
        unless ($ENV{$env}) {
            printOutput ($ERRORS{UNKNOWN}, "Environment variable $env must be set.\n");
        }
    }
    1;
}   

sub checkMetric
{
    my $metric = shift;
    my $retVal = 0;

    printOutput ($ERRORS{UNKNOWN}, "Metric must be defined. Supported metrics are: ".join(', ',@METRICS).".\n") unless ($metric);

    foreach my $m (@METRICS){
        if ($metric eq $m) {
            $retVal = 1;
            last;
        }
    }
   
    printOutput ($ERRORS{UNKNOWN}, "Unknown metric defined: $metric. Supported metrics are: ".join(', ',@METRICS).".\n") unless ($retVal);
    
    1;
}

sub checkHost {
    my $host = shift;

    if (defined $host) {
        if ($host !~ /^([-_.A-Za-z0-9]+\$?)$/) {
            printOutput ($ERRORS{UNKNOWN}, "Invalid host: $host.\n");
        }
    } else {
        printOutput ($ERRORS{UNKNOWN}, "Host must be defined.\n");
    }

    $host;
}

#########################
##
##   Grid proxy functions
##
#########################

sub checkProxy {
    my $proxy = shift;
    my $timeout = shift || "1:0";
    my $state;
    my $res;
    my $cmd;
    if (defined $proxy && -r $proxy) {
        $ENV{X509_USER_PROXY}=$proxy;
    }
    
    $cmd = $COMMANDS{GRID_PROXY_INFO} . " -e -valid $timeout 2>&1";

    ($state, $res) = processCommand ($cmd);

    if ($state == $ERRORS{CRITICAL}) {
        return ($ERRORS{UNKNOWN}, "Valid grid proxy doesn't exist.\n", $res);
    } elsif ($state == $ERRORS{UNKNOWN}) {
        return ($ERRORS{UNKNOWN}, "Error executing command for checking grid proxy.\n", $res);
    }

    if ($VONAME) {
        $cmd = $COMMANDS{VOMS_PROXY_INFO} . " -vo 2>&1";
        ($state, $res) = processCommand ($cmd);
        if ($state == $ERRORS{CRITICAL}) {
            return ($ERRORS{UNKNOWN}, "Error checking VOMS attributes.\n", $res);
        } elsif ($state == $ERRORS{UNKNOWN}) {
            return ($ERRORS{UNKNOWN}, "Error executing command for checking VOMS attributes.\n", $res);
        } else {
            unless ($res =~ /$VONAME/m) {
                return ($ERRORS{UNKNOWN}, "Proxy certificate doesn't have $VONAME VOMS attributes.\n", $res);
            }
        }
    }
    
    return ($ERRORS{OK}, "Grid proxy is valid.\n", $res);
}

sub createProxy {
    my $pass = shift;
    my $vo = shift;
    my $passwd = "";
    my $res;
    my $cmd;

    if ($vo) {
        $cmd = "$COMMANDS{VOMS_PROXY_INIT} -voms $vo -pwstdin";
    } else {
        $cmd = "$COMMANDS{GRID_PROXY_INIT} -pwstdin";
    }
    
    if ($pass) {
        $cmd = "/bin/cat $pass | $cmd 2>&1";
    } else {
        $cmd = "/bin/echo | $cmd 2>&1";
    }
    
    ($state, $res) = processCommand ($cmd);

    if ($state == $ERRORS{CRITICAL}) {
        return ($ERRORS{UNKNOWN}, "Valid grid proxy doesn't exist. Proxy creation failed.\n", $res);
    } elsif ($state == $ERRORS{UNKNOWN}) {
        return ($ERRORS{UNKNOWN}, "Error executing command for creating grid proxy.\n", $res);
    }

    $ERRORS{OK};
}

#########################
##
##   Output functions
##      (format output, print revision, etc)
##
#########################

sub print_revision ($$$) {
    my $plugin = shift;
    my $pluginRevision = shift;
    my $serviceVersion = shift;
    my $serviceT = $SERVICETYPE || '';
    my $probeV = $PROBESPECVER || '';
    print "$plugin\n";
    print "probeVersion: $pluginRevision\n";
    print "serviceType: $serviceT\n";
    print "serviceVersion: $serviceVersion\n";
    print "probeSpecificationVersion: $probeV\n\n";
    print "$plugin comes with ABSOLUTELY NO WARRANTY.
Licensed under the Apache License, Version 2.0 (the \"License\");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
   http://www.apache.org/licenses/LICENSE-2.0
";
}

sub print_revision_short ($$) {
    my $plugin = shift;
    my $pluginRevision = shift;
    print "$plugin $pluginRevision\n";
    print "$plugin comes with ABSOLUTELY NO WARRANTY.
Licensed under the Apache License, Version 2.0 (the \"License\");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
   http://www.apache.org/licenses/LICENSE-2.0
";
}


sub support() {
    print 'Send email to nagios-admin@srce.hr if you have questions
regarding use of this software or wish to submit patches or 
suggest improvements.
'; 
}

sub printOutput {
    my $status = shift;
    my $summary = shift;
    my $extra = shift;
    my $hostname = shift;
    
    if ($OUTPUT_TYPE == $OUTPUT_TYPES{NAGIOS}) {
        printNagiosOutput($status,$summary, $extra);
    } elsif ($OUTPUT_TYPE == $OUTPUT_TYPES{WLCG}) {
        printWLCGOutput($status,$summary,$extra);
    } elsif ($OUTPUT_TYPE == $OUTPUT_TYPES{NAGIOS3}) {
        printNagios3Output($status,$summary,$extra);
    } elsif ($OUTPUT_TYPE == $OUTPUT_TYPES{NAGIOS_PASSIVE}) {
        printNagiosPassive($status,$summary,$extra,$hostname);
    }
}

sub printNagiosOutput($$$) {
    my $status = shift;
    my $summary = shift;
    my $extra = shift;

    if ($extra) {
        $extra =~ s/\n//mg;
        # avoid printing the same output
        if ($summary !~ /$extra/) {
            $summary =~ s/\n//mg;
            my $sumLen = length ($summary) + 2;
            $summary .= " " . substr($extra, 0, $MAX_PLUGINOUTPUT_LENGTH - $sumLen) . "\n";
        }
    }

    print $summary;

    exit $status;
}

sub printNagios3Output($$$) {
    my $status = shift;
    my $summary = shift;
    my $extra = shift;

    print $summary;

    print $extra if ($extra);

    exit $status;
}


sub printNagiosPassive  {
    my $status = shift;
    my $summary = shift;
    my $extra = shift;
    my $hostname = shift || hostname();
    my $metName = $METRICNAME || "unknown";

    my $nagios = GridMon::Nagios::Passive->new();
    unless ($nagios->publishPassiveResult($hostname, $metName, $status, $summary)) {
        print "ERROR: publishing failed: $nagios->{ERROR}\n";
        exit 2;
    }
    alarm (0);

    print $summary;
    exit $status;
}

sub printWLCGOutput  {
    my $status = shift;
    my $summary = shift;
    my $extra = shift;
    my $hostname = hostname();
    my $serType = $SERVICETYPE || "unknown";
    my $metName = $METRICNAME || "unknown";
    my $statName = $ERRORS_REV{$status};

    print "serviceType: $serType\n";
    print "metricName: $metName\n";
    print "metricStatus: $statName\n";
    print "timestamp: ". time2str("%Y-%m-%dT%H:%M:%SZ",time(),'UTC') . "\n";
    print "summaryData: $summary";
    print "voName: $VONAME\n" if (defined $VONAME);
    if ($SERVICEURI) {
        print "serviceURI: $SERVICEURI\n";
        print "gatheredAt: $hostname\n";
    } else {
        print "hostName: $hostname\n";
    }
    if ($extra) {
        $extra =~ s/^\s*\n//mg;
        print "detailsData: $extra";
    }
    print "EOT\n";

    if ($status == $ERRORS{UNKNOWN}) {
        exit 1;
    } else {
        exit 0;
    }
}

sub printWLCGList  {
    foreach my $name (@METRICS) {
        print "serviceType: $SERVICETYPE\n";
        print "metricName: $name\n";
        print "metricType: status\n";
        print "EOT\n";
    }
}

sub processCommand {
    my $cmd = shift;
    my $sig = shift || TERM;
    my $pid;
    my $CMDFD;
    my $state;
    my $res;

    if (!($pid = open($CMDFD, "$cmd |"))) {
        $state = $ERRORS{UNKNOWN};
        $res = "Error executing command.\n";
    } else {
        eval {
           local $SIG{ALRM} = sub { die "COMMAND_EVAL_BLOCK_TIMEOUT"; };
           local $SIG{TERM} = sub { die "COMMAND_EVAL_BLOCK_TERM"; };
           $res = join ("", <$CMDFD>);
           close($CMDFD);
           if ($?) {
               $state = $ERRORS{CRITICAL};
           } else {
               $state = $ERRORS{OK};
           }
        };
        if ($@) {
            if ($@ =~ /COMMAND_EVAL_BLOCK_TIMEOUT/) {
                $state = $ERRORS{UNKNOWN};
                $res = "Timeout executing command.\n";
            } elsif ($@ =~ /COMMAND_EVAL_BLOCK_TERM/) {
                $state = $ERRORS{UNKNOWN};
                $res = "Plugin received TERM signal.\n";
            } else {
                $state = $ERRORS{UNKNOWN};
                $res = "Unknown error executing command: $@.\n";
            }
            kill $sig, $pid;
            sleep 1;
            kill KILL, $pid;
            close($CMDFD);
            $? ||= 9;
        }
    }

    return ($state, $res);
}

=head1 NAME

GridMon::sgutils

=head1 DESCRIPTION

The GridMon::sgutils module provides set of common functions used by
grid probes.

=head1 SYNOPSIS

$DEFAULT_NAGIOS_CFG $SERVICEURI $SERVICETYPE $METRICNAME $SRM_PATH $GLOBUS_TCP_PORT_RANGE $GLOBUS_LOCATION $EDG_LOCATION $LCG_LOCATION $GLITE_LOCATION $TIMEOUT $VONAME $OUTPUT_TYPE @METRICS %ERRORS %OUTPUT_TYPES %COMMANDS &print_revision &support &printOutput &checkCommands &checkCommand &checkProxy &createProxy &printWLCGList &checkHost &checkEnvironment &checkMetric &print_revision_short &processCommand);

  use GridMon::sgutils;

  my $javaDir = find_java();

  $COMMANDS{MY_PROXY_LOGON}  = "$GLOBUS_LOCATION/bin/myproxy-logon";
  checkCommands();
  
  checkEnvironment(@envVars);

  @METRICS = ("hr.srce.GridProxy-Get");
  checkMetric($metricName);

  checkHost($hostname);
  
  checkProxy($proxyFile, $lifetime);
  
  createProxy($pass, $vo);
  
  print_revision ($plugin, $pluginRevision, $serviceVersion);
  
  print_revision_short ($plugin, $pluginRevision);
  
  support();

  printOutput($status, $summary, $extra, $hostname);
  
  printWLCGList();
  
  processCommand($command, $signal);

=cut

=head1 METHODS

=over

=item C<find_java>

  my $javaDir = find_java();

Retrieves JAVA_HOME value from java.conf file.

=item C<checkCommands>

  $COMMANDS{MY_PROXY_LOGON}  = "$GLOBUS_LOCATION/bin/myproxy-logon";
  checkCommands();

Method checks if all executables listed in COMMANDS hash exist on the system.

=item C<checkCommand>

  checkCommands($cmd);

Method checks if executable $cmd exist on the system.

=item C<checkEnvironment>

  checkEnvironment(@envVars);

Method checks if env variables in array @envVars are defined.

=item C<checkMetric>

  checkMetric($metricName);

Method checks if metric name exists in array @METRICS.

=item C<checkMetric>

  checkMetric($metricName);

Method checks if metric name exists in array @METRICS.

=item C<checkHost>

  checkHost($hostName);

Method checks if $hostName is valid hostname.

=item C<checkProxy>

  checkProxy($proxyFile, $lifetime);

Method checks if valid proxy exists in file $proxyFile.

=item C<createProxy>

  checkProxy($proxyFile, $vo);

Method creates proxy file for a given VO and stores it into
defined location $proxyFile.

=item C<print_revision>

  print_revision ($plugin, $pluginRevision, $serviceVersion);

Method prints formatted version information.

=item C<print_revision_short>

  print_revision_short ($plugin, $pluginRevision);

Method prints shorter version of version information.

=item C<support>

  support();

Method prints short support information.

=item C<support>

  support();

Method prints short support information.

=item C<printOutput>

  printOutput($status, $summary, $extra, $hostname);

Method prints probe's output. Output is format is defined by the
$OUTPUT_TYPE. Supported types are:
  $OUTPUT_TYPES{NAGIOS} - result is reported in standard Nagios format
  $OUTPUT_TYPES{NAGIOS3} - result is reported in Nagios 3 format (multiline)
  $OUTPUT_TYPES{NAGIOS_PASSIVE} - result is reported as passive result
  $OUTPUT_TYPES{WLCG} - result is reported in WLCG format

=item C<printNagios3Output>

  printNagios3Output($status, $summary, $extra);

Internal method for reporting output in Nagios 3 format.

=item C<printNagiosPassive>

  printNagiosPassive($status, $summary, $extra, $hostname);

Internal method for reporting output as passive result.

=item C<printWLCGOutput>

  printWLCGOutput($status, $summary, $extra);

Internal method for reporting output in WLCG format.

=item C<printNagiosOutput>

  printNagiosOutput($status, $summary, $extra);

Internal method for reporting output in standard Nagios format.

=item C<printWLCGList>

  printWLCGList();

Method prints probe info in WLCG format.

=item C<processCommand>

  processCommand($command, $signal);
  
Method executes command cleanly, taking care of timeouts. 
Signal $signal is sent to the command prior to KILL.

=back

=cut

1;

