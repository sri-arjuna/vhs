Name:           vhs
Version:        1.0.5
Release:        0%{?dist}
Summary:        Video Handler Script

License:        GPLv3
URL:            https://github.com/sri-arjuna/vhs
Source0:        vhs-%{version}.tar.gz

Requires:       tui
Requires:       ffmpeg
Requires:       mkvtoolnix
Requires:       v4l-utils

#Requires:       ogmtools
#Requires:       oggvideotools
#Requires:       theora-tools
#Requires:       vorbis-tools
#Requires:       speex-tools
#Requires:       swftools
#Requires:       mjpegtools
#Requires:       libdvdcss

%description
A Script to handle different multimedia tasks.
* Re-encode existing videos
* Capture web cam
* Capture desktop
* Capture webcam as PiP over desktop
* Extract audio stream from video files
* Include audio-, subtitle streams
* Include PiP Video
* Include Logoimage (Top Left fixed)
* Encode DVD, non-copy-protected only

%prep
%setup -q -c %{name}-%{version}

%build
# Nothing to do

%install
rm -rf $RPM_BUILD_ROOT
##%make_install

mkdir -p %{buildroot}%{_bindir}/ \
         %{buildroot}%{_datarootdir}/%{name}
rm -fr %{name}/.git
mv %{name}/vhs.sh %{buildroot}%{_bindir}/vhs
mv %{name}/[RL]*  %{buildroot}%{_datarootdir}/%{name}

%files
%doc %{_datarootdir}/%{name}/README.md 
%doc %{_datarootdir}/%{name}/LICENSE
%{_bindir}/vhs

%changelog
* Fri Oct 24 2014 Simon A. Erat <erat.simon@gmail.com> 1.0.5
- Updated description

* Mon Oct 20 2014 Simon A. Erat <erat.simon@gmail.com> 1.0.4
- Initial package
