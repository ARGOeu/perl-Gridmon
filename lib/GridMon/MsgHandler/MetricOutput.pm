#
# MsgHandler for metrics
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

package GridMon::MsgHandler::MetricOutput;

use strict;
use warnings;
use Crypt::SMIME;
use Date::Parse;
use GridMon::MsgHandler;
use GridMon::Nagios::Passive;
use GridMon::sgutils qw(%ERRORS);
use Messaging::Message;
use Messaging::Message::Queue;
#use TOM::File qw(file_read);
use No::Worries::File qw(file_read);

use constant DEFAULT_CACHE_DIR => "/var/spool/msg-nagios-bridge/incoming";
use constant DEFAULT_X509_KEY  => "/etc/nagios/globus/hostkey.pem";
use constant DEFAULT_X509_CERT => "/etc/nagios/globus/hostcert.pem";

our(@ISA) = qw(GridMon::MsgHandler);

sub new : method {
    my($class, @data) = @_;
    my($self);

    $self = $class->SUPER::new(@data);
    $self->{NAGIOS}    ||= GridMon::Nagios::Passive->new();
    $self->{CACHE_DIR} ||= DEFAULT_CACHE_DIR;
    $self->{CACHE}     ||= Messaging::Message::Queue->new(type=> 'DQS', path => $self->{CACHE_DIR});
    $self->{SOURCE}    ||= "local";
    $self->{X509_KEY}  ||= DEFAULT_X509_KEY;
    $self->{X509_CERT} ||= DEFAULT_X509_CERT;
    return($self);
}

sub _decryptMessage : method {
    my($self, $body, $attrs) = @_;
    my($smime, $key, $crt, $rsa, $plaintext);

    $smime = Crypt::SMIME->new();
    $body =~ s/\\n/\n/g;
    $key = file_read($self->{X509_KEY}, binmode => "binary");
    $crt = file_read($self->{X509_CERT}, binmode => "binary");
    $smime->setPrivateKey($key, $crt);

    eval {
        $plaintext = $smime->decrypt($body);
    };
    return(0, "Failed decrypting the message: $@") if $@;

    if ($plaintext =~ s/^\s*(\d+)\s*\n//) {
        $attrs->{status} = $1;
    }
    $plaintext =~ s/\n$//;
    $plaintext =~ s/\n/\\n/sg;
    $attrs->{output} =~ s/OK$//sg;
    $attrs->{output} .= $plaintext;

    return(1);
}

sub _parseMetricOutput : method {
    my($self, $body, $attrs) = @_;

    if ($body =~ /serviceURI: (\w+:\/\/)?([-_.A-Za-z0-9]+)(:\d+)?/) {
        $attrs->{hostname} = $2;
    } elsif ($body =~ /hostName: (\S.*\S)/) {
        $attrs->{hostname} = $1;
    }
    if ($body =~ /nagiosName: (\S.*\S)/) {
        $attrs->{servicename} = $1;
    } elsif ($body =~ /metricName: (\S.*\S)/) {
        $attrs->{servicename} = $1;
    }
    if ($body =~ /metricStatus: (\w+)/) {
        $attrs->{status} = $ERRORS{$1};
    }
    if ($body =~ /timestamp: (\S+)/) {
        $attrs->{timestamp} = str2time($1,"GMT");
    }
    if ($body =~ /summaryData: (\S.*\S)/) {
        $attrs->{output} = $1;
    }
    if ($body =~ /gatheredAt: (\S.*\S)/) {
        my $output = $attrs->{output} || "";
        $attrs->{output} = $1 . ": " . $output;
    }

    if ($body =~ /encrypted: yes/) {
        if ($body =~ /detailsData: (.*)EOT/s) {
            my ($retVal, $errMsg) = $self->_decryptMessage($1, $attrs);
            if (!$retVal) {
                return($retVal, $errMsg);
            }
        }
    } else {
        if ($body =~ /detailsData: (.*)EOT/s) {
            my $details = $1;
            $details =~ s/\n$//;
            $details =~ s/\n/\\n/sg;
            if ($details) {
                $attrs->{output} .= '\\\n' . $details;
            }
        }
    }

    if ($self->{SOURCE} =~ /remote/) {
        if ($body =~ /role: (\S.*\S)/) {
            $attrs->{servicename} .= "-$1";
        }
    }

    1;
}

sub handle : method {
    my($self, $headers, $body) = @_;
    my($result, $reason, $attrs, $msg);

    $attrs = {};
    ($result, $reason) = $self->_parseMetricOutput($body, $attrs);
    return($self->warning($reason)) unless $result;
    $msg = $self->{NAGIOS}->getPassiveResultString($attrs);
    return($self->warning("Got error creating Nagios passive result: $self->{NAGIOS}->{ERROR}."))
	unless $msg;
    $self->debug(1, "Storing Nagios passive result: %s", $msg);
    $self->{CACHE}->add_message(Messaging::Message->new(body => $msg));
    return($self->success());
}

=head1 NAME

GridMon::MsgHandler::MetricOutput

=head1 DESCRIPTION

The GridMon::MsgHandler::MetricOutput is msg-to-handler adapter which
handles messages containing output from probe runs. Messages are
parsed and translated to passive Nagios results. Passive results are
stored into a Messaging::Message::Queue::DQS cache.

=head1 METHODS

=over

=item C<new>

Creates new GridMon::MsgHandler::MetricOutput instance.

Options are:

=over

=item NAGIOS

instance of GridMon::Nagios::Passive class which is used for
generating Nagios passive results

=item CACHE_DIR

directory of the Messaging::Message::Queue::DQS cache

=item CACHE

instance of Messaging::Message::Queue::DQS class

=item SOURCE

if set to "remote", results are coming from external Nagios instance
(e.g. ROC or VO) and suffix "-<roleName>" is added to Nagios service
names; if set to "local", results are coming from complex probes
submitted by this Nagios instance (e.g. org.sam.WN metrics) and no
suffix is added to Nagios service names.

=back

=item C<handle>

Method implementing the message handling.

=back

=head1 SEE ALSO

GridMon::Nagios::Passive

=cut

1;
