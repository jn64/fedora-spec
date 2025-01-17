%define commit0 c78ef40603476351ef42641617e99023cc3b324b

Name:    lv2-slowmo
Version: 0.1
Release: 1%{?dist}
Summary: Multiband slowgate with delay
License: GPLv2+
URL:     https://github.com/brummer10/slowmo.lv2

Vendor:       Audinux
Distribution: Audinux

# To get the sources:
# ./brummer10-source.sh slowmo.lv2 c78ef40603476351ef42641617e99023cc3b324b

Source0: slowmo.lv2.tar.gz
Source1: brummer10-source.sh

BuildRequires: gcc gcc-c++
BuildRequires: make
BuildRequires: lv2-devel
BuildRequires: libX11-devel
BuildRequires: cairo-devel
BuildRequires: liblo-devel
BuildRequires: libsigc++20-devel
BuildRequires: vim-common

%description
Overdrive / Distortion

%prep
%autosetup -n slowmo.lv2

%build

%set_build_flags

%make_build STRIP=true

%install 

%make_install INSTALL_DIR=/usr/%{_lib}/lv2 STRIP=true

%files
%doc README.md
%{_libdir}/lv2/*

%changelog
* Sat Jan 21 2023 Yann Collette <ycollette.nospam@free.fr> - 0.1-1
- Initial spec file
