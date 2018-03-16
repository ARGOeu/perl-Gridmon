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

use strict;

package GridMon::Nagios;

###############################################################################
use Exporter;    
our(@ISA, @EXPORT, @EXPORT_OK);   
@ISA = qw(Exporter);                   
@EXPORT = qw();                                     
@EXPORT_OK = qw(nagios_cmd nagios_debug);           

#use TOM::Error qw(error_report);  
use No::Worries::Die qw(dief handler);

#use TOM::Syslog qw(syslog_error syslog_debug);       
use No::Worries::Syslog qw(syslog_error syslog_debug);
#                                                  
# global variables
#
                                                                                                                                                             
our(                                                      
    $CommandPipe,               # path of the Nagios command pipe           
    $CommandTimeout,            # maximum time allowed to execute a command      
); 

$CommandPipe = "/var/nagios/rw/nagios.cmd";                                                
$CommandTimeout = 5;   

#                                                                                          
# send to the pipe a list of commands to be executed by Nagios                             
#                                                                                          
                                                                                           
sub nagios_cmd (@) {                                                                       
    my(@commands) = @_;                                                                    
    my($fh, $command);                                                                     
                                                                                           
    eval {                                                                                 
        local $SIG{ALRM} = sub { die("timeout\n") };                                       
        alarm($CommandTimeout);                                                            
        open($fh, ">", $CommandPipe)                                                       
            or die("cannot open($CommandPipe): $!");                                       
        foreach $command (@commands) {                                                     
            printf($fh "[%d] %s\n", time(), $command)                                      
                or die("cannot printf($CommandPipe): $!");                                 
        }                                                                                  
        close($fh)                                                                         
            or die("cannot close($CommandPipe): $!");                                      
        alarm(0);                                                                          
    };                                                                                     
    if ($@) {                                                                              
        alarm(0);                                                                          
        dief("cannot execute Nagios commands: %s", $@);                            
        return();                                                                          
    }                                                                                      
    return(1);                                                                             
}   

#                                                                                          
# (maybe) report a debug message                                                           
#                                                                                          
                                                                                           
sub nagios_debug ($@) {                                                                    
    my($format, @arguments) = @_;                                                          
                                                                                           
    return(0) unless $ENV{GRIDMON_NAGIOS_DEBUG};                                               
    return(syslog_debug($format, @arguments));                                             
}   
#####################################################################################

my $CONFFILE="/etc/nagios/nagios.cfg";

sub _addRecurseDirs {
    my $filelist = shift;
    my $path = shift;

    $path .= '/' if($path !~ /\/$/);

    foreach my $eachFile (glob($path.'*')) {
        if( -d $eachFile) {
            _addRecurseDirs ($filelist, $eachFile);
        } elsif ( -f $eachFile) {
            push @$filelist, $eachFile;
        }
    }
}

sub _getConfFiles {
    my $self = shift;
    my $filelist = [];
    my $confFile = $self->{MAIN_CONFIG};

    unless(open (STD, $confFile)) {
        $self->setError("Failed opening main config file $confFile.");
        return 0;
    }

    while (my $line = <STD>) {
        if ($line =~ /^cfg_file\s*=\s*(\S.*?\S?)\s*$/) {
            push @$filelist, $1;
        } elsif ($line =~ /^cfg_dir\s*=\s*(\S.*?\S?)\s*$/) {
            _addRecurseDirs $filelist, $1;
        }
    }
    close (STD);

    return $filelist;
}

sub _getStatusFile {
    my $self = shift;
    my $res;
    my $confFile = $self->{MAIN_CONFIG};

    unless(open (STD, $confFile)) {
        $self->setError("Failed opening main config file $confFile.");
        return 0;
    }

    while (my $line = <STD>) {
        if ($line =~ /^status_file\s*=\s*(\S.*?\S?)\s*$/) {
            $res = $1;
            last;
        }
    }

	return $res;
}

sub _getResourceFiles {
    my $self = shift;
    my $filelist = [];
    my $confFile = $self->{MAIN_CONFIG};

    unless(open (STD, $confFile)) {
        $self->setError("Failed opening main config file $confFile.");
        return 0;
    }

    while (my $line = <STD>) {
        if ($line =~ /^resource_file\s*=\s*(\S.*?\S?)\s*$/) {
            push @$filelist, $1;
        }
    }
    close (STD);

    return $filelist;
}

