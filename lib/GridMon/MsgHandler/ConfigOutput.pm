#
# MsgHandler for configs
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

package GridMon::MsgHandler::ConfigOutput;

use strict;
use warnings;
use GridMon::ConfigCache;
use GridMon::MsgHandler;
use JSON;

#use TOM::Error qw(error_report);
use No::Worries::Die qw(dief handler);

#use TOM::File qw(file_read);
use No::Worries::File qw(file_read);

our(@ISA) = qw(GridMon::MsgHandler);

sub new : method {
    my($class, @data) = @_;
    my($self);

    $self = $class->SUPER::new(@data);
    $self->{CACHE} ||= GridMon::ConfigCache->new({
	CACHE_FILE  => $self->{CACHE_FILE},
	CACHE_TABLE => $self->{CACHE_TABLE},
    });
    $self->{FILTER} = $self->_parseFilter($self->{FILTER_FILE});
    return($self);
}

sub _parseFilter : method {
    my($self, $path) = @_;
    my($line, $code, $sub);

    return() unless defined($path);
    $code = "";
    $code .= "sub {\n";
    $code .= "    my(\$roc, \$role, \$host) = \@_;\n";
    $code .= "    \$roc  = defined(\$roc)  ? lc(\$roc)  : '';\n";
    $code .= "    \$role = defined(\$role) ? lc(\$role) : '';\n";
    $code .= "    \$host = defined(\$host) ? lc(\$host) : '';\n";
    foreach $line (split(/\n/, file_read($path))) {
	next if $line =~ /^\s*$/ or $line =~ /^\s*\#/;
	unless ($line =~ /^\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\s*$/) {
#	    error_report("unexpected line in %s: %s", $path, $line);
	    dief("unexpected line in %s: %s", $path, $line);
	    return();
	}
	$code .= "    return(1) if ";
	$code .= "\$roc  eq '\L$1\E' and " unless $1 eq "*";
	$code .= "\$role eq '\L$2\E' and " unless $2 eq "*";
	$code .= "\$host eq '\L$3\E' and " unless $3 eq "*";
	$code .= "1;\n";
    }
    $code .= "    return(0);\n";
    $code .= "}\n";
    #print($code);
    $sub = eval($code);
    if ($@) {
#	error_report("filter compilation failed: %s", $@);
	dieff("filter compilation failed: %s", $@);
	return();
    }
    return($sub);
}

sub _parseConfigOutput ($$) {
    my($body, $attrs) = @_;
    my($ref);
    
    eval {
        $ref = from_json($body);
    };
    return(0, "Received message is not valid JSON object: $@") if $@;
    return(0, "Received empty object") unless $ref and ref($ref) eq "HASH";

    $attrs->{sitename} = $ref->{sitename};
    $attrs->{hostname} = $ref->{gatheredAt};
    $attrs->{timestamp} = $ref->{timestamp};
    $attrs->{role} = $ref->{role};
    $attrs->{config} = $body;
    return(1);
}

sub _filter : method {
    my($self, $headers) = @_;

    return(1) unless $self->{FILTER};
    return($self->{FILTER}->($headers->{ROC}, $headers->{role}, $headers->{nagios_host}));
}

sub handle : method {
    my($self, $headers, $body) = @_;
    my($result, $reason, $attrs);

    if ($self->_filter($headers)) {
        $attrs = {};
        ($result, $reason) = _parseConfigOutput($body, $attrs);
        return($self->warning($reason)) unless $result;
        ($result, $reason) = $self->{CACHE}->put($attrs);
        return($self->warning($reason)) unless $result;
        $self->debug(1, "Accepting config");
    } else {
        $self->debug(1, "Rejecting config");
    }

    return($self->success());
}

=head1 NAME

GridMon::MsgHandler::ConfigOutput

=head1 DESCRIPTION

The GridMon::MsgHandler::ConfigOutput is msg-to-handler adapter which handles
messages containing config of other Nagios instance. Messages are parsed and
inserted to SQLite based config cache. Access to cache is achieved via
module GridMon::ConfigCache.

=head1 SYNOPSIS

  use GridMon::MsgHandler::ConfigOutput;

  my $lms = GridMon::MsgHandler::ConfigOutput->new( {   CACHE_FILE => '/var/alternative/path/config.db',
                                                        CACHE_TABLE => 'config_outgoing' } );

=cut

=head1 METHODS

=over

=item C<new>

  $lms = GridMon::MsgHandler::ConfigOutput->new( $options );

Creates new GridMon::MsgHandler::ConfigOutput instance. Argument $options
is hash reference that can contain following elements:
  CACHE - instance of GridMon::ConfigCache class
          which is used for storing config
  CACHE_FILE - file where cache is stored. This option is forwarded to
               GridMon::ConfigCache module.
  CACHE_TABLE - table in which cache is stored.This option is forwarded to
                GridMon::ConfigCache module.

=item C<handle>

Method implementing the message handling.

=back

=head1 SEE ALSO

GridMon::ConfigCache;

=cut

1;
