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

GridMon::MsgCache

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 4

=cut


package GridMon::MsgCache;

our @ISA = ();
our $VERSION = "1.0";

our $DEBUG; # = 1;

use IPC::DirQueue;

=item $cache->new(DIRECTORY);

Construct a new message change object for the given cache directory.

=cut
sub new {
	my $class = shift;
	my $opts = shift;
	$opts ||= { };
	$class = ref($class) || $class;
	my $self = $opts;
	bless($self, $class);

	die "no 'dir' specified" unless $self->{dir};
	my $dir = $self->{dir};
	$self->{dir_queue} = IPC::DirQueue->new({dir => $dir});

	$self;
}

=item $cache->add_to_cache($message, $metadata);

Add a new message to the cache.  This is in the form of an object
representing the message. We will call the C<wlcg_format()> method 
to convert into a WLCG formatted message

Optional metadata can be passed in-  this must be in the form of
C<{name - value}> pairs.

=cut

sub add_to_cache {
	my ($self, $message, $metadata) = @_;
	

	$q = $self->{dir_queue};

	my $stringy_message = $message->wlcg_format();
	return $q->enqueue_string($stringy_message, $metadata);
}

=item $cache->add_string_to_cache($message, $metadata);

Add a new string message to the cache.

Optional metadata can be passed in - this must be in the form of
C<{name - value}> pairs.

=cut

sub add_string_to_cache {
	my ($self, $message, $metadata) = @_;

	$q = $self->{dir_queue};

	return $q->enqueue_string($message, $metadata);
}

=item $message = next_message([ $timeout ]);

Wait for and get a message from the cache. The message payload is available via the 
C<get_data()> method.

If C<$timeout> is not specified, or is less than 1, this function will wait
indefinitely.

=back

=cut

sub next_message {
	my ($self, $timeout) = @_;

	$q = $self->{dir_queue};
	if($timeout) {
		return $q->wait_for_queued_job($timeout);
	} else {
		return $q->wait_for_queued_job();
	}
}

1;
	
