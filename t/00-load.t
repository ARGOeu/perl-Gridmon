#!perl -T

use Test::More tests => 7;

BEGIN {
	use_ok( 'GridMon' );
	use_ok( 'GridMon::Nagios' );
	use_ok( 'GridMon::Nagios::Downtimes' );
	use_ok( 'GridMon::certutils' );
	use_ok( 'GridMon::sgutils' );
}

diag( "Testing GridMon $GridMon::VERSION, Perl $], $^X" );
