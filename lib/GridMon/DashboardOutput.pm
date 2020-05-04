# Copyright 2009 Romain Wartel
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

GridMon::DashboardOutput

=head1 SYNOPSIS
A representation of a dashboard notification record.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=cut
package GridMon::DashboardOutput;

our @ISA = ();

#use TOM::Date qw(date_string);
use No::Worries::Date qw(date_string);
use Sys::Hostname;
use YAML qw(Dump);

=item C<new>

=cut
sub new {
	my $class = shift;
	my $opts = shift;
	$opts ||= { };
	$class = ref($class) || $class;
	my $self = $opts;
	bless($self, $class);

        die "no 'site' specified" unless $self->{site};
        die "no 'test_name' specified" unless $self->{test_name};
        die "no 'node_name' specified" unless $self->{node_name};
        die "no 'service_flavour' specified" unless $self->{service_flavour};
        die "no 'execution_time' specified" unless $self->{execution_time};
        die "no 'notification_time' specified" unless $self->{notification_time};
        die "no 'notification_type' specified" unless $self->{notification_type};
#        die "no 'problem_id' specified" unless $self->{problem_id};
        die "no 'status' specified" unless $self->{status};
        die "no 'url_history' specified" unless $self->{url_history};

	$self->{url_help} = '' if ! $self->{url_help};
	$self->{details} = '' if ! $self->{details};
	$self->{timestamp} = date_string();
	$self->{gatheredAt} = hostname;
	$self;
}

=item C<wlcg_format>

Return a textual representation of the C<DashboardOutput> object in 
dashboard notification format.

=back

=cut

sub wlcg_format {
	my ($self) = @_;
        my $yaml_format= {
                        siteName => $self->{site},
                        testName => $self->{test_name},
                        nodeName => $self->{node_name},
                        executionTime =>  $self->{execution_time},
			serviceFlavour => $self->{service_flavour},
                        notificationTime => $self->{notification_time},
                        notificationType =>  $self->{notification_type},
                        problemID =>  $self->{problem_id},
                        testStatus =>  $self->{status},
                        urlToHistory => $self->{url_history},
                        timestamp => $self->{timestamp},
        };
        $yaml_format->{'urlToHelp'} = $self->{url_help} if ($self->{url_help});
        $yaml_format->{'voName'} = $self->{vo} if ($self->{vo});
        $yaml_format->{'detailsData'} = $self->{details} if ($self->{details});

	#Tranforming the hash into a serialised YAML data
	my $message = Dump $yaml_format;
    return $message;
}

1;
