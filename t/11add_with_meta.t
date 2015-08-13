#!/usr/bin/perl -w

use Test::More tests => 8;

use GridMon::MsgCache;
use GridMon::MetricOutput;
use File::Path;

# This can't be on an AFS path ;(
rmtree ("/tmp/log");
ok mkdir ("/tmp/log");
ok mkdir ("/tmp/log/qdir");
my $cache = GridMon::MsgCache->new({ dir => '/tmp/log/qdir' });
ok ($cache);

my $metric = GridMon::MetricOutput->new( {service_uri => 'www.example.com', 
										  status => 'foo', site => 'SITE-FOO',
										  service_flavour => 'xxx',
										  host_name => 'www.example.com',
										  summary => 'bar', metric => 'baz'});
ok($metric);

my $meta = { 'Sitename' => 'SITE-FOO', 'gatheredRole' => 'ROC'};
my $ret = $cache->add_to_cache($metric, $meta);
ok ($ret);

# and read it back
my $mesg = $cache->next_message();
ok ($mesg); 
ok ($meta->{'Sitename'} eq $mesg->{metadata}->{'Sitename'});
ok ($meta->{'gatheredRole'} eq $mesg->{metadata}->{'gatheredRole'});

