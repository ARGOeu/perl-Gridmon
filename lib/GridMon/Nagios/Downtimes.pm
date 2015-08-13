#!/usr/bin/perl -w

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

package GridMon::Nagios::Downtimes;

use strict;
use GridMon::Nagios;
use vars qw(@ISA);

@ISA=("GridMon::Nagios");

sub new {
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my $self =  $class->SUPER::new(@_);

    # Nagios downtime ID => downtime hash (attr => value, e.g. end_time=1170230400)
    $self->{DOWNTIMES} = {};

    # GOCDB maintenance ID 
    #    => hostname => Nagios downtime ID
    #    => hostname => Nagios downtime ID
    # Single GOCDB downtime is mapped to multiple Nagios
    # downtimes (unless downtime is for a single node).
    $self->{MAINT} = {};
    $self->{ERROR} = "";
    $self;
}

sub fetchDowntimeData {
    my $self = shift;
    my $filter = shift || 1;
    my $downtime;
    my $type;

    unless ($self->{STATUS_FILE}) {
        unless ($self->{STATUS_FILE} = $self->_getStatusFile) {
    		return 0;
    	}
    }

    unless(open (STD, $self->{STATUS_FILE})) {
        $self->setError("Failed opening downtime file $self->{STATUS_FILE}.");
        return 0;
    }

    while (my $line = <STD>) {
        if ($line =~ /hostdowntime\s*\{/) {
            $downtime = {};
            $type = 1;
        } elsif ($type) {
            if ($line =~ /\s+\}/) {
                if ( !$filter || exists $downtime->{maintID}) {
                    $self->{DOWNTIMES}->{$downtime->{downtime_id}} = {%{$downtime}};
                    $self->{MAINT}->{$downtime->{maintID}}->{$downtime->{host_name}} = $downtime->{downtime_id};
                }
                $type = 0;
            } elsif ($line =~ /^\s+(\w+)=(\S.*?\S?)\s*$/) {
                my $attr = $1;
                my $value = $2;
                $downtime->{$attr}=$value;
                if ($attr=~/comment/ && $value=~/^(\d+)#.*/) {
                    $downtime->{maintID} = $1;
                }
            }
        }
    }

    close (STD);

    1;
}
		
sub getMaintHosts {
    my $self = shift;
    my $maintId = shift or return ();
    my @hosts = ();

    if (exists $self->{MAINT}->{$maintId}) {
        @hosts = keys %{$self->{MAINT}->{$maintId}};
    }

    @hosts;
}

sub getMaintHostDowntime {
    my $self = shift;
    my $maintId = shift or return;
    my $hostname = shift or return;
    my $retVal;

    if (exists $self->{MAINT}->{$maintId}) {
        if ($self->{MAINT}->{$maintId}->{$hostname}) {
            $retVal = $self->{DOWNTIMES}->{$self->{MAINT}->{$maintId}->{$hostname}};
        }
    }
    
    $retVal;
}

sub existsMaint {
    my $self = shift;
    my $maintId = shift or return;

    return exists $self->{MAINT}->{$maintId};
}

sub getMaints {
    my $self = shift;
    return keys %{$self->{MAINT}};
}

