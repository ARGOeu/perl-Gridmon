Name:           perl-GridMon
# do not forget to change GridMon.pm to put the same version string...
Version:        1.0.75
Release:        2%{?dist}
Summary:        GridMon Perl module
License:        Apache 2
Group:          Development/Libraries
URL:            http://search.cpan.org/dist/GridMon/
Source0:        http://www.cpan.org/modules/by-module/GridMon/GridMon-%{version}.tar.gz
BuildRoot:      %{_tmppath}/perl-%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
BuildRequires:  perl(Config::General)
BuildRequires:  perl(Crypt::OpenSSL::RSA)
BuildRequires:  perl(Crypt::OpenSSL::X509)
BuildRequires:  perl(Crypt::SMIME)
BuildRequires:  perl(Date::Format)
BuildRequires:  perl(ExtUtils::MakeMaker)
BuildRequires:  perl(IO::Socket::SSL)
BuildRequires:  perl(IPC::DirQueue)
BuildRequires:  perl(Nagios::Plugin)
BuildRequires:  perl(Test::Exception)
BuildRequires:  perl(Test::More)
BuildRequires:  perl(Test::Pod)
BuildRequires:  perl(Test::Pod::Coverage)
BuildRequires:  perl(No::Worries)
BuildRequires:  perl(DBI)
BuildRequires:  perl(Messaging::Message)
BuildRequires:  perl(YAML)
Requires:       perl(Config::General)
Requires:       perl(Crypt::OpenSSL::RSA)
Requires:       perl(Crypt::OpenSSL::X509)
Requires:       perl(Crypt::SMIME)
Requires:       perl(DBI)
Requires:       perl(DBD::SQLite)
Requires:       perl(Date::Format)
Requires:       perl(Date::Parse)
Requires:       perl(Digest::SHA1)
Requires:       perl(Directory::Queue)
Requires:       perl(IO::Socket::SSL)
Requires:       perl(IPC::DirQueue)
Requires:       perl(Messaging::Message)
Requires:       perl(Messaging::Message::Queue)
Requires:       perl(MIME::Base64)
Requires:       perl(Nagios::Plugin)
Requires:       perl(Sys::Hostname)
Requires:       perl(Test::Exception)
Requires:       perl(Test::More)
Requires:       perl(Test::Pod)
Requires:       perl(Test::Pod::Coverage)
Requires:       perl(YAML)
Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires:       perl(No::Worries)

%description
A Perl library for interface code used for grid monitoring.

%prep
%setup -q -n GridMon-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
make %{?_smp_mflags}

%install
rm -rf $RPM_BUILD_ROOT

make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT

find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;

