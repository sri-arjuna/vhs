VHS
===

Video Handler Script by sea, using [ffmpeg](http://ffmpeg.org)



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

	# To report a bug, please use the output of these two (with the first one modified) lines:
	vhs -vV[youroptions] ["inputfile"]
	tail ~/.config/vhs/vhs.log


Examples
-----------

	vhs [/path/to/]file				# Encodes a specific file
	vhs *							# Encodes all files in current directory, using the sources bitrates
	vhs -b a128 -b v256 files		# Encode a video with given bitrates in kbytes
	vhs -B files					# Encode a video with default bitrates
	vhs -c vlibtheora -c alibvorbis files	# Encode a file with given codecs
	vhs -e XY files					# Encode a video with container XY rather than favorite
	vhs -w files					# Encode a video and move info flags in front (web/streaming)
	vhs -v files					# Encode a video and (ffmpeg) be verbose
	vhs -C files					# Copy streams - dont encode
	vhs -U files					# Upstream passed files, to favorite upstream ID
	vhs -SU						# Upstream desktop, to favorite upstream ID
	vhs -vPU					# Play videostream from favorite playstream id
	vhs -Pu adress					# Play audio stream from adress

Help-screen
-----------

	vhs (2.0) - Video Handler Script
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
		-2(-pass)			Enabled 2 Pass encoding: Video encoding only (Will fail when combinied with -y (copy)!)
		-a(dd)		FILE		Adds the FILE to the 'add/inlcude' list, most preferd audio- & subtitle files (images can be only on top left position, videos 'anywhere' -p allows ; just either one Or the other at a time)
		-A(dvanced)			Will open an editor before executing the command
		-b(itrate)	[av]NUM		Set Bitrate to NUM kilobytes, use either 'a' or 'v' to define audio or video bitrate
		-B(itrates)			Use bitrates (a|v) from configuration (/home/sea/.config/vhs/vhs.conf)
		-c(odec)	[atv]NAME	Set codec to NAME for audio, (sub-)title or video, can pass '[atv]copy' as well
		-C(onfig)			Shows the configuration dialog
		-d(b)		VOL		Change the volume, eg: +0.5 or -1.3
		-D(VD)				Encode from DVD (not working since code rearrangement)
		-e(xtension)	CONTAINER	Use this container (ogg,webm,avi,mkv,mp4)
		-E(tra)		'STRING'	STRING can be any option to ffmpeg you want, understand that it is inserted right after the first input file!
		-f(ps)		FPS		Force the use of the passed FPS
		-F(PS)				Use the FPS from the config file (25 by default)
		-G(uide)			Capures your screen & puts Webcam as PiP (default: top left @ 320), use -p ARGS to change
		-i(nfo)		filename	Shows a short overview of the video its streams and exits
		-I(d)		NUM		Force this audio ID to be used (if multiple files dont have the language set)
		-j(pg)				Thought to just include jpg icons, changed to include all attachments (fonts, etc)
		-J(oin)				Appends the videos in passed order.
		-K(ill)				Lets you select the job to kill among currenlty running VHS jobs.
		-l(anguage)	LNG		Add LNG to be included (3 letter abrevihation, eg: eng,fre,ger,spa,jpn)
		-L(OG)				Show the log file
		-p(ip)		LOCATION[NUM]	Possible: tl, tc, tr, br, bc, bl, cl, cc, cr ; optional appending (NO space between) NUM would be the width of the PiP webcam
		-P(lay[-list])			Requires either '-u URL' or '-U', or be called 2 times to select the playlist history, pass -PPP to open the urls history file.
		-q(uality)	RES		Encodes the video at ID's bitrates from presets
		-Q(uality)	RES		Sets to ID-resolution and uses the bitrates from presets, video might become sctreched
		-r(ate)		48000		Values from 48000 to 96000, or similar
		-R(ate)				Uses the frequency rate from configuration (/home/sea/.config/vhs/vhs.conf)
		-S(creen)			Records the fullscreen desktop
		-t(itles)			Use default and provided langauges as subtitles, where available
		-T(imeout)	2m		Set the timeout between videos to TIME (append either 's', 'm' or 'h' as other units)
		-u(rl)		URL		Using URL as streaming target or source, use '-S|W|G' to 'send' or '-P' to play the stream.
		-U(rl)				Using the URL from the config file
		-v(erbose)			Displays encode data from ffmpeg
		-V(erbose)			Show additional info on the fly
		-w(eb-optimized)		Moves the videos info to start of file (web compatibility)
		-W(ebcam)			Record from webcam
		-x(tract)			Clean up the log file
		-X(tract)			Clean up system from vhs-configurations
		-y(copY)			Just copy streams, fake convert
		-z(sample)  1:23[-1:04:45[.15]	Encdodes a sample file which starts at 1:23 and lasts 1 minute, or till the optional endtime of 1 hour, 4 minutes and 45 seconds


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
	RES:		These bitrates are ment to save storage space and still offer great quality, you still can overwrite them using something like -b v1234.
			Use '-q LABEL' if you want to keep the original bitrates, use '-Q LABEL' to use the shown bitrates and aspect ratio below.
			Also, be aware that upcoding a video from a lower resolution to a (much) higher resolution brings nothing but wasted diskspace, but if its close to the next 'proper' resolution aspect ratio, it might be worth a try.
			See "/home/sea/.config/vhs/presets" to see currently muted ones or to add your own presets.

		Label	Resolution	Pixels	Vidbit	Audbit	Bitrate	1min	Comment
		a-vga	640x480 	307.20K	512	196	708.00k	5.2mb	Anime optimized, VGA     
		a-dvd	720x576 	414.72K	640	256	896.00k	6.6mb	Anime optimized, DVD-wide - PAL   
		a-hd	1280x720 	921.60K	768	256	1.02M	7.5mb	Anime optimized, HD     
		a-fhd	1920x1080 	2.07M	1280	256	1.54M	11.2mb	Anime optimized, Full HD    
		qvga	320x240 	76.80K	240	128	368.00k	2.7mb	Quarter of VGA, mobile devices   
		hvga	480x320 	153.60K	320	192	512.00k	3.8mb	Half VGA, mobile devices    
		nhd	640x360 	230.40K	512	256	768.00k	5.6mb	Ninth of HD, mobile devices   
		vga	640x480 	307.20K	640	256	896.00k	6.6mb	VGA       
		dvdn	720x480 	345.60K	744	384	1.13M	8.3mb	DVD NTSC      
		dvd	720x576 	414.72K	768	384	1.15M	8.4mb	DVD-wide - Pal     
		fwvga	854x480 	409.92K	768	384	1.15M	8.4mb	DVD-wide - NTCS, mobile devices   
		hd	1280x720 	921.60K	1280	384	1.66M	12.2mb	HD aka HD Ready    
		fhd	1920x1080 	2.07M	1920	384	2.30M	16.9mb	Full HD      
		qhd	2560x1440 	3.69M	3840	448	4.29M	31.4mb	2k, Quad HD - 4xHD   
		uhd	3840x2160 	8.29M	7680	512	8.19M	60.0mb	4K, Ultra HD TV    
		yt-240	426x240 	102.24K	768	196	964.00k	7.1mb	YT, seriously, no reason to choose  
		yt-360	640x360 	230.40K	1000	196	1.20M	8.8mb	YT, Ninth of HD, mobile devices  
		yt-480	854x480 	409.92K	2500	196	2.70M	19.7mb	YT, DVD-wide - NTCS, mobile devices  
		yt-720	1280x720 	921.60K	5000	512	5.51M	40.4mb	YT, HD      
		yt-1080	1920x1080 	2.07M	8000	512	8.51M	62.3mb	YT, Full HD     
		yt-1440	2560x1440 	3.69M	10000	512	10.51M	77.0mb	YT, 2k, Quad HD - 4xHD  
		yt-2160	3840x2160 	8.29M	40000	512	40.51M	296.7mb	YT, 4K, Ultra HD TV   

	CONTAINER (a):	aac ac3 dts flac mp3 ogg vorbis wav wma
	CONTAINER (v):  avi flv mkv mp4 mpeg ogv theora webm wmv xvid
	VIDEO:		[/path/to/]videofile
	LOCATION:	tl, tc, tr, br, bc, bl, cl, cc, cr :: as in :: top left, bottom right, center center
	LNG:		A valid 3 letter abrevihation for diffrent langauges
	HRZ:		44100 *48000* 72000 *96000* 128000
	TIME:		Any positive integer, optionaly followed by either 's', 'm' or 'h'

	For more information or a FAQ, please see man vhs.

	Files:		
	------------------------------------------------------
	Script:		/home/sea/.local/bin/vhs.sh
	Config:		/home/sea/.config/vhs/vhs.conf
	Containers:	/home/sea/.config/vhs/container
	Lists:		/home/sea/.config/vhs/vhs.list
	Log:		/home/sea/.config/vhs/vhs.log
	Presets:	/home/sea/.config/vhs/presets



Videoguide
----------

If you want a video guide, please acknowledge that i dont like to be recorded: [VHS - Playlist](https://www.youtube.com/playlist?list=PLLFcWWccyIef2wUuT-KUMzRdlvNj525mG)

	
Dependencies
------------

It expects bash and either wget with unzip or git to be already installed.
Bash-completion is optional but recomended.

To display properly, VHS depends on [TUI](http://github.com/sri-arjuna/tui), the Text User Interface.
This dependency is automaticly installed, if either git or wget and unzip are available.

FFMPEG, mkvtoolnix, v4l-tools are attempt to be installed with the package manager of your system, if reckognized by TUI.
For any codec or container you attempt to encode, even just the defaults set by VHS, is in your obligation to provide.
If your ffmpeg build does not support the task you want to achieve, you can build your own following the instructions on [ffmpeg.org](http://ffmpeg.org/general.html) and the [forum](http://ffmpeg.gusari.org/viewtopic.php?f=25&t=38)


Installation
------------

Only 3 files are to be installed, as root, place the files as (rename vhs.sh along):

	vhs.sh		/usr/bin/vhs
	vhs.1		/usr/share/man/man1/
	vhs_compl.bash	/etc/bash_completion.d/


Hope you like it as much as i do, enjoy :)