sub addDowntime {
    my $self = shift;
    my $attrs = shift;
    my $site = shift || 0;
    my $myTime = time();

    unless ($myTime) {
        $self->setError("Failed getting current time.");
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

    foreach my $attr (('hostname', 'start_time', 'end_time', 'author', 'maintID', 'comment' )) {
        if (!$attrs->{$attr}) {
            $self->setError("Missing attribute $attr.");
            return 0;
        }
    }

    if ($site) {
        print STD "[$myTime] SCHEDULE_HOSTGROUP_HOST_DOWNTIME;$attrs->{hostname};$attrs->{start_time};$attrs->{end_time};1;0;0;$attrs->{author};$attrs->{maintID}#$attrs->{comment}\n";
    } else {
        print STD "[$myTime] SCHEDULE_AND_PROPAGATE_HOST_DOWNTIME;$attrs->{hostname};$attrs->{start_time};$attrs->{end_time};1;0;0;$attrs->{author};$attrs->{maintID}#$attrs->{comment}\n";
    }

    close (STD);

    1;
}

sub removeDowntime {
    my $self = shift;
    my $downID = shift;
    my $myTime = time();

    return 1 unless (exists $self->{DOWNTIMES}->{$downID});

    unless ($self->{COMMAND_FILE}) {
        unless ($self->{COMMAND_FILE} = $self->_getCommandFile()) {
            return 0;
        }
    }

    unless(open (STD, ">>$self->{COMMAND_FILE}")) {
        $self->setError("Failed opening command file $self->{COMMAND_FILE}.");
        return 0;
    }

    print STD "[$myTime] DEL_HOST_DOWNTIME;$downID\n";
    close (STD);
	
    1;
}

sub removeDowntimeByMaint {
    my $self = shift;
    my $maintID = shift;
    my $myTime = time();
    my @downIds;

    return 1 if (! exists $self->{MAINT}->{$maintID});

    return 1 if (ref ($self->{MAINT}->{$maintID}) ne 'HASH');

    unless ($self->{COMMAND_FILE}) {
        unless ($self->{COMMAND_FILE} = $self->_getCommandFile()) {
            return 0;
        }
    }

    unless(open (STD, ">>$self->{COMMAND_FILE}")) {
        $self->setError("Failed opening command file $self->{COMMAND_FILE}.");
        return 0;
    }
    foreach my $id (values %{$self->{MAINT}->{$maintID}}) {
        print STD "[$myTime] DEL_HOST_DOWNTIME;$id\n";
    }
    close (STD);

    1;
}

=head1 NAME

GridMon::Nagios

=head1 DESCRIPTION

The GridMon::Nagios::Downtimes module is a thin wrapper around Nagios
which enables scheduling downtimes. 

Furthermore, module enables mapping downtimes to downtimes from the
external data source. In the methods these are called maintenances.
External downtimes can be associated to a host or a hostgroup. 
Identificator of external downtime is coded into the
downtime name, e.g.:
	26005353#Internet connection will be unavailable.

Module contains two hashes:
  MAINT - list of external downtime identifiers and mappings to Nagios 
          downtime IDs
  DOWNTIMES - list of Nagios downtimes

Object configuration files and status file paths are retrieved from
main configuration file (nagios.cfg).

=head1 SYNOPSIS

  use GridMon::Nagios::Downtimes;

  my $nagios =GridMon::Nagios::Downtimes->new();

  $nagios->fetchDowntimeData() or die $nagios->{ERROR};
  
  my @hosts = $nagios->getMaintHosts($id);

  my $nagiosId = $nagios->getMaintHostDowntime($maintId, $hostname);

  $nagios->existsMaint($maintId);
  
  my @maintIds = $nagios->getMaints();

  my $attr = {hostname=> ..., start_time=> ..., end_time=> ..., author=> ...,
              maintID=> ..., comment=>...};
  $nagios->addDowntime ($attrs);
  
  $nagios->removeDowntime($nagiosId);
  
  $nagios->removeDowntimeByMaint($maintId);

=cut

=head1 METHODS

=over

=item C<new>

  $nagios = GridMon::Nagios::Downtimes->new( );

Creates new GridMon::Nagios::Downtimes instance. At this point instance 
doesn't contain any data. In order to fill it one of the fetch* methods 
must be invoked.

=item C<fetchDowntimeData>

  $res = $nagios->fetchDowntimeData( );

Method parses Nagios object configuration files and retrieves
information about downtimes.

=item C<getMaintHosts>

  @hosts = $nagios->getMaintHosts( $maintId );

Method returns array of hosts affected by a given external downtime.

=item C<getMaintHostDowntime>

  $nagiosId = $nagios->getMaintHostDowntime( $maintId, $hostname );

Method returns Nagios downtime ID for a given external downtime and hostname.

=item C<existsMaint>

  $res = $nagios->existsMaint( $maintId );

Check if the defined external downtime exists.

=item C<getMaints>

  @maints = $nagios->getMaints( );

Retrieves list of external downtime identifiers.

=item C<addDowntime>

  $res = $nagios->addDowntime( $attrs );

Reports new downtime to Nagios. Attribute is hash ref with the following
elements:
  hostname - DNS name of the host in downtime
  start_time - start of downtime
  end_time - end of downtime
  author - person reporting the downtime
  maintID - identifier of external downtime
  comment - description of downtime

=item C<removeDowntime>

  $res = $nagios->removeDowntime( $nagiosId );

Removes downtime based on the Nagios downtime identifier.

=item C<removeDowntimeByMaint>

  $res = $nagios->removeDowntimeByMaint($maintId);

Removes downtime based on the external downtime identifier.

=back

=head1 SEE ALSO

GridMon::Nagios

=cut

1;