%{_fixperms} $RPM_BUILD_ROOT/*

%check
make test

%clean
rm -rf $RPM_BUILD_ROOT

%post
if [ -x /etc/init.d/msg-to-handler ]; then
  # try to restart msg-to-handler in case handler code has changed
  /etc/init.d/msg-to-handler condrestart
fi

%files
%defattr(-,root,root,-)
%doc CHANGES README
%{perl_vendorlib}/*
%{_mandir}/man3/*

%changelog
* Fri Mar 16 2018 Emir Imamagic <eimamagi@srce.hr> - 10.0.75-1
- Removed support for NSCA passive reporting
* Thu Mar 24 2016 Emir Imamagic <eimamagi@srce.hr> - 10.0.74-2
- Change default LCG and GLITE locations
- Added 
* Wed Feb 13 2013 Robert Veznaver <robert.veznaver@cern.ch> - 10.0.73-1
- SAM-3136 Change GridMon::sgutils default GLOBUS location
* Mon Jan 14 2013 Marian Babik <marian.babik@cern.ch> - 1.0.72-1
- SAM-3054 Remove perl-TOM dependency from perl-GridMon
- Merged changes from Update-21 branch
* Thu Nov 29 2012 Emir Imamagic <eimamagi@srce.hr> - 1.0.71-1
- SAM-3056 Use of uninitialized values in GridMon::Nagios
* Fri Nov 23 2012 Paschalis Korosoglou <pkoro@grid.auth.gr> - 1.0.62-2
- SAM-2627 Include dependency on perl NoWorries
* Wed Nov 21 2012 Nikolai Klopov <Nikolai.Klopov@cern.ch> - 1.0.62-1
- SAM-2627 Probe libraries need to be ported to SL6
* Wed Nov 14 2012 Marian Babik <Marian.Babik@cern.ch> - 1.0.70-1
- SAM-3089 Remove nagios-ggus-cert dependency from perl-GridMon
* Tue Aug 7 2012 Christos Triantafyllidis <ctria@grid.auth.gr> - 1.0.61-2
- Added perl(Directory::Queue) to the requires of the package
  https://tomtools.cern.ch/jira/browse/SAM-2889
* Mon Jun 25 2012 Christos Triantafyllidis <ctria@grid.auth.gr> - 1.0.61-1
- Replaced perl-MIG with perl-Messaging-Message
  https://tomtools.cern.ch/jira/browse/SAM-2444
* Thu Jun 30 2011 Emir Imamagic <eimamagi@srce.hr> - 1.0.60-1
- Enable sending alarms without problem ID
  https://tomtools.cern.ch/jira/browse/SAM-1672
* Mon Jun 27 2011 Emir Imamagic <eimamagi@srce.hr> - 1.0.59-2
- perl(JSON) dependency of egee-NAGIOS
  https://tomtools.cern.ch/jira/browse/SAM-1626
* Wed Feb 23 2011 Lionel Cons <lionel.cons@cern.ch> - 1.0.59-1
- Added wildcard support to GridMon::MsgHandler::ConfigOutput, this fixes SAM-1179.
* Thu Sep 30 2010 Emir Imamagic <eimamagi@srce.hr> - 1.0.58-1
- Problem with TOM::Nagios::handle_die - removed workaround
  https://tomtools.cern.ch/jira/browse/SAM-750
- CertLifetime metric should return unknown status if remote 
  certificate could not be accessed
  https://tomtools.cern.ch/jira/browse/SAM-818
* Mon Sep 27 2010 Wojciech Lapka <Wojciech.Lapka@cern.ch> - 1.0.57-1
- bug fix
* Mon Sep 20 2010 Wojciech Lapka <Wojciech.Lapka@cern.ch> - 1.0.56-1
- Added FILTER_FILE with Nagios hosts to ConfigOutput
  https://tomtools.cern.ch/jira/browse/SAM-574
* Thu Aug 26 2010 Emir Imamagic <eimamagi@srce.hr> - 1.0.55-1
- Problem with TOM::Nagios::handle_die
  https://tomtools.cern.ch/jira/browse/SAM-750
* Fri Aug 13 2010 Lionel Cons <lionel.cons@cern.ch> - 1.0.53-1
- Code cleanup and now using the TOM modules.
- MsgHandler::GGUSInput and MsgHandler::MetricOutput now use the new
  message queue (MIG::Message::Queue).
* Tue Aug 3 2010 Emir Imamagic <eimamagi@srce.hr> 1.0.52-1
- Fixed nagios-gocdb-downtime - Couldn't filter Nagios hosts based on _site_name
  https://tomtools.cern.ch/jira/browse/SAM-696
* Fri Jul 30 2010 Christos Triantafyllidis <ctria@grid.auth.gr> - 1.0.51-1
- Fixed sanitation regexp for DashboardInput
  https://tomtools.cern.ch/jira/browse/SAM-487
* Fri Jul 30 2010 Christos Triantafyllidis <ctria@grid.auth.gr> - 1.0.50-1
- Added WN report for encrypted results
  https://tomtools.cern.ch/jira/browse/SAM-674
* Tue Jun 29 2010 Emir Imamagic <eimamagi@srce.hr> 1.0.49-1
- GridMon::Nagios filters hosts that do not contain searched field.
* Tue Jun 29 2010 Emir Imamagic <eimamagi@srce.hr> 1.0.48-1
- Implemented url_help can be empty
  https://tomtools.cern.ch/jira/browse/SAM-615
* Thu Jun 17 2010 Christos Triantafyllidis <ctria@grid.auth.gr> - 1.0.47-1
- Changed the location of ggus_server.crt
* Tue Jun 15 2010 Lionel Cons <lionel.cons@cern.ch> - 1.0.46-1
- Conditionally restart msg-to-handler in %post
* Wed Jun 02 2010 Lionel Cons <lionel.cons@cern.ch> - 1.0.45-1
- Cleaned msg-to-handler modules to improve reliability.
* Thu May 20 2010 Lionel Cons <lionel.cons@cern.ch> - 1.0.44-1
- Improved input handling in the GGUSInput handler
* Tue May 18 2010 Romainn Wartel <Romain.Wartel@cern.ch> 1.0.43-1
- Fixed excessive sanitization of the service name
* Fri May 07 2010 Emir Imamagic <eimamagi@srce.hr> - 1.0.42-1
- Fixed vo_fqan typo in MetricOutput
* Mon May 03 2010 Lionel Cons <lionel.cons@cern.ch> - 1.0.41-1
- Updated the message handler modules to be compatible with msg-to-handler
* Mon Apr 26 2010 Christos Triantafyllids <ctria@grid.auth.gr> 1.0.40-1
- Fixed encryption method by using Crypt::SMIME
  https://savannah.cern.ch/bugs/?66459
* Wed Apr 14 2010 Romain Wartel <Romain.Wartel@cern.ch> 1.0.39-1
- Added vo_fqan to MetricOutput
  https://savannah.cern.ch/bugs/?64883
- Fixed a incorrect input filter in the GGUSInput handler
* Fri Mar 19 2010 Emir Imamagic <eimamagi@srce.hr> 1.0.38-1
- Removed obsoleted perl JSON calls (added dep)
- Removed GridMon::MsgBroker and GridMon::URI::Stomp
* Fri Feb 26 2010 Emir Imamagic <eimamagi@srce.hr> 1.0.37-1
- Added clear function to GridMon::ConfigCache.
* Wed Feb 24 2010  Romain <Romain.Wartel@cern.ch> 1.0.36-1
- Added ACK for Dashboard notifications
* Wed Feb 24 2010 Emir Imamagic <eimamagi@srce.hr> 1.0.35-1
- Print meaningful message in case SSL on host:port is not working.
* Fri Jan 29 2010 Romain Wartel <Romain.Wartel@cern.ch> 1.0.34-1
- Added serviceFlavour for Dashboard notifications
* Tue Jan 19 2010 Emir Imamagic <eimamagi@srce.hr> 1.0.33-1
- Added decryption functions for security probes
* Tue Jan 19 2010 Romain Wartel <Romain.Wartel@cern.ch> 1.0.31-1
- Added initial support for MyEGEE "GGUS notifications"
* Fri Jan 08 2010 Romain Wartel <Romain.Wartel@cern.ch> 1.0.30-1
- Improved debugging info and added support for Dashboard problem IDs
* Tue Jan 05 2010 Romain Wartel <Romain.Wartel@cern.ch> 1.0.29-1
- Added a dependency on the GGUS host certificate
* Fri Nov 13 2009 Emir Imamagic <eimamagi@srce.hr> 1.0.28-1
- Added user cert & key checkCertLifetimeSSL in certutils.
* Fri Nov 13 2009 Steve Traylen <steve.traylen@cern.ch> 1.0.27-1
- Adding signature check to GGUS messages
* Tue Nov 10 2009 Steve Traylen <steve.traylen@cern.ch> 1.0.25-1
- Change in schema for notifications
* Mon Aug 31 2009 Steve Traylen <steve.traylen@cern.ch> 1.0.23-1
- Addition of MetricOutputNagios
* Tue Jun 23 2009 Steve Traylen <steve.traylen@cern.ch> 1.0.18-2
- Bump 1.0.18
* Tue Jun 23 2009 Steve Traylen <steve.traylen@cern.ch> 1.0.17-2
- Remove all env setting in sgutils.pm
  Fixes: https://savannah.cern.ch/bugs/index.php?52183
* Fri May 29 2009 Steve Traylen <steve.traylen@cern.ch> 1.0.16-1
- Specfile autogenerated by cpanspec 1.77.
