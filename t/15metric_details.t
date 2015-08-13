#!/usr/bin/perl -w

use Test::More tests => 3;
use Test::Exception;

use lib 'lib'; if (-d 'test') { chdir 'test'; }

BEGIN {use_ok( 'GridMon::MetricOutput');}

# Bug https://savannah.cern.ch/bugs/?43555 : extra EOT in detailsData in GridMon/MetricOutput.pm
my $metric = GridMon::MetricOutput->new( {service_uri =>'www.example.com',
										  service_flavour => 'FOO', status => 'foo',
										  site => 'SITE-FOO',
										  host_name => 'www.example.com',
										  summary => 'bar', metric => 'baz',
									      details => "foo\nbar"});
ok($metric);
like($metric->wlcg_format(), '/detailsData: foo\nbar\nEOT\n$/');

##


