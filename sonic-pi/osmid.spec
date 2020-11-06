Name:    osmid
Version: 0.8.0
Release: 1%{?dist}
Summary: osmid is a tool to bridge MIDI and OSC
URL:     https://github.com/llloret/osmid
License: GPLv2+

Source0: https://github.com/llloret/osmid/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires: gcc gcc-c++
BuildRequires: cmake
BuildRequires: jack-audio-connection-kit-devel
BuildRequires: alsa-lib-devel
BuildRequires: libX11-devel

%description
osmid aims to provide a lightweight, portable, easy to use tool to
convert MIDI to OSC and OSC to MIDI.

It is the software handling the communication with MIDI devices in Sonic Pi.

osmid is divided in 2 tools:
 * m2o: MIDI to OSC conversion
 * o2m: OSC to MIDI conversion

Having two separate tools follows Unix ideas of having a number of smaller
standalone tools instead of bigger monolithic ones. Since some projects might
want to use just one direction for the conversion, it makes sense to keep this separation.

%prep
%autosetup -n %{name}-%{version}

%build

%cmake
%cmake_build

%install

%cmake_install

%files
%doc README.md
%license LICENSE.md
%{_bindir}/*

%changelog
* Fri Nov 06 2020 Yann Collette <ycollette.nospam@free.fr> - 0.7.0-1
- Initial spec file
