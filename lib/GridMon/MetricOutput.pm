# Copyright 2008 James Casey
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

=head1 NAME

GridMon::MetricOutput

=head1 SYNOPSIS
A representation of a WLCG Format metric record.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=cut
package GridMon::MetricOutput;

our @ISA = ();

#use TOM::Date qw(date_string);
use No::Worries::Date qw(date_string);
use Sys::Hostname;

=item C<new>

=cut
sub new { 
	my $class = shift;
	my $opts = shift;
	$opts ||= { };
	$class = ref($class) || $class;
	my $self = $opts;
	bless($self, $class);

	die "no 'service_uri' specified" unless $self->{service_uri};
	die "no 'service_flavour' specified" unless $self->{service_flavour};
	die "no 'host_name' specified" unless $self->{host_name};
	die "no 'metric' specified" unless $self->{metric};
	die "no 'status' specified" unless $self->{status};
	die "no 'summary' specified" unless $self->{summary};
	die "no 'site' specified" unless $self->{site};
	$self->{details} = '' if ! $self->{details};
	$self->{timestamp} = date_string();
	$self->{gatheredAt} = hostname;
	$self;
}

=item C<wlcg_format>

Return a textual representation of the C<MetricOutput> object in WLCG
format.

=cut
sub wlcg_format {
	my ($self) = @_;

	my $message= <<EOF;
serviceURI: $self->{service_uri}
hostName: $self->{host_name}
serviceFlavour: $self->{service_flavour}
siteName: $self->{site}
metricStatus: $self->{status}
metricName: $self->{metric}
summaryData: $self->{summary}
gatheredAt: $self->{gatheredAt}
timestamp: $self->{timestamp}
EOF
    if ($self->{nagios_name}) {
        $message .= "nagiosName: $self->{nagios_name}\n";
    }
    if ($self->{role}) {
        $message .= "role: $self->{role}\n";
    }
    if ($self->{vo}) {
        $message .= "voName: $self->{vo}\n";
    }
    if ($self->{vo_fqan}) {
        $message .= "voFqan: $self->{vo_fqan}\n";
    }
    if ($self->{service_type}) {
        $message .= "serviceType: $self->{service_type}\n";
    }
    if ($self->{encrypted}) {
        $message .= "encrypted: yes\n";
    }
    if ($self->{details}) {
        $message .= "detailsData: $self->{details}\n";
    }
    $message .="EOT\n";
    return $message;
}

1;