sub _getCommandFile {
    my $self = shift;
    my $res;
    my $confFile = $self->{MAIN_CONFIG};

    unless(open (STD, $confFile)) {
        $self->setError("Failed opening main config file $confFile.");
        return 0;
    }

    while (my $line = <STD>) {
        if ($line =~ /^command_file\s*=\s*(\S.*?\S?)\s*$/) {
            $res = $1;
            last;
        }
    }

    return $res;
}

sub setError($) {
	my $self = shift;
	my $answer = shift;

	$self->{ERROR} = "Nagios Parser ERROR: $answer\n";

	1;
}

sub clearError() {
	my $self = shift;
	$self->{ERROR} = "";
	1;
}

sub fetchConfHostData {
    my $self = shift;
    my $attrs = shift;
    my $silent = shift;
    my $attrsSearch;
    my $host;
    my $type;

    unless ($self->{CONF_FILES}) {
        unless ($self->{CONF_FILES} = $self->_getConfFiles) {
            return (undef, $self->{ERROR});
        }
    }

    if (@$attrs) {
        $attrsSearch = "(" . join (")|(" , @$attrs) . ")";
        ($attrsSearch =~ /host_name/) or $attrsSearch .= "|(host_name)";
    } else {
        $attrsSearch = "(host_name)";
    }

    foreach my $confFile (@{$self->{CONF_FILES}}) {
        unless(open (STD, $confFile)) {
            print STDERR "Failed opening config file $confFile. Let's try without it." unless ($silent);
            next;
        }

        while (my $line = <STD>) {
            if ($line =~ /define\s+host\s*\{/) {
                $host = {};
                $type = 1;
            } elsif ($type) {
                if ($line =~ /\s*\}/) {
                    if (exists $host->{host_name}) {
                        if (exists $self->{HOSTS}->{$host->{host_name}}) {
                            foreach my $key (keys %{$host}) {
                                $self->{HOSTS}->{$host->{host_name}}->{$key} = $host->{$key};
                            }
                        } else {
                            $self->{HOSTS}->{$host->{host_name}} = {%{$host}};
                        }
                    }
                    $type = 0;
                } elsif ( ( ! defined $attrsSearch || $line =~ /$attrsSearch/) && $line =~ /^\s*(\w+)\s+(\S.+?\S)(\s*;\s*\S.+?\S)?\s*$/) {
                    $host->{$1}=$2;
                }
            }
        }

        close (STD);
    }

    $self->{HOSTS_INTERNAL} = {%{$self->{HOSTS}}};

	1;
}

sub fetchConfServiceData {
    my $self = shift;
    my $attrs = shift;
    my $silent = shift;
    my $attrsSearch;
    my $service;
    my $type;

    unless ($self->{CONF_FILES}) {
        unless ($self->{CONF_FILES} = $self->_getConfFiles) {
    		return (undef, $self->{ERROR});
    	}
    }

    if (@$attrs) {
        $attrsSearch = "(" . join (")|(" , @$attrs) . ")";
        ($attrsSearch =~ /host_name/) or $attrsSearch .= "|(host_name)";
        ($attrsSearch =~ /service_description/) or $attrsSearch .= "|(service_description)";
    } else {
        $attrsSearch = "(host_name)|(service_description)";
    }

    foreach my $confFile (@{$self->{CONF_FILES}}) {
        unless(open (STD, $confFile)) {
            print STDERR "Failed opening config file $confFile. Let's try without it." unless ($silent);
            next;
        }
        while (my $line = <STD>) {
            if ($line =~ /define\s+service\s*\{/) {
                $service = {};
                $type = 1;
            } elsif ($type) {
                if ($line =~ /\s*\}/) {
                    if (exists $service->{service_description} && exists $service->{host_name}) {
                        $service->{service_name} = lc($service->{service_description});
                        $service->{service_name} =~ s/\s/_/g;
                        $self->{HOSTS}->{$service->{host_name}} = {} unless (exists $self->{HOSTS}->{$service->{host_name}});
                        $self->{HOSTS}->{$service->{host_name}}->{services} = {} unless (exists $self->{HOSTS}->{$service->{host_name}}->{services});

                        if (exists $self->{HOSTS}->{$service->{host_name}}->{services}->{$service->{service_name}}) {
                            foreach my $key (keys %{$service}) {
                                $self->{HOSTS}->{$service->{host_name}}->{services}->{$service->{service_name}}->{$key} = $service->{$key};
                            }
                        } else {
                            $self->{HOSTS}->{$service->{host_name}}->{services}->{$service->{service_name}} = {%{$service}};
                        }
                        $type = 0;
                    }
                } elsif ( ( ! defined $attrsSearch || $line =~ /$attrsSearch/) && $line =~ /^\s*(\w+)\s+(\S.+?\S)(\s*;\s*\S.+?\S)?\s*$/) {
                    $service->{$1}=$2;
                }
            }
        }

        close (STD);
    }

    $self->{HOSTS_INTERNAL} = {%{$self->{HOSTS}}};

    1;
}

