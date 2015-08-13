#!/usr/bin/perl -w
#
# Nagios configuration generator (WLCG probe based)
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

package GridMon::ConfigCache;

use DBI;
use Date::Parse;

my $DEFAULT_CACHE_FILE = "/var/cache/msg/config-cache/config.db";

sub new {
	my $class = shift;
	my $opts = shift;
	$opts ||= { };
	$class = ref($class) || $class;
	my $self = $opts;
	bless($self, $class);
    unless ($self->{CACHE_FILE}) {
        $self->{CACHE_FILE} = $DEFAULT_CACHE_FILE;
    }
    unless ($self->{CACHE_TABLE}) {
        $self->{CACHE_TABLE} = 'config_incoming';
    }
    $self->{DBH} = DBI->connect("dbi:SQLite:dbname=".$self->{CACHE_FILE},"","", {PrintError => 0});
    if ($DBI::errstr) {
        undef $self;
        print "Could not connect to database: $DBI::errstr ($DBI::err)\n";
    }
    $self;
}

# 0 - failure
# 1 - table exists
# 2 - table didn't exist and it is created successfully
sub _checkTable {
    my $self = shift;
    my $res = 1;

    my $row_ary  = $self->{DBH}->selectrow_array("SELECT count(*) FROM sqlite_master WHERE name='$self->{CACHE_TABLE}'");
    if ($DBI::errstr) {
        return (0, "Error checking if table $self->{CACHE_TABLE} exists: $DBI::errstr");
    }

    unless($row_ary) {
        $self->{DBH}->do("CREATE TABLE $self->{CACHE_TABLE}(sitename TEXT, hostname TEXT, role TEXT, timestamp TEXT, processed TEXT, config BLOB)");
        if ($DBI::errstr) {
            return (0, "Error creating table $self->{CACHE_TABLE}: $DBI::errstr");
        }
        $res = 2;
    }

    $res;
}

sub clear {
    my $self = shift;
    my $res = 1;
    my $output;
    
    ($res, $output) = $self->_checkTable();

    if (!$res) {
        return ($res, $output);
    } elsif ( $res == 1 ) {
        $self->{DBH}->do("DELETE FROM $self->{CACHE_TABLE}");
        if ($DBI::errstr) {
            return (0, "Error clearing table $self->{CACHE_TABLE}: $DBI::errstr");
        }
        $res = 2;
    }

    $res;
}


# 0 - failure
# 1 - entry exists and it wasn't updated
# 2 - entry is updated
sub put {
    my $self = shift;
    my $attrs = shift or return (0, "Attrs hash must be defined");
    my $found = 0;
    my $res = 1;
    my $output;
    
    foreach my $attr (('sitename', 'hostname', 'timestamp', 'role', 'config' )) {
        if (! defined $attrs->{$attr}) {
            return (0, "Missing attribute $attr.");
        }
    }

    ($res, $output) = $self->_checkTable();

    if (!$res) {
        return ($res, $output);
    } elsif ( $res == 1 ) {

        my $arrRef = $self->{DBH}->selectall_arrayref( "SELECT timestamp FROM $self->{CACHE_TABLE} WHERE sitename='$attrs->{sitename}' AND hostname='$attrs->{hostname}'", { Slice => {} } );
        if ($DBI::errstr) {
            return (0, "Error getting timestamp for $attrs->{sitename}, $attrs->{hostname} from $self->{CACHE_TABLE}: $DBI::errstr");
        }
    
        if (ref $arrRef eq "ARRAY") {
            foreach my $tuple (@$arrRef) {
                $found = 1;
                my $newTime = str2time($attrs->{timestamp}) or return (0, "Incorrect input timestamp: $attrs->{timestamp}");
                my $oldTime = str2time($tuple->{timestamp}) or return (0, "Incorrect timestamp in the DB: $tuple->{timestamp}");
    
                # we've got a new config, update it
                if ($newTime > $oldTime) {
                    $res = 2;
                    $self->{DBH}->do("UPDATE $self->{CACHE_TABLE} SET config='$attrs->{config}', timestamp='$attrs->{timestamp}' WHERE sitename='$attrs->{sitename}' AND hostname='$attrs->{hostname}'");
                    if ($DBI::errstr) {
                        return (0, "Error updating config and timestamp for $attrs->{sitename}, $attrs->{hostname} in $self->{CACHE_TABLE}: $DBI::errstr");
                    }
                }
           }
        }
    }

    # we've got a completely new thing
    unless($found) {
        $res = 2;
        $self->{DBH}->do("INSERT INTO $self->{CACHE_TABLE}(sitename, hostname, role, timestamp, config) VALUES('$attrs->{sitename}', '$attrs->{hostname}','$attrs->{role}','$attrs->{timestamp}','$attrs->{config}')");
        if ($DBI::errstr) {
            return (0, "Error inserting new config for $attrs->{sitename}, $attrs->{hostname} in $self->{CACHE_TABLE}: $DBI::errstr");
        }
    }
    
    return $res;
}

