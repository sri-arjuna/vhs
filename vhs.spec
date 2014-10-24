Name:           vhs
Version:        1.0.5
Release:        0%{?dist}
Summary:        Video Handler Script

License:        GPL v3
URL:            https://github.com/sri-arjuna/vhs
Source0:        vhs.tar.gz

Requires:       tui
Requires:       ffmpeg
Requires:       mkvtoolnix
Requires:       v4l-tools

#Requires:       ogmtools
#Requires:       oggvideotools
#Requires:       theora-tools
#Requires:       vorbis-tools
#Requires:       speex-tools
#Requires:       swftools
#Requires:       mjpegtools
#Requires:       libdvdcss

%description
A Script to handle diffrent multimedia tasks.
* Re-encode existing videos
* Capture webcam
* Capture desktop
* Capture webcam as PiP over desktop
* Extract audio stream from video files
* Include audio-, subtitlestreams
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

mv %{name}/vhs.sh %{buildroot}%{_bindir}/vhs
mv vhs/[RL]*  %{buildroot}%{_datarootdir}/%{name}

%files
%doc %{_datarootdir}/%{name}/README.md 
%doc %{_datarootdir}/%{name}/LICENSE
%{_bindir}/vhs

%changelog
* Mon Oct 20 2014 Simon A. Erat <erat.simon@gmail.com>
- Initial package