sub fetchCommandData {
    my $self = shift;
    my $command_name = shift || "";
    my $silent = shift;
    my $service;
    my $type;
    
    unless ($self->{CONF_FILES}) {
        unless ($self->{CONF_FILES} = $self->_getConfFiles) {
    		return (undef, $self->{ERROR});
    	}
    }

    $self->{COMMANDS} = {};

    foreach my $confFile (@{$self->{CONF_FILES}}) {
        unless(open (STD, $confFile)) {
            print STDERR "Failed opening config file $confFile. Let's try without it." unless ($silent);
            next;
        }
        while (my $line = <STD>) {
            if ($line =~ /define\s+command\s*\{/) {
                $service = {};
                $type = 1;
            } elsif ($type) {
                if ($line =~ /\s*\}/) {
                    if ( exists $service->{command_name} ) {
                        if (!$command_name) {
                            $self->{COMMANDS}->{$service->{command_name}} = {%{$service}};
                        } elsif ($command_name eq $service->{command_name}) {
                            $self->{COMMANDS}->{$service->{command_name}} = {%{$service}};
                            last;
                        }
                    }
                    $type = 0;
                } elsif ($line =~ /^\s*(\w+)\s+(\S.+?\S)(\s*;\s*\S.+?\S)?\s*$/) {
                    $service->{$1}=$2;
                }
            }
        }

        close (STD);
    }

    1;
}

sub fetchResourceData {
    my $self = shift;
    my $silent = shift;

    unless ($self->{RESOURCE_FILES}) {
        unless ($self->{RESOURCE_FILES} = $self->_getResourceFiles) {
    		return 0;
    	}
    }

    $self->{RESOURCES} = {};

    foreach my $confFile (@{$self->{RESOURCE_FILES}}) {
        unless(open (STD, $confFile)) {
            print STDERR "Failed opening resource file $confFile. Let's try without it." unless ($silent);
            next;
        }
        while (my $line = <STD>) {
            if ($line =~ /^\s*(\$(USER\d+)\$)\s*=\s*(\S.+?\S)\s*$/) {
                $self->{RESOURCES}->{$2} = $3;
            }
        }

        close (STD);
    }

    1;
}

sub fetchStatusHostData {
    my $self = shift;
    my $attrs = shift;
    my $attrsSearch;
    my $host;
    my $type;

    unless ($self->{STATUS_FILE}) {
        unless ($self->{STATUS_FILE} = $self->_getStatusFile) {
            return 0;
        }
    }

    if (@$attrs) {
        $attrsSearch = "(" . join (")|(" , @$attrs) . ")";
        ($attrsSearch =~ /host_name/) or $attrsSearch .= "|(host_name)";
    } else {
        $attrsSearch = "(host_name)";
    }

    unless(open (STD, $self->{STATUS_FILE})) {
        $self->setError("Failed opening status file ".$self->{STATUS_FILE}.".");
        return 0;
    }

    while (my $line = <STD>) {
        if ($line =~ /host(status)?\s*\{/) {
            $host = {};
            $type = 1;
        } elsif ($type) {
            if ($line =~ /\s+\}/) {
                next unless ($host->{host_name});
                if (exists $self->{HOSTS}->{$host->{host_name}}) {
                    foreach my $key (keys %{$host}) {
                        $self->{HOSTS}->{$host->{host_name}}->{$key} = $host->{$key};
                    }
                } else {
                    $self->{HOSTS}->{$host->{host_name}} = {%{$host}};
                }
                $type = 0;
            } elsif (( ! defined $attrsSearch || $line =~ /$attrsSearch/) && $line =~ /^\s+(\w+)=(\S.*?\S?)\s*$/) {
                $host->{$1}=$2;
            }
        }
    }
    close (STD);

    $self->{HOSTS_INTERNAL} = {%{$self->{HOSTS}}};

    1;
}

