#!/usr/bin/perl -w
#
# Nagios configuration & status parser
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

package GridMon::Nagios::Passive;

use strict;
use Config::General;
use Nagios::NSCA::Client;
use GridMon::Nagios;
use vars qw(@ISA);

@ISA=("GridMon::Nagios");

my $SEND_NSCA_CONF_FILE="/etc/nagios/send_nsca.cfg";
my $PASSIVE_MODE_FILE="/etc/nagios-submit.conf";

sub new {
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my $self =  $class->SUPER::new(@_);

    $self;
}

sub publishPassiveResultString {
    my $self = shift;
    my $string = shift;
    
    unless ($string) {
        $self->setError("String for publishing must be defined!.");
        return 0;
    }

    unless ($self->{COMMAND_FILE}) {
        unless ($self->{COMMAND_FILE} = $self->_getCommandFile()) {
            return 0;
        }
    }

    unless(open (STD, ">>$self->{COMMAND_FILE}")) {
        $self->setError("Failed opening command file $self->{COMMAND_FILE}.");
        return 0;
    }

    print STD $string;

    close (STD);

    1;
}

sub getPassiveResultString {
    my $self = shift;
    my $attrs = shift;

    if (! $attrs->{timestamp}) {
        $attrs->{timestamp} = time();
    }

    foreach my $attr (('hostname', 'servicename', 'status', 'output' )) {
        if (! defined $attrs->{$attr}) {
            $self->setError("Missing attribute $attr.");
            return 0;
        }
    }

    return "[$attrs->{timestamp}] PROCESS_SERVICE_CHECK_RESULT;$attrs->{hostname};$attrs->{servicename};$attrs->{status};$attrs->{output}\n";
}

sub publishPassiveResult {
    my $self = shift;
    my $host = shift;
    my $service = shift;
    my $status = shift;
    my $output = shift;
    my $modeFile = shift || $PASSIVE_MODE_FILE;
    my $publishStr;

    # submit parameters are set only during first call of publishPassiveResult
    unless ($self->{SUBMIT_METHOD}) {
        if ( -f $modeFile ) {
            my %options = (-ConfigFile => $modeFile);
            my $config = new Config::General(%options);
            if (!$config) {
                $self->setError("Error parsing config file $modeFile.");
                return 0;
            }
            my %conf = $config->getall;

            # config file must have following option set:
            # SUBMIT_METHOD=nagioscmd|nsca
            if ($conf{SUBMIT_METHOD}) {
                if ( $conf{SUBMIT_METHOD} !~ /nsca|nagioscmd/ ) {
                    $self->setError("Unknown mechanism defined. Valid options are: nsca, nagioscmd.");
                    return 0;
                }
                $self->{SUBMIT_METHOD} = $conf{SUBMIT_METHOD};
            } else {
                $self->{SUBMIT_METHOD} = "nagioscmd";
            }

            # if SUBMIT_METHOD is nsca NSCA_HOST must be set
            # All relevant options are:
            # NSCA_HOST=...
            # NSCA_PORT=...
            # NSCA_CONFIG=...
            if ($self->{SUBMIT_METHOD} eq "nsca") {
                if ($conf{NSCA_HOST}) {
                    $self->{NSCA_HOST} = $conf{NSCA_HOST};
                    $self->{NSCA_PORT} = $conf{NSCA_PORT} || 5667;
                    $self->{NSCA_CONFIG} = $conf{NSCA_CONFIG} || $SEND_NSCA_CONF_FILE;
                } else {
                    $self->setError("NSCA hostname must be defined if mechanism is \"nsca\".");
                    return 0;
                }
            }
        } else {
            $self->{SUBMIT_METHOD} = "nagioscmd";
        }
    }

    my $message = {
        hostname => $host,
        servicename => $service,
        status => $status,
        output => $output,
    };

    if ($self->{SUBMIT_METHOD} eq "nagioscmd") {
        $publishStr = $self->getPassiveResultString($message);
        if (!$publishStr) {
            return 0;
        }
        if (! $self->publishPassiveResultString($publishStr)) {
            return 0;
        }
    } elsif ($self->{SUBMIT_METHOD} eq "nsca") {
        
        foreach my $attr (('hostname', 'servicename', 'status', 'output' )) {
            if (! defined $message->{$attr}) {
                $self->setError("Missing attribute $attr.");
                return 0;
            }
        }
        my $line = "$message->{hostname}\t$message->{servicename}\t$message->{status}\t$message->{output}";

        my $nsca = Nagios::NSCA::Client->new(argv => ['-H', $self->{NSCA_HOST}, '-p', $self->{NSCA_PORT}, '-c', $self->{NSCA_CONFIG}]);
        if (!$nsca) {
            $self->setError("Error creating NSCA perl client.");
            return 0;
        }

        # NSCA doesn't have alarm handler, instead it stays blocked
        # lets limit it to 5 seconds
        # These variables will be used to maintain previous alarms
        my $prevTimer;
        my $startTime;
        eval {
            local $SIG{ALRM} = sub { die "Error connecting to NSCA server." };
            $startTime = time();
            $prevTimer = alarm 5;
            $nsca->runServer() or die "Error connecting to NSCA server.";
            alarm 0;
        };
        $startTime = $prevTimer - (time() - $startTime);
        alarm $startTime if ($startTime>0);
        if ($@) {
            $self->setError($@);
            return 0;
        }

        my $packet = $nsca->filter->line2packet($line);
        if (!$packet) {
            $self->setError("Error creating NSCA packet from line: $line.");
            return 0;
        }
        if (!$nsca->server->sendPacket($packet)) {
            $self->setError("Error sending NSCA packet to server.");
            return 0;
        }
    }

    1;
}

