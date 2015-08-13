#!/usr/bin/perl -w

use Test::More tests => 11;
use Test::Exception;

use lib 'lib'; if (-d 'test') { chdir 'test'; }

BEGIN {use_ok( 'GridMon::MetricOutput');}

my $metric = GridMon::MetricOutput->new( {service_uri =>'www.example.com',
										  service_flavour => 'FOO', status => 'foo',
										  site => 'SITE-FOO',
										  summary => 'bar', metric => 'baz',
                                          host_name => 'my.host'});
ok($metric);
ok ($metric->{status} eq 'foo');
ok ($metric->{summary} eq 'bar');
ok ($metric->{metric} eq 'baz');
like($metric->wlcg_format(), '/metricStatus: foo\n/');
like($metric->wlcg_format(), '/serviceURI: www.example.com\n/');
like($metric->wlcg_format(), '/summaryData: bar\n/');
like($metric->wlcg_format(), '/metricName: baz\n/');
like($metric->wlcg_format(), '/serviceFlavour: FOO\n/');
like($metric->wlcg_format(), '/hostName: my.host\n/');