sub fetchStatusServiceData {
    my $self = shift;
    my $attrs = shift;
    my $attrsSearch;
    my $service;
    my $type;

    unless ($self->{STATUS_FILE}) {
        unless ($self->{STATUS_FILE} = $self->_getStatusFile) {
            return 0;
        }
    }

    if (@$attrs) {
        $attrsSearch = "(" . join (")|(" , @$attrs) . ")";
        ($attrsSearch =~ /host_name/) or $attrsSearch .= "|(host_name)";
        ($attrsSearch =~ /service_description/) or $attrsSearch .= "|(service_description)";
    } else {
        $attrsSearch = "(host_name)|(service_description)";
    }

    unless(open (STD, $self->{STATUS_FILE})){
        $self->setError("Failed opening status file ".$self->{STATUS_FILE}.".");
        return 0;
    }

    while (my $line = <STD>) {
        if ($line =~ /service(status)?\s+\{/) {
            $service = {};
            $type = 1;
        } elsif ($type) {
            if ($line =~ /\s*\}/) {
                $service->{service_name} = lc($service->{service_description});
                $service->{service_name} =~ s/\s/_/g;

                $self->{HOSTS}->{$service->{host_name}} = {} unless (exists $self->{HOSTS}->{$service->{host_name}});
                $self->{HOSTS}->{$service->{host_name}}->{services} = {} unless (exists $self->{HOSTS}->{$service->{host_name}}->{services});

                if (exists $self->{HOSTS}->{$service->{host_name}}->{services}->{$service->{service_name}}) {
                    foreach my $key (keys %{$service}) {
                        $self->{HOSTS}->{$service->{host_name}}->{services}->{$service->{service_name}}->{$key} = $service->{$key};
                    }
                } else {
                    $self->{HOSTS}->{$service->{host_name}}->{services}->{$service->{service_name}} = {%{$service}};
                }
                $type = 0;
            } elsif (( ! defined $attrsSearch || $line =~ /$attrsSearch/) && $line =~ /^\s+(\w+)=(\S.*?\S?)\s*$/) {
                $service->{$1}=$2;
            }
        }
    }
    close (STD);

    $self->{HOSTS_INTERNAL} = {%{$self->{HOSTS}}};

    1;
}

sub filterHosts($) {
	my $self = shift;
	my $filter = shift;
	my $exact = shift;
	my @delete;

	$self->{FILTER} = 1;

	unless (%{$self->{HOSTS}}) {
		$self->setError("List of hosts must be populated first.");
		return 0;
	}

	foreach my $host ( values %{$self->{HOSTS}} ) {
		my $test = 0;

		foreach my $key ( keys %{$filter} ) {
			exists $host->{$key} or push @delete, $host->{host_name} and next;
			if ($exact) {
                unless ($host->{$key} eq $filter->{$key}) {
                    $test = 1;
                    last;
                }
            } elsif ($filter->{$key} =~ /^\-?\d+/) {
				unless ($host->{$key} == $filter->{$key}) {
					$test = 1;
					last;
				}
			} else {
				unless ($host->{$key} =~ /$filter->{$key}/) {
					$test = 1;
					last;
				}
			}
		}

		$test and push @delete, $host->{host_name};
	}

	foreach (@delete) {
		delete $self->{HOSTS}->{$_} if ($_);
	}

	1;
}