=head1 NAME

GridMon::Nagios::Passive

=head1 DESCRIPTION

The GridMon::Nagios::Pasive module is a thin wrapper which enables
publishing results to Nagios as passive.

It relies on GridMon::Nagios for getting needed information from
main configuration file (nagios.cfg).

=head1 SYNOPSIS

  use GridMon::Nagios::Passive;

  my $nagios = GridMon::Nagios::Passive->new();

  $res = $nagios->publishPassiveResultString($string);

  $string = $nagios->getPassiveResultString($attrsHashRef);

  $string = $nagios->publishPassiveResult($host, $service,
                        $status, $output, $modeFile);

=cut

=head1 METHODS

=over

=item C<new>

  $nagios = GridMon::Nagios::Passive->new( );

Creates new GridMon::Nagios::Passive instance. At this point instance
doesn't contain any data. In order to fill it one of the fetch* methods
must be invoked.

=item C<publishPassiveResultString>

  $res = $nagios->publishPassiveResultString($string);

Method publishes string representing passive check result to Nagios.
Check Nagios documentation on valid passive result strings.

=item C<getPassiveResultString>

  $string = $nagios->getPassiveResultString($attrsHashRef);

Method creates passive service check string.

Arguments:
  $attrs - hash reference containing information about passive
  service check result; hash must contain the following keys:
    hostname, servicename, status, output

=item C<publishPassiveResult>

  $string = $nagios->publishPassiveResult($host, $service,
                        $status, $output, $modeFile);
                        
Method publishes passive service check result. 

It reads $modeFile to select which mechanism is used for publishing
result. Currently two modes are supported:
  nagioscmd - passive check is published directly to Nagios, 
              method must me executed on the Nagios host
  nsca - passive check is published via NSCA service
Mode is defined by SUBMIT_METHOD variable in file $modeFile.

In case when SUBMIT_METHOD is set to nsca, following options are
expected to be in $modeFile
  NSCA_HOST - hostname of NSCA server
            - this option is mandatory
  NSCA_PORT - port of NSCA server
            - default value is 5667
  NSCA_CONFIG - nsca sender configuration file which contains NSCA key and
                encryption method index
              - default value is /etc/nagios/send_nsca.cfg
              
Arguments are:
  $host - hostname to which service belongs
  $service - name of the service for which passive check is published
  $status - status of check result
  $output - output of check result
  $modeFile - file containing publish mechanism definition
            - default value is /etc/nagios-submit.conf
            - if file is not found nagioscmd publish mechanism is assumed

=back

=head1 SEE ALSO

GridMon::Nagios

=cut

1;

