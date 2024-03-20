use strict;
use warnings;
use ExtUtils::MakeMaker;

eval "use ExtUtils::MakeMaker::Coverage";
$@ or print "Adding testcover target\n";

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'perl-GridMon',
    VERSION_FROM      => 'lib/GridMon.pm',
    AUTHOR => 'James Casey <james.casey@cern.ch>',
#    NO_META => 1,
#    PL_FILES            => {},
    PREREQ_PM => {
# only for test framework
        'Test::More' => 0,
	'Test::Exception' => 0,
        'Test::Pod' => 0,
        'Test::Pod::Coverage' => 0,
# For runtime code
	'Config::General' => 0,
	'Crypt::OpenSSL::RSA' => 0,
	'Crypt::OpenSSL::X509' => 0,
	'Crypt::SMIME' => 0,
	'Date::Format' => 0,
	'IO::Socket::SSL' => 0,
	'IPC::DirQueue' => 0,
	'Monitoring::Plugin' => 0,
	'URI' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'GridMon-*' },
);