sub filterHostsByServiceAttrs($) {
	my $self = shift;
	my $filter = shift;
	my $exact = shift;
	my @delete;

	$self->{FILTER} = 1;

	unless (exists $filter->{service_description}) {
		$self->setError("Service filter must contain service_description.");
		return 0;
	}

	unless (%{$self->{HOSTS}}) {
		$self->setError("List of hosts must be populated first.");
		return 0;
	}

	foreach my $host ( values %{$self->{HOSTS}} ) {
		my $test = 0;

		exists $host->{services} or next;

		foreach my $service ( values %{$host->{services}} ) {
			if ($service->{service_description} =~ /$filter->{service_description}/) {
				foreach my $key ( keys %{$filter} ) {
					exists $service->{$key} or next;
					if ($exact) {
						unless ($service->{$key} eq $filter->{$key}) {
							$test = 1;
							last;
						}
                    } elsif ($filter->{$key} =~ /\d+/) {
						unless ($service->{$key} == $filter->{$key}) {
							$test = 1;
							last;
						}
					} else {
						unless ($service->{$key} =~ /$filter->{$key}/) {
							$test = 1;
							last;
						}
					}
				}
			}
			$test and last;
		}

		$test and push @delete, $host->{host_name};
	}

	foreach (@delete) {
		delete $self->{HOSTS}->{$_};
	}

	1;
}

sub filterHostsByService($) {
    my $self = shift;
    my $filter = shift;
    my @delete;

    $self->{FILTER} = 1;

    unless ($filter) {
        $self->setError("Service description must be defined.");
        return 0;
    }

    unless (%{$self->{HOSTS}}) {
        $self->setError("List of hosts must be populated first.");
        return 0;
    }

    foreach my $host ( values %{$self->{HOSTS}} ) {
        my $test = 0;

        if (!exists $host->{services}) {
            push @delete, $host->{host_name};
            next;
        }

        foreach my $service ( values %{$host->{services}} ) {
            if ($service->{service_description} =~ /$filter/) {
                $test = 1;
                last;
            }
        }

        push @delete, $host->{host_name} unless ($test);
    }

    foreach (@delete) {
        delete $self->{HOSTS}->{$_};
    }

    1;
}

sub prepareServiceCommand {
    my $self = shift;
    my $host = shift || return;
    my $service = shift || return;
    my $command;
    $service = lc($service);
    $service =~ s/\s/_/g;

    if (exists $self->{HOSTS}->{$host} &&
        exists $self->{HOSTS}->{$host}->{services}->{$service} &&
        exists $self->{HOSTS}->{$host}->{services}->{$service}->{check_command}) {
        $command = {};
        my $cmd = $self->{HOSTS}->{$host}->{services}->{$service}->{check_command};
        my @cmdArr = split(/\!/, $cmd);
        $command->{COMMAND} = shift @cmdArr;
        my $count = 1;
        foreach my $arg (@cmdArr) {
            $command->{ARGS}->{"ARG$count"} = $arg;
            $count++;
        }
        # TODO: Macros need to go to separate function
        #       These two are the most commonly used macros.
        $command->{MACROS}->{HOSTADDRESS} = $self->{HOSTS}->{$host}->{address};
        $command->{MACROS}->{HOSTNAME} = $self->{HOSTS}->{$host}->{host_name};
    } else {
        $self->setError("Host $host doesn't contain service $service.");
        return 0;
    }

    $command;
}

sub new {
	my $class = shift;
	my $nagiosMain = shift;
	my $self  = {};
    $self->{MAIN_CONFIG} = $nagiosMain || $CONFFILE;
	$self->{HOSTS} = {};
	$self->{HOSTS_INTERNAL} = {};
	$self->{COMMANDS} = {};
	$self->{RESOURCES} = {};
	$self->{FILTER} = 0;
	$self->{ERROR} = "";
	$self->{CONF_FILES} = undef;
	$self->{RESOURCE_FILES} = undef;
	$self->{STATUS_FILE} = "";
	bless ($self, $class);

	$self;
}

sub hosts {
	my $self = shift;
	return $self->{HOSTS};
}

sub clearFilter {
    my $self = shift;
    $self->{HOSTS} = {%{$self->{HOSTS_INTERNAL}}} if ($self->{FILTER});
    $self->{FILTER} = 0;
    return 1;
}


