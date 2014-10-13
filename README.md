VHS
===

Video Handler Script by sea, using [ffmpeg](http://ffmpeg.org)

(This is a [demonstration script](http://github.com/sri-arjuna/vhs) for the use of [TUI](http://github.com/sri-arjuna/tui) - Text User Interface)



Intro
-----

This is a handler script and therefor it lets you generate a full valid ffmpeg-command, using alot fewer arguments due to the use of a config file.

Now since my TV doesnt support webm formated videos, i have to reencode many files (docs, howtos, guides) to a basic (main-target) container-extension, which would be Matroska (mkv) for my TV.

Its main goal is, to simplify the process of re-encoding a video using my custom (config file) preferences to the same name but changed file extension, increasing the added number if the file already exists.


Also i needed to save up some space, so the goal was set, make a script to:

* easy re-enconde inputfiles to a certain container
* reuse the codec info of diffrent containers,
* strip down audio streams to favorite ones, 
* automaticly (but toggable) downcode to stereo,
* remove subtitles unless told they shall be kept
* make a log file for easier debuging & code reuse
* make ffmpeg less verbose, so i can better find the filename its currently working on
	
	
	
On the road ffmpeg showed it had alot more functionality to offer:

* Screen recording
* Webcam recording
* 'Guide' recording, Screen with Webcam as picture in picture, orientation changable using (-p ARG) presets like: tl, br
* DVD encoding, but 'currently droped' due to issues of actualy doing so, and not beeing top priority


Reason
------

So for lazy people like me, i usualy just call the first line, rather than the second...

Using subtitles and use 'full' preset Quality *-Q RES*

	vhs -tQ fhd videofile
	ffmpeg -i "inputfile"  -strict -2  -map 0:0 -b:v 1664K -vf scale=1920x1080 -c:v libx264  -minrate 3328K -maxrate 3328K -bufsize 1664K  -b:a 256K -ac 2 -c:a ac3   -c:s ssa  -map 0:3  -map 0:1  "outputfile"


Or to record whats going on on my desktop

	vhs -S
	ffmpeg -f x11grab -video_size  1920x1080 -i :0 -f alsa -i default  -strict -2 -f mp4 "outputfile"



If you still want more output, there you go:

	# Script itself beeing verbose (not '-x' debug))
	vhs -V[options] [filename]
	
	# ffmpeg beeing verbose
	vhs -v[options] [filename]

	# To report a bug, please use these two (with the first one modified) lines:
	vhs -vV[youroptions] ["inputfile"]
	tail ~/.config/vhs/vhs.log


Examples
-----------

	vhs [/path/to/]file			# Encodes a specific file
	vhs *					# Encodes all files in current directory, using the sources bitrates
	vhs -b a128 -b v256 files		# Encode a video with given bitrates in kbytes
	vhs -B files				# Encode a video with default bitrates
	vhs -c vlibtheora -c alibvorbis files	# Encode a file with given codecs
	vhs -e XY files				# Encode a video with container XY rather than favorite
	vhs -w files				# Encode a video and move info flags in front (web/streaming)
	vhs -v files				# Encode a video and (ffmpeg) be verbose
	vhs -C files				# Copy streams - dont encode


Help-screen
-----------

	vhs (1.0.4) - Video Handler Script
	Usage: 		vhs [options] filename/s ...

	Examples:	vhs -C				| Enter the configuration/setup menu
			vhs -b a128 -b v512 filename	| Encode file with audio bitrate of 128k and video bitrate of 512k
			vhs -c aAUDIO -c vVIDEO -c sSUBTITLE filename	| Force given codecs to be used for either audio or video (NOT recomended, but as bugfix for subtitles!)
			vhs -e mp4 filename		| Re-encode a file, just this one time to mp4, using the input files bitrates
			vhs -[S|W|G]			| Record a video from Screen (desktop) or Webcam, or make a Guide-video placing the webcam stream as pip upon a screencast
			vhs -l ger			| Add this language to be added automaticly if found (applies to audio and subtitle (if '-t' is passed)
			vhs -Q fhd filename		| Re-encode a file, using the screen res and bitrate presets for FullHD (see RES info below)
			vhs -Bjtq fhd filename		| Re-encode a file, using the bitrates from the config file, keeping attachment streams and keep subtitle for 'default 2 languages' if found, then forcing it to a Full HD dimension

	Where options are: (only the first letter)
		-h(elp) 			This screen
		-b(itrate)	[av]NUM		Set Bitrate to NUM kilobytes, use either 'a' or 'v' to define audio or video bitrate
		-B(itrates)			Use bitrates (a|v) from configuration (/home/sea/.config/vhs/vhs.conf)
		-c(odec)	[av]NAME	Set codec to NAME for audio or video
		-C(onfig)			Shows the configuration dialog
		-d(imension)	RES		Sets to ID-resolution, keeps aspect-ratio (:-1) (will probably fail)
	(drop?)	-D(VD)				Encode from DVD
		-e(xtension)	CONTAINER	Use this container (ogg,webm,avi,mkv,mp4)
		-f(ps)		FPS		Force the use of the passed FPS
		-F(PS)				Use the FPS from the config file (25 by default)
		-G(uide)			Capures your screen & puts Webcam as PiP (default: top left @ 320), use -p ARGS to change
		-i(nfo)		filename	Shows a short overview of the video its streams
		-I(d)		NUM		Force this ID to be used (Audio-extraction, internal use)
		-j(pg)				Include the 'icon-image' if available
		-l(anguage)	LNG		Add LNG to be included (3 letter abrevihation, eg: eng,fre,ger,spa,jpn)
		-L(OG)				Show the log file
		-O(utputFile)	NAME		Forces to save as NAME, this is internal use for '-Ep 2|3'
		-p(ip)		LOCATION[NUM]	Possible: tl, tc, tr, br, bc, bl, cl, cc, cr ; optional appending (NO space between) NUM would be the width of the PiP webcam
		-q(uality)	RES		Encodes the video at ID's default resolution, might strech or become boxed
		-Q(uality)	RES		Sets to ID-resolution and uses (sea)'s prefered bitrates for that RES
		-r(ate)		48000		Values from 48000 to 96000, or similar
		-R(ate)				Uses the frequency rate from configuration (/home/sea/.config/vhs/vhs.conf)
		-S(creen)			Records the fullscreen desktop
		-t(itles)			Use default and provided langauges as subtitles, where available
		-T(imeout)	2m		Set the timeout between videos to TIME (append either 'm' or 'h' as other units)
		-v(erbose)			Displays encode data from ffmpeg
		-V(erbose)			Show additional info on the fly
		-w(eb-optimized)		Moves the videos info to start of file (web compatibility)
		-W(ebcam)			Record from webcam
		-x(tract)			Clean up the log file
		-X(tract)			Clean up system from vhs-configurations
		-y(copY)			Just copy streams, fake convert
		-z(sample)	 1:23[-1:04:45[.15]]	Encdodes a sample file which starts at 1:23 and lasts 1 minute, or till the optional endtime of 1 hour, 4 minutes, 45 seconds and 15 mili-seconds


	Info:
	------------------------------------------------------
	After installing codecs, drivers or plug in of webcam,
	it is highy recomended to update the list file.
	You can do so by entering the Setup dialog: vhs -C
	and select 'UpdateLists'.

	Values:
	------------------------------------------------------
	NUM:		Number for specific bitrate (ranges from 96 to 15536
	NAME:		See '/home/sea/.config/vhs/vhs.list' for lists on diffrent codecs
	RES:		Use '-q RES' if you want to keep the original bitrates, use '-Q RES' to use the shown bitrates here.
			* screen 1920x1080 	a192 v1280	(1min ~ 10.1 mb)
			* clip	320x240 	a128 v256	(1min ~  2.6 mb)
			* vhs	640x480 	a128 v512	(1min ~  4.3 mb, aka VGA)
			* dvd	720x576 	a192 v640	(1min ~  5.4 mb)
			* hdr	1280x720	a192 v1280	(1min ~ 10.1 mb, aka HD Ready)
			* fhd 	1920x1280	a256 v1664	(1min ~ 12.9 mb, aka Full HD)
			* 4k 	3840x2160	a384 v4096	(1min ~ 29.9 mb, aka 4k)
	CONTAINER (a):	aac ac3 dts mp3 wav
	CONTAINER (v):  mkv mp4 ogm webm
	VIDEO:		[/path/to/]videofile
	LOCATIoN:	tl, tc, tr, br, bc, bl, cl, cc, cr :: as in :: top left, bottom right, center center
	LNG:		A valid 3 letter abrevihation for diffrent langauges
	PASS:		2 3
	HRZ:		44000 *48000* 72000 *96000* 128000, but im no audio technician
	TIME:		Any positive integer, optionaly followed by either 's', 'm' or 'h'




	Files:		
	------------------------------------------------------
	Script:		~/.local/bin/vhs
	Config:		~/.config/vhs/vhs.conf
	Containers:	~/.config/vhs/containers
	Lists:		~/.config/vhs/vhs.list
	Log:		~/.config/vhs/vhs.log


Videoguide
----------

If you want a video guide, please acknowledge that i dont like to be recorded: [VHS - Playlist](https://www.youtube.com/playlist?list=PLLFcWWccyIef2wUuT-KUMzRdlvNj525mG)

