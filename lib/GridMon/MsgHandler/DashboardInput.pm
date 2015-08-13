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

package GridMon::MsgHandler::DashboardInput;

use strict;
use warnings;
use GridMon::MsgHandler;
#use TOM::Date qw(date_string);
use No::Worries::Date qw(date_string);

#use TOM::Nagios qw(nagios_cmd);
use GridMon::Nagios qw(nagios_cmd);
use YAML;

our(@ISA) = qw(GridMon::MsgHandler);

use constant AUTHOR => "Dashboard to Nagios";

#
# parse and check the message body
#

sub _parse ($) {
    my($body) = @_;
    my(%data, $content, $field);

    # decode YAML
    eval { ($content) = Load($body) };
    return(0, "cannot parse message body: $@") if $@;

    # check the mandatory fields
    foreach $field (qw(nodeName testName dashboardStatus)) {
	return(0, "missing data from message body: $field") unless $content->{$field};
    }

    # extract the interesting fields
    $data{host}     = $content->{nodeName};
    $data{service}  = $content->{testName};
    $data{status}   = $content->{dashboardStatus};
    $data{comments} = $content->{comments};

    # sanitize them
    $data{host}     =~ s/[^A-Za-z0-9_\.-]//g;
    $data{service}  =~ s/[^A-Za-z0-9_\.-]//g;
    $data{status}   =~ s/[^A-Z]//g;
    $data{comments} =~ s/[^A-Za-z0-9_\/:\?=\s]//g if $data{comments};

    # so far so good
    return(\%data);
}

#
# handle one message
#

sub handle : method {
    my($self, $headers, $body) = @_;
    my($data, @commands, $reason);

    # extract data from the message
    ($data, $reason) = _parse($body);
    return($self->warning($reason)) unless $data;
    $self->debug(2, "[DASHBOARD] %s;%s notification ACK = %s",
		 $data->{host}, $data->{service}, $data->{status});

    # update the environment variable based on the dashboard status
    @commands = ();
    push(@commands, sprintf("CHANGE_CUSTOM_SVC_VAR;%s;%s;dashboard_notification_status;%s",
			    $data->{host}, $data->{service}, $data->{status}));
    push(@commands, sprintf("CHANGE_CUSTOM_SVC_VAR;%s;%s;dashboard_notification_status_last_update;%s",
			    $data->{host}, $data->{service}, date_string()));
    push(@commands, sprintf("ADD_SVC_COMMENT;%s;%s;0;%s;Notification status: %s%s",
			    $data->{host}, $data->{service}, AUTHOR, $data->{status},
			    $data->{comments} ? " ($data->{comments})" : ""));
    nagios_cmd(@commands);

    # save state information
    nagios_cmd("SAVE_STATE_INFORMATION");

    # so far so good
    return($self->success());
}

1;

=head1 NAME

GridMon::MsgHandler::DashboardInput

=head1 DESCRIPTION

The GridMon::MsgHandler::DashboardInput is a msg-to-handler adapter
which handles messages containing service notications acknowledgement
from the Dashboard. Messages are parsed and injected into Nagios via
the command pipe.

=head1 METHODS

=over

=item C<new>

Creates new GridMon::MsgHandler::DashboardInput instance.

=item C<handle>

Extracts the YAML payload of acknowledgement messages sent by the
Dashboard. These aknowledgement are matched against a service
notification previously sent.

Once the relevant host and service have been identified, the script
will: update the relevant Nagios environment variable to mark the
service notification as acknowledged and add a comment on the Web
interface to reflect the acknowledgement.

=back

=head1 SEE ALSO

GridMon::MsgHandler::MetricOuput,
GridMon::Nagios::Passive

=cut