=head1 NAME

GridMon::Nagios

=head1 DESCRIPTION

The GridMon::Nagios module is a thin wrapper around Nagios configuration and
status. It enables fetching of host and service information. Furthermore,
it enables filtering entities based on:
 * host attributes (filterHosts)
 * services (filterHostsByService)
 * service attributes (filterHostsByServiceAttrs).

Object configuration files and status file paths are retrieved from
main configuration file (nagios.cfg). Module supports multiple object
configuration files and configuration directories (cfg_dir).

=head1 SYNOPSIS

  use GridMon::Nagios;

  my $nagios = GridMon::Nagios->new();

  my $confHostAttrs = ["hostgroups"];
  $nagios->fetchConfHostData($confHostAttrs) or die $nagios->{ERROR};

  my $statusHostAttrs = ["current_state","last_check"];
  $nagios->fetchStatusHostData($statusHostAttrs) or die $nagios->{ERROR};

  my $confServiceAttrs = ["servicegroups"];
  $nagios->fetchConfServiceData($confServiceAttrs) or die $nagios->{ERROR};

  my $statusServiceAttrs = ["current_state","plugin_output","last_check"];
  $nagios->fetchStatusServiceData($statusServiceAttrs) or die $nagios->{ERROR};

  my $hostFilter = {};
  $hostFilter->{current_state} = 0;
  $nagios->filterHosts($hostFilter) or die $nagios->{ERROR};

  $nagios->filterHostsByService("my_service") or die $nagios->{ERROR};

  my $serviceAttrFilter = {};
  $serviceAttrFilter->{service_description} = "my_service";
  $serviceAttrFilter->{current_state} = 0;
  $nagios->filterHostsByServiceAttrs($serviceFilter) or die $nagios->{ERROR};

  foreach my $host (keys %{$nagios->{HOSTS}}) {
      print "Found host: $host \n";

      # print all host attributes
      foreach my $hostKey (keys %{$nagios->{HOSTS}->{$host}}) {
          next if ($hostKey eq "services");
          print "  $hostKey: " . $nagios->{HOSTS}->{$host}->{$hostKey} . "\n";
      }

      # print all services and attributes on host
      my $hostServices = $nagios->{HOSTS}->{$host}->{services};
      foreach my $service (keys %$hostServices) {
          print "  service: $service \n";
          foreach my $serviceKey (keys %{$hostServices->{$service}}) {
              print "    $serviceKey: " . $hostServices->{$service}->{$serviceKey} . "\n";
          }
      }
  }

=cut

=head1 METHODS

=over

=item C<new>

  $nagios = GridMon::Nagios->new( );
  $nagios = GridMon::Nagios->new( $mainConfigFile );

Creates new GridMon::Nagios instance. At this point instance doesn't contain
any data. In order to fill it one of the fetch* methods must be invoked.

Argument defines location of main Nagios configuration file. If not
defined default value /etc/nagios/nagios.cfg is used. From the main
configuration following file paths are retrieved:
 * object configuration files (parameters cfg_file and cfg_dir)
 * status file (parameter status_file).

=item C<fetchConfHostData>

  $res = $nagios->fetchConfHostData( $AttrsArrayRef );

Method parses Nagios object configuration files and retrieves
information for all available hosts.

Argument is array reference with list of attributes which are
retrieved from object configuration file. If not defined all
attributes are retrieved. If the list doesn't contain host_name
it is automatically added.

Result is 1 if operation is successful, 0 otherwise. In case of
failure field ERROR is set to error string.

=item C<fetchStatusHostData>

  $res = $nagios->fetchStatusHostData( $AttrsArrayRef );

Method parses Nagios status files and retrieves information
for all available hosts.

Argument is array reference with list of attributes which are
retrieved from object configuration file. If not defined all
attributes are retrieved. If the list doesn't contain host_name
it is automatically added.

Result is 1 if operation is successful, 0 otherwise. In case of
failure field ERROR is set to error string.

=item C<fetchConfServiceData>

  $res = $nagios->fetchConfServiceData( $AttrsArrayRef );

Method parses Nagios object configuration files and retrieves
information for all available services.

