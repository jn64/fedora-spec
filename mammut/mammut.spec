# Global variables for github repository
%global commit0 71986a48f10c62f622421c204611b5b354fbad19
%global gittag0 master
%global shortcommit0 %(c=%{commit0}; echo ${c:0:7})

Name:    mammut
Version: 0.61.%{shortcommit0}
Release: 1%{?dist}
Summary: A sound editor with a non-intuitive sound transformation approach using one single gigantic analysis (no windows)
License: GPLv3
URL:     https://github.com/kmatheussen/mammut/

Source0: https://github.com/kmatheussen/%{name}/archive/%{commit0}.tar.gz#/%{name}-%{shortcommit0}.tar.gz
Source1: mammut_globals.c
Patch0:  mammut_0001-fix-juce-encoding.patch

BuildRequires: gcc gcc-c++
BuildRequires: libX11-devel
BuildRequires: mesa-libGL-devel
BuildRequires: alsa-lib-devel
BuildRequires: freetype-devel
BuildRequires: libcurl-devel
BuildRequires: libXinerama-devel
BuildRequires: webkit2gtk3-devel
BuildRequires: gtk3-devel
BuildRequires: libsndfile-devel
BuildRequires: libvorbis-devel
BuildRequires: libsamplerate-devel
BuildRequires: jack-audio-connection-kit-devel
BuildRequires: desktop-file-utils

%description
A sound editor with a non-intuitive sound transformation approach using one
single gigantic analysis (no windows). 

%prep
%autosetup -p1 -n %{name}-%{commit0}

cp %{SOURCE1} src/globals.c

%build

%set_build_flags

cd juce_5_3_2/Builds/Linux
%make_build CONFIG=Release STRIP=true V=1

cd ../../../src
%make_build -f Makefile.linux  CONFIG=Release STRIP=true V=1

%install 

install -m 755 -d %{buildroot}%{_bindir}/
install -m 755 src/%{name} %{buildroot}/%{_bindir}/

install -m 755 -d %{buildroot}%{_datadir}/pixmaps/
install -m 644 icons/icon.png %{buildroot}/%{_datadir}/pixmaps/%{name}.png

install -m 755 -d %{buildroot}%{_datadir}/applications/

cat > %{buildroot}%{_datadir}/applications/mammut.desktop << EOF
[Desktop Entry]
Name=Mammut
Comment=A sound editor.
Exec=/usr/bin/mammut
Type=Application
Terminal=0
Icon=/usr/share/pixmaps/mammut.png
Categories=AudioVideo;
EOF

desktop-file-install                         \
  --add-category="Audio"                     \
  --delete-original                          \
  --dir=%{buildroot}%{_datadir}/applications \
  %{buildroot}/%{_datadir}/applications/%{name}.desktop

%files
%doc README
%{_bindir}/*
%{_datadir}/*

%changelog
* Sun Dec 20 2020 Yann Collette <ycollette.nospam@free.fr> - 4.61-71986a48-1
- Initial spec file