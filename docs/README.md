VHS
===

Video Handler Script by sea, using [ffmpeg](http://ffmpeg.org) and [TUI](https://github.com/sri-arjuna/tui)

Is it an audio extractor?
Is it a stream caster?
Is it a webradio player?
Is it a video converter?
Is it a video player?
Yes, and more!


Tabele of Content
-----------------
* Intro
* What it was...
* What does it do?
* Tools
* Examples : Command length
* Examples : Usage


Intro
-----

I'm a lazy guy, and eventhough i love the power of the console, one cannot remember/know all of the options and arguments of every tool there is.
This said, i wanted to make my use of ffmpeg a little easier.

What started as a simple script to mass-encode videos to save discspace, became a quite powerfull tool around ffmpeg.
It was never supposed to be, but now it is my favorite web radio player :D

Rather than typing a complex line of a single command, with the change of a letter, you can record from your webcam, your desktop or combine the both in a guide video.
Encoding files, automaticly increases a naming number, so no file gets overwritten.

Even for dvd encoding, for which it requires __vobcopy__ to be installed, in best case scenario, it reads the dvd its name, and uses that automaticly for the output name.


What it was...
--------------

Initialy, all i wanted was to have a script i could throw video files at,
and it would encode them:
* to my favorite codec
* with my favorite resolution
* at my favorite bitrates

At first i became quote busy just accomplishing that single task, and at some point, figured ffmpeg can encode vob files too.
So i then tried to include that, while trying that, figured ffmpeg could record from webcam, record the desktop and do streaming tasks too.


What it became...
-----------------
Well, at that point i had to do a partial rewrite of VHS to accomplish all the new tasks, which i certainly like.
By now, for my needs it replaces:
* ogmrip (dvd-ripper)
* {gtk|qt-}recordMyDesktop (screenrecording)
* Rythmbox (which i just used to listen webradio)
* totem/vlc (to play videos/music - music even in multiuser.stage)

So if you are aiming for an OS with as less possible packages/space usage, VHS is the way to go!
While these named packages themself just require like ~20 mb, their dependencies grow quickly to aprox around 150mb pulling a quite amount of libs with them.


What does it do?
----------------
All the features below can be quick access'ed by simply passing 1 option to vhs, and if required the input files of concern.
*	Make ffmpeg silent, as it expects the commands to work properly
*	Encode files to save space.
*	Rearange audio streams
*	Extract time segments or just samples (1min)
*	Extract audio / subtitle
*	Add audio or subtitle stream
*	Add another video stream as pip (there are presets for orientation)
*	Join/concat audio or video files
*	Enable, Remove or rearange subtitles
*	Stream/Record Webcam
*	Stream/Record Desktop
*	Stream/Record Guide (the two above, webcam as pip)
*	Streamserver, Audio or Video
*	Streamplayer, Audio or Video
*	Make a backup of your DVD


Tools
-----
Recently i've added some handy tools.

__vhs calc__ ___[cd|dvd|br #files ~#min]___

__vhs calc__ Would start the tool, and ask you for the storage device, the amount of files, and their average playtime.
__vhs calc dvd 32 20__ Does pass all that information on the call and just prints the result.

__vhs ip__ Simply prints your external (wan) and internal (lan) IP adresses.

IN-PLANNING __vhs build-ffmpeg [CHROOT]__ Will pull in all source code and compile ffmpeg pulling in as many possible features as possible.
CHROOT by default will be $HOME/.local, during compilation, the PREFIX will then be $CHROOT/usr -> $HOME/.local/usr.


Examples : Command length
-------------------------

So for lazy people like me, i usualy just call the first line, rather than the second...

Using subtitles and use 'full' preset Quality *-Q RES*

	vhs -tQ fhd inputfile
	ffmpeg -i "inputfile"  -strict -2  -map 0:0 -b:v 1664K -vf scale=1920x1080 -c:v libx264  -minrate 3328K -maxrate 3328K -bufsize 1664K  -b:a 256K -ac 2 -c:a ac3   -c:s ssa  -map 0:3  -map 0:1  "outputfile"


Or to record whats going on on the desktop

	vhs -S
	ffmpeg -f x11grab -video_size  1920x1080 -i :0 -f alsa -i default  -strict -2 -f mp4 "outputfile"

Or even take the desktop as background, and the webcam as a pip-overlay (orient- and sizeable):

	vhs -Gp br480
	ffmpeg -f v4l2 -s 1280x720 -framerate 25 -i /dev/video0  -f x11grab -video_size  1920x1080 -framerate 25 -i :0 -f alsa -i default -filter_complex '[0:v:0] scale=480:-1 [a] ; [1:v:0][a]overlay=1440:main_h-overlay_h-0' -c:v libx264 -crf 23 -preset veryfast -c:a ac3 -q:a 4  -strict -2  "/home/sea/mm/vid/guide-out.8.mkv"
	

Examples : Usage
----------------

	vhs [/path/to/]file				# Encodes a specific file
	vhs *							# Encodes all files in current directory
	vhs -b a128 -b v256 files		# Encode a video with given bitrates in kbytes
	vhs -B files					# Encode a video with default bitrates (vhs.conf)
	vhs -c vlibx265 -c alibfaac files	# Encode a file with given codecs
	vhs -e XY files					# Encode a video with container XY rather than favorite from vhs.conf
	vhs -w files ...					# Encode a video and move info flags in front (web/streaming)
	vhs -v files ...					# Encode a video and (ffmpeg) be verbose (good to see why it failed)
	vhs -y files ...					# Copy streams - dont encode
	vhs -U files ...					# Upstream passed files, to favorite upstream ID (urls.stream)
	vhs -SU						# Upstream desktop, to favorite (default) upstream ID
	vhs -vPU					# Play videostream from your most favorite (default) playstream id (vhs.conf)
	vhs -vPP					# Play videostream from one of the prevously played streams (urls.play)
	vhs -Pu adress					# Play audio stream from adress (urls.play)

Debuging:
---------

There are times where the default settings, generated command, does not work.
If that happens, you might want to change to verbose mode (-v) to get the error message produced by ffmpeg.
There is also a chance to modify the generated command before it gets executed by passing _-A_.

If you still want more output, there you go:

	# Script itself beeing verbose (not '-x', but still debug))
	vhs -V[options] [filename]
	
	# ffmpeg beeing verbose
	vhs -v[options] [filename]

	# To report a bug, please use the output of these two (with the first one modified) lines:
	vhs -vV[youroptions] ["inputfile"]
	tail ~/.config/vhs/vhs.log
