VHS - Installation
==================


The actual installation
-----------------------

__Minimalistic:__ 
Place the script in $HOME/bin and remove the __.sh__.

__Recomended:__
The files are quite easy to be placed.

At least the most essential one, which is the script itself, vhs.sh.
You can place it within any available $PATH, such as /bin, /usr/bin, /usr/local/bin, $HOME/bin or $HOME/.local/bin.

The manpage should be placed with your distros official manpage directories.
On Fedora that is in /usr/share/man/man1.

Now the most tricky file is the file for the bash completion.
That is only recomended if the shell you use is bash.

Anyway, on Fedora, you'd place it in /etc/bash_completion.d/

__Best:__
Is to use the rpm repositry so you get all the updates automaticly.
See: http://sea.fedorapeople.org/sea-devel.repo
Please that file in /etc/yum.repos.d/

First start
-----------

Upon first start, it will check for TUI (Text User Interface) and install it if required.
For this task it expected git or wget to be installed on your system.

Then it will write 5 files into $HOME/.config/vhs
*) container
*) presets
*) vhs.conf
*) urls.{play,stream}

__container__ provides a table of recomended codecs according to their container/file extension.
For example it takes ac3 & x265 for an mp4 container.
If your preference is different, you can change it within there.
Once that is implemented, if you build ffmpeg using vhs, or otherwise get your hands on a ffmpeg supporting h265, 
you can use my custom containers mp5 and mkv5, both preserving their original file extension, but using x265 instead of x264.

__presets__ provies a table with most suggested video resolutions and recomended bitrates according to their resolution.
All of the presets (first column 'quick access') are thought to use the lowest possible bitrate for the highest possible video quality.
The a-PRESETs are supposed to be used for animes or cartoons (as in 'drawn' not 'rendered'), not animated movies.
The yt-PRESETs are using the 'highest' bitrates, but giving a technicly lossless file, at maximum filesize.

__vhs.conf__ contains all the defaul values you never want to pass everytime, because its 'your' default.
This goes from default audio or video container, to your top most important stream source or target,
or the 2 default languages you want to presrve for video encoding, or if you want to downcode dts to stereo or not.
Please use __vhs -C__ and use the configuration screen.

__urls.{play,stream}__ contains the URLs which already been used to play or stream a stream.
It is recomended to use your most used URLs first, and place them on top of the file, so any below comment block gives you an easy divider for removable urls.