Argument is array reference with list of attributes which are
retrieved from object configuration file. If not defined all
attributes are retrieved. If the list doesn't contain host_name
or service_description they're automatically added.

Result is 1 if operation is successful, 0 otherwise. In case of
failure field ERROR is set to error string.

=item C<fetchStatusServiceData>

  $res = $nagios->fetchStatusServiceData( $AttrsArrayRef );

Method parses Nagios status files and retrieves information
for all available services.

Argument is array reference with list of attributes which are
retrieved from object configuration file. If not defined all
attributes are retrieved. If the list doesn't contain host_name
or service_description they're automatically added.

Result is 1 if operation is successful, 0 otherwise. In case of
failure field ERROR is set to error string.

=item C<fetchCommandData>

  $res = $nagios->fetchCommandData( $commandName );

Method parses Nagios config files and retrieves information
for a single command or all available commands.

Argument is name of command which information will be fetched.

Result is 1 if operation is successful, 0 otherwise. In case of
failure field ERROR is set to error string.

=item C<fetchResourceData>

  $res = $nagios->fetchResourceData();

Method parses Nagios resource files and retrieves information
for all configuration variables.

Result is 1 if operation is successful, 0 otherwise. In case of
failure field ERROR is set to error string.

=item C<filterHosts>

  $res = $nagios->filterHosts( $FilterHashRef );

Filters hosts based on set of attribute requirements. In case
of string filter, method checks occurrence of the string. In
case of numeric filter, method checks for the exact value.

Argument is hash reference with list of pairs
 attribute_name => attribute_filter
Argument must be defined.

Result is 1 if operation is successful, 0 otherwise. In case of
failure field ERROR is set to error string.

=item C<filterHostsByService>

  $res = $nagios->filterHostsByService( $serviceDescription );

Filters hosts which contain defined service_description.

Argument is service description which is used for filtering.
Argument must be defined.

Result is 1 if operation is successful, 0 otherwise. In case of
failure field ERROR is set to error string.

=item C<filterHostsByServiceAttrs>

  $res = $nagios->filterHostsByServiceAttrs( $FilterHashRef );

Filters hosts based on set of service attributes. In case
of string filter, method checks occurrence of the string. In
case of numeric filter, method checks for the exact value.

WARNING: if the host doesn't contain defined service_description
it will not be filtered out. Used method filterHostsByService
first in order to exclude hosts which don't contain defined service.

Argument is hash reference with list of pairs
 attribute_name => attribute_filter
If the service_description is not in the list, method will
return error.  Argument must be defined.

Result is 1 if operation is successful, 0 otherwise. In case of
failure field ERROR is set to error string.

=item C<hosts>

  $res = $nagios->hosts();
  
Method returns hash containing hosts.

=item C<prepareServiceCommand>

  $res = $nagios->prepareServiceCommand( $hostname, $service );

Parses service command and generates hash with following
fields:
  COMMAND - name of command object
  ARGS - hash reference with all arguments
  MACROS - hash reference with macros.

ARGS hash reference has following structure:
  ARGN => ARG_VALUE

MACROS is formed in following way:
  MACRO_NAME => MACRO_VALUE
It contains two most commonly used macros:
  HOSTNAME - host's attribute host_name
  HOSTADDRESS - host's attribute address

Arguments are:
  $hostname - name of the host which contain service
  $service - name of the service on defined host
Bost arguments are mandatory.

Result is hash if operation is successful, undef otherwise.
In case of failure field ERROR is set to error string.

=item C<clearFilter>

  $res = $nagios->clearFilter();

Method clears current filtering and restores initial hosts and 
services information.

=item C<setError>

  $res = $nagios->setError($errString);

Method sets filed ERROR which contains error raised by the last failed 
operation.

=item C<clearError>

  $res = $nagios->clearError();

Method clears field ERROR.

=back

=head1 FUNCTIONS 

=over

=item nagios_cmd(COMMAND...)

send the given commands to Nagios using its command pipe

=item nagios_debug(MESSAGE)

report a sanitized debugging message to syslog via syslog_debug(),
if GRIDMON_NAGIOS_DEBUG is true

=back

=cut

1;

