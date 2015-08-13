#! /usr/bin/perl -w
#
# Set of common functions for certificate lifetime handling used in Nagios plugins
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
# 29-Mar-2007 - Created; 
#               Parts of Nagios utils.pm are taken in order to make 
#               plugins Nagios-agnostic
# 

package GridMon::certutils;

use Nagios::Plugin;
use IO::Socket::SSL qw(inet4);
use Net::SSLeay;
use Date::Parse;
use Crypt::OpenSSL::X509;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(&checkCertLifetimeSSL &checkCertLifetimeFile &checkCertDiff);

#########################
##
##   Certificate functions
##
#########################

sub checkCertDiff {
    my $diff = shift;
    my $certDate = shift;
    my $warn = shift;
    my $crit = shift;

    if (defined $warn) {
        $warn *= 60;
    } else {
        $warn = 1209600;
    }
    
    if (defined $crit) {
        $crit *= 60;
    } else {
        $crit = 0;
    }
    
    my $state = OK;
    my $answer = "Certificate";
    my $diffString;

    if ($diff < $crit) {
        $state = CRITICAL;
    } elsif ($diff < $warn) {
        $state = WARNING;
    }
    
    if ($diff < 0) {
        $answer = "Certificate has expired <diff> ago";
        $diff = -$diff;
    } else {
        $answer = "Certificate will expire in <diff>";
    }

    if ($diff < 60) {
        $diffString = "$diff seconds";
        chop($diffString) if ($diff == 1) ;
    } elsif ($diff < 3600) {
        $diffString = sprintf("%.2f", $diff/60) . " minutes";
    } elsif ($diff < 86400) {
        $diffString = sprintf("%.2f", $diff/3600) . " hours";
    } else {
        $diffString = sprintf("%.2f", $diff/86400) . " days";
    }
    $answer =~ s/<diff>/$diffString/;

    $answer .= " ($certDate)";

    return ($state,$answer);
}

sub checkCertLifetimeSSL
{
    my $host = shift;
    my $port = shift;

    my $warn = shift;
    my $crit = shift;
    my $proto = shift || 'SSLv3';

    my $certfile = shift;
    my $key = shift;
    my $ca_path = shift || '/etc/grid-security/certificates';
    my $use_cert = 0;

    if ($certfile && $key) {
        $use_cert = 1;
    }

    my $state = OK;
    my $answer;
    my $res;
    my $cert;

    my $client;
    if ($use_cert) {
        $client = new IO::Socket::SSL(
            PeerAddr        => $host,
            PeerPort        => $port,
            SSL_version     => $proto,
            SSL_use_cert    => 1,
            SSL_cert_file   => $certfile,
            SSL_key_file    => $key,
            SSL_ca_path     => $ca_path
        );
    } else {
        $client = new IO::Socket::SSL(
            PeerAddr        => $host,
            PeerPort        => $port,
            SSL_version     => $proto
        );
    }

    if (defined $client) {
        $cert = $client->peer_certificate();
        if (!$cert) {
            $answer = "SSL ERROR: couldn't get peer certificate";
            $state = CRITICAL;
        } else {
            $res = Net::SSLeay::X509_get_notAfter($cert);
            if (!$res) {
                $answer = "Net::SSLeay error retrieveing notAfter field.";
                $state = CRITICAL;
            } else {
                my $certDate = Net::SSLeay::P_ASN1_UTCTIME_put2string($res);
                if (!$certDate) {
                    $answer = "Net::SSLeay error converting notAfter to string.";
                    $state = CRITICAL;
                } else {
                    $res = str2time($certDate);
                    $answer = $res - time();
                    ($state, $answer) = checkCertDiff($answer,$certDate,$warn,$crit);
                    $res = undef;
                }
            }
        }
        $client->close();
    } else {
        if (IO::Socket::SSL::errstr() =~ /IO::Socket::INET configuration failederror:00000000:lib\(0\):func\(0\):reason\(0\)/) {
            $answer = "Cannot establish SSL connection with $host:$port.";
        } else {
            $answer = "SSL ERROR: " . IO::Socket::SSL::errstr();
        }
        $state = UNKNOWN;
    }

    return ($state, $answer);
}

sub checkCertLifetimeFile
{
    my $cert = shift;
    my $warn = shift;
    my $crit = shift;

    my $state = OK;
    my $answer;
    my $res;

    unless (-f $cert) {
        return (CRITICAL, "Certificate $cert doesn't exist!");
    }

    unless (-r $cert) {
        return (CRITICAL, "Cannot access certificate $cert!");
    }

    eval {
        $res = Crypt::OpenSSL::X509->new_from_file($cert);
    };
    if ($@) {
        return (CRITICAL, "Error openening certificate: ".$@);
    }

    unless (defined $res) {
        return (CRITICAL, "Error openening certificate $cert!");
    }
    
    my $certDate = $res->notAfter();
    $res = str2time($certDate);
    $answer = $res - time();
    ($state, $answer) = checkCertDiff($answer,$certDate,$warn,$crit);
    $res = undef;

    return ($state, $answer, $res);
}

=head1 NAME

GridMon::Nagios

=head1 DESCRIPTION

The GridMon::certutils module provides set of common functions for 
analyzing certificate lifetimes.

=head1 SYNOPSIS

  use GridMon::certutils;

  ($state, $details)= checkCertDiff ($diff, $certDate, $warn, $crit);

  ($state, $details)= checkCertLifetimeFile ($certFile, $warn, $crit);

  ($state, $details)= checkCertLifetimeSSL ($host, $port, $warn, $crit, $proto);

=cut

=head1 METHODS

=over

=item C<checkCertDiff>

  ($state, $details)= checkCertDiff ($diff, $certDate, $warn, $crit);

Checks if the certificate lifetime is withing critical or warning threshold.
Arguments are:
  $diff - certificate lifetime in seconds
  $certDate - certificate expiration date (string)
  $warn - warning threshold
  $crit - critical threshold
If the $diff is smaller than $crit method will return $state CRITICAL.
If the $diff is smaller than $warn method will return $state WARNING.

=item C<checkCertLifetimeFile>

  ($state, $details)= checkCertLifetimeFile ($certFile, $warn, $crit);

Checks the lifetime of certificate stored in file $certFile.
Arguments are:
  $certFile - certificate path
  $warn - warning threshold
  $crit - critical threshold
If the $diff is smaller than $crit method will return $state CRITICAL.
If the $diff is smaller than $warn method will return $state WARNING.

=item C<checkCertLifetimeSSL>

  ($state, $details)= checkCertLifetimeSSL ($host, $port, $warn, $crit, $proto);

Checks if the lifetime of certificate used by SSL service on host $host and port 
$port.
Arguments are:
  $host - host where the SSL service is running
  $port - port where the SSL service is running
  $warn - warning threshold
  $crit - critical threshold
  $proto - version of SSL protocol, supported values: SSLv2, SSLv3, TLSv1
If the $diff is smaller than $crit method will return $state CRITICAL.
If the $diff is smaller than $warn method will return $state WARNING.

=back

=cut

1;
