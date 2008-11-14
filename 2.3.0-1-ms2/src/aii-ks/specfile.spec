#
# Generic component spec file
#
# German Cancio <German.Cancio@cern.ch>
#
#

Summary: @DESCRIPTION@
Name: @NAME@
Version: @VERSION@
Vendor: EDG/CERN
Release: 1
License: http://cern.ch/eu-datagrid/license.html
Group: quattor/Components
Source: @TARFILE@
BuildArch: noarch
BuildRoot: /var/tmp/%{name}-build
Packager: @AUTHOR@
Requires: @NCM_EXTRA_REQUIRES@
URL: @QTTR_URL@

%description

quattor (@QTTR_URL@) NCM @COMP@ configuration component:

@DESCRIPTION@

%prep
%setup

%build
make

%install
rm -rf $RPM_BUILD_ROOT
make PREFIX=$RPM_BUILD_ROOT install

%files
%defattr(-,root,root)
%doc /usr/share/doc/@NAME@-@VERSION@/
%doc /usr/share/man/man8/*
@NCM_COMP@/@COMP@.pm
@PAN_TEMPLATESDIR@/@PAN_NAMESPACE_SDIR@/@PAN_QUATTOR_NS@/aii/@COMP@/*

%clean
rm -rf $RPM_BUILD_ROOT