sub getAll {
    my $self = shift;
    my $sitename = shift || "";
    my $hostname = shift || "";
    my $whereQuery = "";
    if ($sitename) {
        $whereQuery = "sitename='$sitename'";
    }
    if ($hostname) {
        if ($whereQuery) {
            $whereQuery .= " AND hostname='$hostname'";
        } else {
            $whereQuery = "hostname='$hostname'";
        }
    }
    if ($whereQuery) {
        $whereQuery = " WHERE $whereQuery";
    }
    
    my ($res, $output) = $self->_checkTable();

    if (!$res) {
        return ($res, $output);
    } elsif ( $res == 1 ) {
        my $arrRef = $self->{DBH}->selectall_arrayref( "SELECT * FROM $self->{CACHE_TABLE} $whereQuery", { Slice => {} } );
        if ($DBI::errstr) {
            return (0, "Error getting data from $self->{CACHE_TABLE}: $DBI::errstr");
        }
        return (1, $arrRef);
    } elsif ( $res == 2 ) {
        return (1, []);
    }
}

sub getUpdatedCount {
    my $self = shift;

    my ($res, $output) = $self->_checkTable();

    if (!$res) {
        return ($res, $output);
    } elsif ( $res == 1 ) {
        my $row_ary  = $self->{DBH}->selectrow_array("SELECT count(*) FROM $self->{CACHE_TABLE} WHERE processed <> timestamp or processed is null");
        if ($DBI::errstr) {
            return (0, "Error getting data from $self->{CACHE_TABLE}: $DBI::errstr");
        }
        return (1, $row_ary);
    } elsif ( $res == 2 ) {
        return (1, 0);
    }
}

sub getUpdated {
    my $self = shift;

    my ($res, $output) = $self->_checkTable();

    if (!$res) {
        return ($res, $output);
    } elsif ( $res == 1 ) {
        my $arrRef = $self->{DBH}->selectall_arrayref( "SELECT * FROM $self->{CACHE_TABLE} WHERE processed <> timestamp or processed is null", { Slice => {} } );
        if ($DBI::errstr) {
            return (0, "Error getting data from $self->{CACHE_TABLE}: $DBI::errstr");
        }
        return (1, $arrRef);
    } elsif ( $res == 2 ) {
        return (1, []);
    }
}

sub updateProcessed {
    my $self = shift;
    my $sitename = shift;
    my $hostname = shift;
    if ($sitename && $hostname) {
        $hostname = " WHERE sitename='$sitename' AND hostname='$hostname'";
    }

    my ($res, $output) = $self->_checkTable();

    if (!$res) {
        return ($res, $output);
    } elsif ( $res == 1 ) {
        $self->{DBH}->do("UPDATE $self->{CACHE_TABLE} SET processed=timestamp $hostname");
        if ($DBI::errstr) {
            return (0, "Error updating data in $self->{CACHE_TABLE}: $DBI::errstr");
        }
    }
    1;
}

=head1 NAME

GridMon::ConfigCache

=head1 DESCRIPTION

GridMon::ConfigCache module stores Nagios configurations in SQLite-based
cache. Table for storing data consists of following fields:
  sitename - name of the site
  hostname - host which published Nagios configuration
  role - role of Nagios instance
  timestamp - time when the config was published
  processed - time when the relevant entity processed config
  config - JSON blob containing Nagios configuration
  
Regarding the field "processed" relevant entities are following:
  NCG - processes configuration coming from the external instances
  sendToMsg - publishes configuration generated by local Nagios instance

Table schema is following:
  CREATE TABLE config_name (
    sitename TEXT,
    hostname TEXT,
    role TEXT, 
    timestamp TEXT,
    processed TEXT,
    config BLOB)

=head1 SYNOPSIS

  use GridMon::ConfigCache;

  my $lms = GridMon::ConfigCache->new( { CACHE_FILE => '/var/alternative/path/config.db',
                                         CACHE_TABLE => 'config_incoming' } );

  ($retVal, $errMsg) = $lms->put( { sitename => 'sitename',
                                    hostname => 'my.host',
                                    role => 'roc',
                                    timestamp => '2009-05-20T11:10:15Z',
                                    config => '...'});

  ($retVal, $arrRef) = $lms->getAll();
  if (ref $arrRef eq "ARRAY") {
      foreach my $tuple (@$arrRef) {
          print "$tuple->{hostname}, $tuple->{role}, $tuple->{timestamp}, $tuple->{config}\n";
      }
  }

=cut

=head1 METHODS

=over

=item C<new>

  $lms = GridMon::ConfigCache->new( $options );

Creates new GridMon::ConfigCache instance. Argument $options
is hash reference that can contain following elements:
  CACHE_FILE - file where SQLite database is stored.
  CACHE_TABLE - table in which cache is stored.
  
=item C<clear>

  $lms = $lms->clear();

Clears cache table. Used by NCG prior to filling cache with new 
site configs.

=item C<put>

Method puts new or updates existing config entry.

  ($retVal, $errMsg) = $lms->put( { sitename => 'sitename',
                                    hostname => 'my.host',
                                    role => 'roc',
                                    timestamp => '2009-05-20T11:10:15Z',
                                    config => '...'});

=item C<getAll>

Method returns all configurations in cache.

  ($retVal, $arrRef) = $lms->getAll();

=item C<getUpdated>

Method returns updated configurations in cache.

  ($retVal, $arrRef) = $lms->getUpdated();

=item C<getUpdatedCount>

Method returns number of configurations in cache which have been updated.

  ($retVal, $count) = $lms->getUpdatedCount();

=item C<updateProcessed>

Method updates all processed configuration. This is achieved by 
setting processed field to timestamp.

=item C<_checkTable>

Internal method used for checking if table exists in database.
If it doesn't it will create it.

  ($retVal, $errMsg) = $lms->_checkTable();

=back

=head1 SEE ALSO

GridMon::MsgCache;

=cut


1;
