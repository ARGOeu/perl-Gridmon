#
# Common code for all message handlers.
#
# Copyright (c) 2010 Lionel Cons
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

package GridMon::MsgHandler;

use strict;
use warnings;

#
# return codes
#

use constant SUCCESS => 101; # message has been handled
use constant WARNING => 102; # message has not been handled but handler is ok
use constant ERROR   => 103; # message has not been handled and handler is bad

#
# inheritable constructor that can be given a hash of options
#

sub new : method {
    my($class, @data) = @_;
    my(%hash, $self);

    if (@_ == 2 and ref($data[0]) eq "HASH") {
	# given a hash reference
	%hash = %{ $data[0] };
    } elsif (@data % 2 == 0) {
	# given a hash
	%hash = @data;
    } else {
	die("${class}->new(): invalid invocation\n");
    }
    $self = \%hash;
    bless($self, $class);
    return($self);
}

#
# helper methods for the return codes
#

sub success : method {
    my($self) = @_;

    return(SUCCESS);
}

sub warning : method {
    my($self, $reason) = @_;

    return(WARNING, $reason);
}

sub error : method {
    my($self, $reason) = @_;

    return(ERROR, $reason);
}

#
# debugging method (msg-to-handler does provide a main::debug() function)
#

sub debug : method {
    my($self, $level, $format, @arguments) = @_;
    my($message);

    if (defined(&main::debug)) {
	main::debug($level, $format, @arguments);
    } else {
	$message = sprintf($format, @arguments);
	$message =~ s/\s+$//;
	if ($level) {
	    printf(STDERR "%s %s\n", "#" x $level, $message);
	} else {
	    printf(STDERR "%s\n", $message);
	}
    }
}

1;

__END__

=head1 NAME

GridMon::MsgHandler

=head1 DESCRIPTION

This module provides common code for all message handlers.

The handlers should inherit from this class via:

  use GridMon::MsgHandler;
  our(@ISA) = qw(GridMon::MsgHandler);

=head1 METHODS

=over

=item new([OPTIONS])

Creates a new handler object. It accepts both a hash or a hash reference of options.

=item success()

Can be used by the handler to indicate a success.

=item warning(REASON)

Can be used by the handler to indicate a warning.

=item error(REASON)

Can be used by the handler to indicate an error.

=item debug(LEVEL, FORMAT, ARGUMENTS...)

Can be used by the handler to log a debug message of a given level.
This will be displayed if C<msg-to-handler> is executed with the
C<--debug> option.

=back
