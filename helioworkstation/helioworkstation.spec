Name:    helio-workstation
Version: 3.1.0
Release: 1%{?dist}
Summary: An audio sequencer
URL:     https://github.com/helio-fm/helio-workstation
License: GPLv2+

# git clone https://github.com/helio-fm/helio-workstation
# cd helio-workstation
# git checkout 3.1
# git submodule init
# git submodule update
# find . -name .git -exec rm -rf {} \;
# cd ..
# tar cvfz helio-workstation.tar.gz helio-workstation/
# rm -rf helio-workstation

Source0: helio-workstation.tar.gz

BuildRequires: gcc gcc-c++
BuildRequires: jack-audio-connection-kit-devel
BuildRequires: alsa-lib-devel
BuildRequires: make
BuildRequires: desktop-file-utils
BuildRequires: libcurl-devel
BuildRequires: freetype-deve
BuildRequires: libglvnd-devell
BuildRequires: libX11-devel libXft-devel libXrandr-devel libXinerama-devel libXcursor-devel

%description
Helio Workstation is free and open-source music sequencer, designed to be used on all major platforms.

%prep
%autosetup -n %{name}

%build

%set_build_flags

cd Projects//LinuxMakefile/
%make_build STRIP=true

%install

%__install -m 755 -d %{buildroot}/%{_bindir}/
cp -a Projects/LinuxMakefile/build/Helio %{buildroot}/%{_bindir}/

%__install -m 755 -d %{buildroot}/%{_datadir}/applications/
cp -a Projects/Deployment/Linux/Debian/x64/usr/share/applications/Helio.desktop %{buildroot}%{_datadir}/applications/%{name}.desktop

%__install -m 755 -d %{buildroot}/%{_datadir}/icons/
cp -ra Projects/Deployment/Linux/Debian/x64/usr/share/icons/* %{buildroot}%{_datadir}/icons/

%__install -m 755 -d %{buildroot}/%{_datadir}/doc/%{name}/
cp -ra Docs/* %{buildroot}/%{_datadir}/doc/%{name}/

# install konfyt.desktop properly.
desktop-file-install --vendor '' \
        --add-category=AudioVideo \
        --add-category=X-Midi \
        --add-category=X-Jack \
        --dir %{buildroot}%{_datadir}/applications \
        %{buildroot}%{_datadir}/applications/%{name}.desktop

%files
%doc README.md CHANGELOG.md
%license LICENSE
%{_bindir}/*
%{_datadir}/applications/*
%{_datadir}/icons/hicolor/*
%{_datadir}/doc/%{name}/*

%changelog
* Tue Oct 6 2020 Yann Collette <ycollette.nospam@free.fr> - 3.1.0-1
- Initial spec file 3.1.0
