#!/usr/bin/env bash
# ------------------------------------------------------------------------
#
# Copyright (c) 2014-2015 by Simon Arjuna Erat (sea)  <erat.simon@gmail.com>
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
#-----------------------------------------------
#
#
#	File:		vhs
#	Author: 	Simon Arjuna Erat (sea)
#	Contact:	erat.simon@gmail.com
#	License:	GNU General Public License (GPL3)
#	Created:	2014.05.18
#	Changed:	2015.05.24
#	Description:	All in one video handler, wrapper for ffmpeg
#			Simplyfied commands for easy use
#			The script is designed (using the -Q toggle) use create the smallest files with a decent quality
#			
#	Resources:	http://ffmpeg.org/index.html
#			https://wiki.archlinux.org/index.php/FFmpeg
#			https://support.google.com/youtube/answer/1722171?hl=en&ref_topic=2888648
#			users of #ffmpeg on freenode.irc
#
#
# This script requires TUI - Text User Interface
# See:		https://github.com/sri-arjuna/tui
#
#	Check if TUI is installed...
#
	if [ ! -f "$(which tui)" ]
	then 	[ ! 0 -eq $UID ] && \
			printf "\n#\n#\tPlease restart the script as root to install TUI (Text User Interface).\n#\n#\n" && \
			exit 1
		if ! git clone https://github.com/sri-arjuna/tui.git /tmp/tui.inst
		then 	mkdir -p /tmp/tui.inst ; cd /tmp/tui.inst/
			curl --progress-bar -L https://github.com/sri-arjuna/tui/archive/master.zip -o master.zip
			unzip master.zip && rm -f master.zip
			mv tui-master/* . ; rmdir tui-master
		fi
    		cd /tmp/tui.inst || exit 1
    		echo "Installing to default location."
		sleep 1.5
		./configure --prefix=/usr
		./make-install
		#make && make install && [ -f /share/info/tui.info ] && ln -sf /share/info/tui.info /usr/share/info/tui.info || exit 1
		#! ./install.sh || exit 1
	fi
	source tuirc
#fix
#	Get XDG Default dirs
#
	X="$HOME/.config/user-dirs.dirs"
	[ -f "$X" ] && source "$X" || tui-status $? "Missing XDG default dirs configuration file, using: $HOME/Videos"
	# Setting default videos dir and create it if none is present
	[ -z "$XDG_VIDEOS_DIR" ] && XDG_VIDEOS_DIR="$HOME/Videos" && ( [ -d "$XDG_VIDEOS_DIR" ] || tui-bol-dir "$XDG_VIDEOS_DIR" )
#
#	Script Environment
#
	ME="${0##*/}"				# Basename of $0
	ME_DIR="${0/\/$ME/}"			# Cut off filename from $0
	ME="${ME/.sh/}"				# Cut off .sh extension
	script_version=2.5.1
	TITLE="Video Handler Script"
	CONFIG_DIR="$HOME/.config/$ME"		# Base of the script its configuration
	CONFIG="$CONFIG_DIR/$ME.conf"		# Configuration file
	CONTAINER="$CONFIG_DIR/container"
	PRESETS=$CONFIG_DIR/presets             # Contains a basic table of the presets
        LOG="$CONFIG_DIR/$ME.log" 		# If a daily log file is prefered, simply insert: -$(date +'%T')
	LIST_FILE="$CONFIG_DIR/$ME.list"	# Contains lists of codecs, formats
	[ -z "$TUI_TEMP_DIR" ] && TUI_TEMP_DIR="$HOME/.cache/" && mkdir -p "$HOME/.cache"
	TMP_DIR="$TUI_TEMP_DIR"			# Base of possible temp files
	TMP="$TMP_DIR/$ME.tmp"			# Direct tempfile access
	
	# Get basic container, set to open standard if none exist
	[ -f "$CONFIG" ] && container=$(tui-conf-get "$CONFIG" "container") || container=webm
	# Create temp directory if not existing
	[ -d "$TMP_DIR" ] || mkdir -p "$TMP_DIR"
	# Create configuration directory if not existing
	[ -d "$CONFIG_DIR" ] || mkdir -p "$CONFIG_DIR"
#
#	Requirements
#
	req_dvd="vobcopy libdvdread"
	req_webcam="v4l-utils"
	req_file_editors="mkvtoolnix"
	REQUIRES="ffmpeg $req_dvd $req_webcam $req_file_editors"
#
#	Defaults for proper option catching, do not change
#
	# BOOL's
	ADDED_VIDEO=false		# Toggle if a video/-stream is added
	ADVANCED=false			# Open the tempfile before executing?
	showFFMPEG=false		# -v 	Debuging help, show the real encoder output
	beVerbose=false			# -V 	Show additional steps done
	doCopy=false			# -y	Just set all stream codecs to copy
	doJoin=false			# -J	Joins all the passed video files
	doPlay=false			# -P	requires -U|[u URL]
	PlayFilesShown=false		# Show playing file title just once
	PlayFile=true			# In stream checks, make sure if its play file or stream
	VideoInfoShown=false		# Show playback info for videos just once
	doSelect=false			# -[PP|UU] Show selection menu for either one
	doStream=false			# -U|u, unless -P is passed, requres one of -G|S|W or a file
	doExternal=false		# -E
	doZone=false			# -S required
	override_audio_codec=false	# -c a	/ -C	User passed codec
	override_sub_codec=false	# -c t	/ -C	''
	override_video_codec=false	# -c v	/ -C	''
	override_container=false	# -e ext
	useFPS=false			# -f / -F
	useRate=false			# -R
	useSubs=false			# -t
	useJpg=false			# -j		Now: Copy all streams
	codec_extra=false		# Depends on container /file extension
	file_extra=false		# Depends on container /file extension
	# Values - 
	MODE=video			# -D, -W, -S, -e AUDIO_EXT	audio, dvd, webcam, screen, guide
	ADDERS=""			# Stream to be added / included
	cmd_all=""
	#cmd_data=""			# Actualy, ffmpeg uses the datastream by default.
	cmd_audio_all=""		# These cmd_XY_all commands contain
	cmd_audio_maps=""		# the presets for all the files passed
	cmd_audio_rate=""		# This counts for audio, video
	cmd_input_all=""		#  enconand upstreaming
	cmd_output_all=""
	cmd_subtitle_all=""
	cmd_video_all=""
	optLogVerb=""
	langs=""			# -l LNG 	will be added here
	PASS=1				# -p 		toggle multipass video encoding, also 1=disabled
	RES=""				# -q|Q		dimension will set video resolution if provided
	OF=""				#		Empty: Output File
	VOL=""				# -d VOL
	ffmpeg_silent="ffmpeg -v quiet" # [-V]		Regular or debug verbose
	ffmpeg_verbose="ffmpeg -v verbose"	# -v		ffmpeg verbose
	FFMPEG="$ffmpeg_silent"		# Setting default
	hwaccel="-hwaccel vdpau"	# NOT USED -H		Enable hw acceleration
	txt_mjpg=""
	FPS_ov=""			# -f NUM -- string check
	SS_START=""			# -z 1:23[-1:04:45.15] start value, triggered by beeing non-empty
	SS_END=""			# -z 1:23[-1:04:45.15] calculated end value
	TIMEFRAME=""			# the codesegment containg the above two variables.
	EXTRA_CMD=""
	# Default overlays
	guide_complex="'[0:v:0]scale=320:-1[a] ; [1:v:0][a]overlay'"
	video_overlay="'[X:v:0]scale=320:-1[a] ; [0:v:0][a]overlay'"
	# Advanced usage
	[ -z "$showHeader" ] && showHeader=true
	URL_UP=""
	URL_PLAY=""
	URLS="$CONFIG_DIR/urls"
	#LS=$(locate ls|$GREP bin/ls$|head -n1)
	count_P=0
	count_U=0
	# Figured an average webradio url has like 67 chars.... * 3 =~ 180-210
	WIDTH=${COLUMNS:-$(tput cols)}
	if [ $WIDTH -le  100 ]		# This check sets the variable used by tui-select when selecting from urllist
	then	intPlayRows="-1"	# 1 or less
	elif [ $WIDTH -le  200 ]
	then	intPlayRows="-2"	# 2 or less
	else	intPlayRows=""		# Its wider, so use all 3 colums
	fi
#
#	Check for PRESETS, required for proper help display
#
	WritePresetFile() { #
        # Write a basic table of the presets
        # 
		touch "$PRESETS"
		cat > "$PRESETS" <<-EOF
		# Presets 'RES' configuration, there must be no empty line or output will fail.
		# Label	Resolution 	Vidbit	Audbit	Comment	(Up to 7 elements/words)
		scrn	resolve 	1024	256	This is only used for screenrecording
		a-hvga	  480x320	320	192	Lower bitrate for Animes and Cartoons
		a-nhd	  640x360	512	192	Lower bitrate for Animes and Cartoons
		a-vga	  640x480	512	196	Lower bitrate for Animes and Cartoons
		a-dvd	  720x576	640	256	Lower bitrate for Animes and Cartoons
		a-hd	 1280x720	768	256	Lower bitrate for Animes and Cartoons
		a-fhd	1920x1080	1280	256	Lower bitrate for Animes and Cartoons
		qvga	  320x240	240	128	Quarter of VGA, mobile devices 
		hvga	  480x320	320	192	Half VGA, mobile devices
		ntsc	  440×486	320	192	TV - NTSC 4:3
		pal	  520×576	480	192	TV - PAL 4:3
		nhd	  640x360	512	192	Ninth of HD, mobile devices
		vga	  640x480	640	192	VGA
		dvdn	  720x480	744	256	DVD NTSC
		dvd	  720x576	768	256	DVD-wide - Pal
		fwvga	  854x480	768	256	DVD-wide - NTCS, mobile devices
		hdr	 1280x720	1280	256	HD Ready
		hd	1920x1080	1920	256	Full HD
		HD	1920x1080	2560	384	Full HD
		qhd	2560x1440	3840	384	2k, Quad HD - 4xHD
		uhd	3840x2160	7680	512	4K, Ultra HD TV
		# Below are presets which fail (freeze!) on my machine.
		# Feel free to uncomment the below 4 lines at your own risk.
		#uhd+	5120x2880	14400	768	5K, UHD+
		#fuhd	7680x4320	32160	1280	8K, Full UHD TV
		#quhd	15360x8640	128720	1280	16k, Quad UHD - 4xUHD
		#ouhd	30720x17380	512000	2048	32k, Octo UHD - 8xUHD, my suggestion
		#
		# It is strongly recomended to NOT modify the youtube preset bitrates or resolutions, as they are set that high to meet google its standard.
		# Saying, whatever video quality you pass to youtube, it will be re-encoded with these values.
		# So it is best to provide a source as high as that (selected resolution, 'upscale' does not work, it increases filesize only)
		# For more details see:	https://support.google.com/youtube/answer/1722171?hl=en
		#
		yt-240	  426x240	768	196	YT, seriously, no reason to choose
		yt-360	  640x360	1000	196	YT, Ninth of HD, mobile devices
		yt-480	  854x480	2500	196	YT, DVD-wide - NTCS, mobile devices
		yt-720	 1280x720	5000	512	YT, HD
		yt-1080	1920x1080	8000	512	YT, Full HD
		yt-1440	2560x1440	10000	512	YT, 2k, Quad HD - 4xHD
		yt-2160	3840x2160	40000	512	YT, 4K, Ultra HD TV
		EOF
		tui-status $? "Wrote presets in:" "$PRESETS"
	}
	WriteContainerFile() { #
	# This writes the default contaienrs, note that ffmpeg must be build 
	# against the according codecs and libraries. --> vhs build-ffmpeg
		touch "$CONTAINER"
		cat > "$CONTAINER" <<-EOF
		# VHS ($script_version) container file
		# Use '-' for an empty codec
		# STRICT true 	= 	-strict -2
		# FILE true 	= 	-f EXT
		#
		# LABEL	EXT	STRICT	FILE	AUDIO		VIDEO
		# - Audio -
		aac	aac	true	false	aac		-
		ac3	ac3	false	false	ac3		-
		dts	dts	false	false	dts		-
		flac	flac	false	false	flac		-
		m4a	m4a	false	false	mp4als		-
		mp3	mp3	false	false	libmp3lame	-
		ogg	ogg	false	false	libvorbis	-
		wma	wma	false	true	wmav2		-
		wav	wav	false	false	pcm_s16le	-
		# - Video with Audio -
		avi	avi	false	true	wmav1		msvideo1		
		flv	flv	false	false	adpcm_swf	flv
		mp4	mp4	true	true	mp4als		libx264
		mpeg	mpeg	false	false	mp2fixed	mpeg2video
		mkv	mkv	false	false	ac3		libx264
		ogv	ogv	true	false	libvorbis	libtheora
		webm	webm	true	true	libvorbis	libvpx
		wmv	wmv	false	false	wmav2		wmv2
		xvid	avi	false	true	libmp3lame	libxvid
		# - Special containers : Streaming -
		mpegts	mpeg	false	false	mp2fixed	mpeg2video
		#
		# Place here your custom/new containers
		#
		# LABEL	EXT	STRICT FILE	AUDIO		VIDEO
		mk5	mkv	false 	false	ac3		libx265
		mp5	mp4	true	true	libfdk_aac	libx265
		
		EOF
		tui-status $? "Wrote containers in:" "$CONTAINER"
	}
	[ -f "$PRESETS" ] 	|| WritePresetFile
	[ -f "$CONTAINER" ] 	|| WriteContainerFile
#
#	Help text
#
	BOLD="$TUI_FONT_BOLD"
	RESET="$TUI_COLOR_RESET"
	help_text="
$ME ($script_version) - ${TITLE^}
Usage: 		$ME [options] filename/s ...

${BOLD}${TUI_FONT_UNDERLINE}Examples:${RESET}	$ME -C				| Enter the configuration/setup menu
		$ME -b ${BOLD}a${RESET}128 -b ${BOLD}v${RESET}512 filename	| Encode file with audio bitrate of 128k and video bitrate of 512k
		$ME -c ${BOLD}a${RESET}AUDIO -c ${BOLD}v${RESET}VIDEO -c ${BOLD}s${RESET}SUBTITLE filename	| Force given codecs to be used for either audio or video (NOT recomended, but as bugfix for subtitles!)
		$ME -e mp4 filename		| Re-encode a file, just this one time to mp4, using the input files bitrates
		$ME -[S|W|G]			| Record a video from Screen (desktop) or Webcam, or make a Guide-video placing the webcam stream as pip upon a screencast
		$ME -l ger			| Add this language to be added automaticly if found (applies to audio and subtitle (if '-t' is passed)
		$ME -Q fhd filename		| Re-encode a file, using the screen res and bitrate presets for FullHD (see RES info below)
		$ME -Bjtq fhd filename		| Re-encode a file, using the bitrates from the config file, keeping attachment streams and keep subtitle for 'default 2 languages' if found, then forcing it to a Full HD dimension

${BOLD}${TUI_FONT_UNDERLINE}Where options are:${RESET} (only the first letter)
	-h(elp) 			This screen
	-2(-pass)			Enabled 2 Pass encoding: Video encoding only (Will fail when combinied with -y (copy)!)
	-a(dd)		FILE		Adds the FILE to the 'add/inlcude' list, most preferd audio- & subtitle files (images can be only on top left position, videos 'anywhere' -p allows ; just either one Or the other at a time)
	-A(dvanced)			Will open an editor before executing the command
	-b(itrate)	[av]NUM		Set Bitrate to NUM kilobytes, use either 'a' or 'v' to define audio or video bitrate
	-B(itrates)			Use bitrates (a|v) from configuration ($CONFIG)
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
	-P(lay)		-[PUu]|FILE	Requires either '-u URL','-P|U' or a file as argument
	-PP				Select the url playlist history
	-PPP 				Open the urls history file.
	-q(uality)	RES		Encodes the video at ID's bitrates from presets
	-Q(uality)	RES		Sets to ID-resolution and uses the bitrates from presets, video might become sctreched
	-r(ate)		48000		Values from 48000 to 96000, or similar
	-R(ate)				Uses the frequency rate from configuration ($CONFIG)
	-s(cale)	RES		Expects RES to be in form/kind of either one: ${BOLD}1600x900$RESET or ${BOLD}hd$RESET
	-S(creen)			Records the fullscreen desktop
	-t(itles)			Use default and provided langauges as subtitles, where available
	-T(imeout)	2m		Set the timeout between videos to TIME (append either 's', 'm' or 'h' as other units)
	-u(rl)		URL		Using URL as streaming target or source, use '-S|W|G' to 'send' or '-P' to play the stream.
	-U(rl)				Using the URL from the config file, 
	-UU				Select among already used upstream urls
	-v(erbose)			Displays encode data from ffmpeg
	-V(erbose)			Show additional info on the fly
	-w(eb-optimized)		Moves the videos info to start of file (web compatibility)
	-W(ebcam)			Record from webcam
	-x(tract)			Clean up the log file
	-X(tract)			Clean up system from $ME-configurations
	-y(copY)			Just copy streams, fake convert
	-Z(one) TOP LEFT WIDTH HEIGHT	Only record this zone of the screen
	-z(sample)  1:23[-1:04:45[.15]	Encdodes a sample file which starts at 1:23 and lasts 1 minute, or till the optional endtime of 1 hour, 4 minutes and 45 seconds

${BOLD}${TUI_FONT_UNDERLINE}Tools:${RESET}
VHS now comes with some small additional tools built in.
Invoke ${BOLD}vhs calc${RESET} to calculate the best bitrates if you want to match multiple files onto one storage device.
You can pass arguments to it: ${BOLD}[cd|dvd|br] [#files] [avrg:duration]${RESET}
Also, to play and recieve streams, ${BOLD}vhs [my]ip${RESET} will print ip's you could use.

${BOLD}${TUI_FONT_UNDERLINE}Info:${RESET}
After installing codecs, drivers or plug in of webcam,
it is highy recomended to update the list file.
You can do so by entering the Setup dialog: $ME -C
and select 'UpdateLists'.

${BOLD}${TUI_FONT_UNDERLINE}Values:${RESET}
NUM:		Number for specific bitrate (ranges from 96 to 15536
NAME:		See '$LIST_FILE' for lists on diffrent codecs
RES:		These bitrates are ment to save storage space and still offer great quality, you still can overwrite them using something like ${BOLD}-b v1234${RESET}.
		Use '${BOLD}-q${RESET} LABEL' if you want to keep the original bitrates, use '${BOLD}-Q${RESET} LABEL' to use the shown bitrates and aspect ratio below.
		Also, be aware that upcoding a video from a lower resolution to a (much) higher resolution brings nothing but wasted diskspace, but if its close to the next 'proper' resolution aspect ratio, it might be worth a try.
		See \"$BOLD$PRESETS$RESET\" to see currently muted ones or to add your own presets.

$( 
	printf "\t${TUI_FONT_UNDERSCORE}Label	Resolution	Pixels	Vidbit	Audbit	Bitrate	1min	30mins	Comment$RESET\n"
	
	$AWK	'BEGIN  {
			# Prepare Unit arrays
				split ("k M GB", BUNT)
				split ("p K M Gp", PUNT)
				split ("mb gb tb pb", MUNT)
				ln10=log(10)
			}
		# Format input: Number Unit
		function FMT(NBR, U)
			{
				XP=int(log(NBR)/ln10/3)
				return sprintf ("%.2f%s", NBR / 10^(3*XP), U[1+XP])
			}
		function FRMT(NBR, U)
			{
				XP=int(log(NBR)/ln10/3)
				return sprintf ("%.1f%s", NBR / 10^(3*XP), U[1+XP])
			}
		NR==1 ||
		/^#/ ||
		/^scrn/ { next }
		{
		# Bitrates
			bitrate = FMT($3+$4, BUNT)
			byterate = (($3+$4)/8*60)
			megabytes = FRMT(byterate/1024,MUNT)
			#timed = 
			halfhour = FRMT(byterate/1024*30,MUNT)
			if("B" == U) {
					split(bitrate,B,".")
					bitrate=B[1]
				}
		# Pixels
			split($2, A, "x")
			pixels = FMT(A[1] * A[2], PUNT);
		# Output
			print "\t"BOLD$1RESET,$2 " ",pixels, $3 ,$4, bitrate, megabytes , halfhour, $5" "$6" "$7" "$8" "$9" "$10" "$11" "$12
	}' BOLD="\033[1m" RESET="\033[0m" OFS="\t" "$PRESETS"
)

CONTAINER (a):	aac ac3 dts flac mp3 ogg vorbis wav wma
CONTAINER (v):  avi flv mkv mp4 mpeg ogv theora webm wmv xvid
VIDEO:		[/path/to/]videofile
LOCATION:	tl, tc, tr, br, bc, bl, cl, cc, cr :: as in :: top left, bottom right, center center
LNG:		A valid 3 letter abrevihation for diffrent langauges
HRZ:		44100 *48000* 72000 *96000* 128000
TIME:		Any positive integer, optionaly followed by either 's', 'm' or 'h'

For more information or a FAQ, please see ${BOLD}man vhs${RESET}.

${BOLD}${TUI_FONT_UNDERLINE}Files:${RESET}
Script:		$0
Config:		$CONFIG
URLS:		$URLS.{play,stream}
Log:		$LOG
Containers:	$CONTAINER
Lists:		$LIST_FILE
Presets:	$PRESETS

"
#
#	Functions
#
	doLog() { # "MESSAGE STRING"
	# Prints: Time & "Message STRING"
	# See 'tui-log -h' for more info
		tui-log -t$optLogVerb "$LOG" "$1"
	}
	StreamInfo() { # VIDEO
	# Returns the striped down output of  ffmpeg -psnr -i video
	# Highly recomend to invoke with "vhs -i VIDEO" then use "$TMP.info"
		LC_ALL=C ffmpeg  -psnr -i "${1:-$video}" 1> "$TMP.info" 2> "$TMP.info"
		$GREP -i stream "$TMP.info" | $GREP -v @ | $GREP -v "\--version"
		LC_ALL=""
		export LC_ALL
	}
	FileSize() { # FILE
	# Returns the filesize in bytes
	#
		$LS -l "$1" | $AWK '{print $5}'
	}
	LoadContainer() { # CONTAINER
	# Loads a given container into environment
	#
		[ -z "$1" ] && echo "LoadContainer: Requires a CONTAINER" && return 1
		LINE=$($GREP -v ^"#" "$CONTAINER"|$GREP "$1")
		[ -z "$LINE" ] && return 1
		echo "$LINE" | while read lbl E c f a v
			do	cat > "$TUI_FILE_TEMP" <<-EOF
				ext=$E
				codec_extra=$c
				file_extra=$f
				audio_codec="${a/-/}"
				video_codec="${v/-/}"
				EOF
				#echo "Loop: $EXT / $E - $audio_codec / $a - $codec_extra / $c"
				break
			done
		source "$TUI_FILE_TEMP"
		export ext codec_extra file_extra audio_codec video_codec
		echo "" >  "$TUI_FILE_TEMP"
	}
	fs_expected() { #
	# Returns the expected filesize in bytes
	#
		pr_str() {
			ff=$(cat $TMP.info)
			d="${ff#*bitrate: }"
			echo "${d%%,*}" | $AWK '{print $1}' | head -n 1
		}
		[ -z "$BIT_AUDIO" ] && BIT_AUDIO=0
		[ -z "$BIT_VIDEO" ] && BIT_VIDEO=0
		RATE=$(( $BIT_AUDIO + $BIT_VIDEO ))
		if [ 0 -eq $RATE ]
		then	t_BYTERATE=$(( $(pr_str) * 1024 / 8 ))
		else	t_BYTERATE=$(( $RATE / 8 ))
		fi
		[ ! "" = "$(echo $t_BYTERATE|tr -d [[:digit:]])" ] && echo 0 && return 1
		t_TIMES=$( PlayTime | $SED s,":"," ",g)
		echo "${t_TIMES}" | $AWK '{ printf "%.0f\n", ( ($1*60*60 + $2*60 + $3) * BYTES / 4.2 * 3.1 )}' BYTES=$t_BYTERATE
		return $?
	}
	bit_calculator()  { # ITEM COUNT DURATION
	# Trying to calculate suggested bitrates,
	#  according to storage size and amount of files.
		
	#
	#	Variables
	#
		def_STOR=dvd	# The general storage
		def_COUNT=20	# Spread among this many files
		def_AVRG=45	# Of which each plays about this many minutes
		SIZE=""		# Leave empty to start
	#
	#	Functions
	#
		storage_size() { # ITEM
		# Returns the filesize of a storage device
		# A little bit less to be sure
			case "$item" in
			cd)	def_size=680	;;
			dvd)	def_size=4400	;;
			br)	def_size=29000	;;
			other)	def_size=$(tui-read "What is the available storage size?")	;;
			esac
			echo $def_size
			return 0
		}
	#
	#	Action & Display
	#
		tui-title "Bitrate calculator"
		[ -z "$1" ] && \
			tui-echo "What is the storage?" && \
			item=$(tui-select cd dvd br other) || \
			item="$1"
		case "$item" in
		other)	SIZE=$(tui-read "Please type the size in numbers:")
			;;
		*)	[ -z "$SIZE" ] && SIZE=$(storage_size "$item")
			;;
		esac
		[ -z "$2" ] && \
			COUNT=$(tui-read "How many files? ($def_COUNT)") || \
			COUNT="$2"
		[ -z "$COUNT" ] && COUNT=$def_COUNT

		[ -z "$3" ] && \
			AVRG=$(tui-read "What is the average duration in minutes? ($def_AVRG)") || \
			AVRG="$3"
		[ -z "$AVRG" ] && AVRG=$def_AVRG
		
		# Size per file
		SF=$(echo "$SIZE $COUNT" | $AWK '{print int ($1*1024/$2)}')
		# Size per minue
		SM=$(echo "$SF $AVRG" | $AWK '{print int ($1/$2)}')
		# Size per second
		SS=$(echo "$SM 60" | $AWK '{print int ($1/$2)}')
		# Bytes per second
		BS=$(echo "$SS 8" | $AWK '{print int ($1*$2)}')
		# Audio Bit
		AB=$(echo $BS | $AWK '{print int ($1/4)}')
		# Video Bit
		if [ $AB -gt 768 ]
		then	VB=$(echo $AB | $AWK '{print int ($1*4-768)}')
			AB=768
		elif [ $AB -gt 512 ]
		then	VB=$(echo $AB | $AWK '{print int ($1*4-512)}')
			AB=512
		else	VB=$(echo $AB | $AWK '{print int ($1*3)}')
		fi
		
		tui-title "Suggested rates"
		tui-echo "Filesize to achieve:"	"$SF kbytes per file" #| -- comments refer to last output line
		tui-echo "Size per minute"	"$SM kbytes" #| $BS * 8 	= Byterate per second
		tui-echo "Total bitrate:" 	"$BS kbit/s" #| ^ * 60 * AVRG 	= Byterate per file
		tui-echo "Audio (suggestion):"	"$AB kbit/s" #| ^ * $COUNT 	= Byterate total
		tui-echo "Video (suggestion):"	"$VB kbit/s" #|	^ / 1024 	= kilobytes total
	}
	myIp() { # 
	# Simply prints internal and external IP using http://www.unix.com/what-is-my-ip.php
	#
		tui-title "My IP's"
		URL=http://www.unix.com/what-is-my-ip.php
		#for i in $(lynx -dump "$URL" | awk '/DNS Lookup For/ {print $NF}');do
		#	tui-echo "External:" "$i"
		#done
		
		
		DATA=$(curl -s $URL) > /dev/zero
		str="DNS Lookup For"
		tui-echo "External" "$(echo "$DATA" | sed s,"$str","\n\n$str",g  | sed s,"<"," ",g|grep "$str" | awk '{print $4}')"
		
		for i in $(ifconfig | awk -F" " '/netmask / {print $2}');do
			tui-echo "Internal:" "$i"
		done
		return $?
		#DATA=$(curl -s $URL) > /dev/zero
		#str="DNS Lookup For"
		#tui-echo "Internal" \
		#	"$(ifconfig | \
		#		grep -i broadcast | grep ^[[:space:]] | \
		#		awk '{ print $2}')"
		#tui-echo "External" \
		#	"$(echo "$DATA" | \
		#		sed s,"$str","\n\n$str",g | sed s,"<"," ",g | \
		#		grep "$str" | awk '{print $4}')"
	}
	PlayTime() { #
	# Returns the play time duration of a media file
	#
		ff=$(cat $TMP.info)
		d="${ff#*Duration: }"
		echo "${d%%,*}"
	}
	PlayTimeSecs() { #
	# Returns the playtime in seconds
	#
		#set -x
		str_work=$(PlayTime)
		base="${str_work/*:/}"
		mins=${str_work/:$base/}
		hours=${str_work/:*/}
		H=$(( $hours * 3600 ))
		M=$(( ${mins/*:} * 60 )) >&2
		echo ${base} ${M:-0} ${H:-0} | $AWK '{print int ($1 + $2 + $3)}'
		#set +x
	}
	countVideo() { # [VIDEO]
	# Returns the number of video streams found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[ -z "$1" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		eval $cmd|$GREP -i video|wc -l
	}
	countAudio() { # [VIDEO]
	# Returns the number of audio streams found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		LC_ALL=C ; export LC_ALL
		[ -z "$1" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		eval $cmd|$GREP -i audio|wc -l
		LC_ALL="" ; export LC_ALL
	}
	countSubtitles() { # [VIDEO]
	# Returns the number of subtitles found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		LC_ALL=C ; export LC_ALL
		[ -z "$1" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		eval $cmd|$GREP -i subtitle|wc -l
		LC_ALL="" ; export LC_ALL
	}
	hasLang() { # LANG [VIDEO] 
	# Returns true if LANG was found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		LC_ALL=C ; export LC_ALL
		[ -z "$2" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|$GREP -i audio|$GREP -q -i "$1"
		LC_ALL="" ; export LC_ALL
		return $?
	}
	hasLangDTS() { # LANG [VIDEO] 
	# Returns true if LANG was found in VIDEO and declares itself as DTS
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		LC_ALL=C ; export LC_ALL
		[ -z "$2" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|$GREP -i audio|$GREP -i $1|$GREP -q DTS
		LC_ALL="" ; export LC_ALL
		return $?
	}
	txt_meta_me="'VHS ($TITLE $script_version - (c) 2014-2015 by sea), using $(ffmpeg -version|$GREP ^ffmpeg|sed s,'version ',,g)'"
	hasSubtitle() { # LANG [VIDEO] 
	# Returns true if LANG was found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		LC_ALL=C ; export LC_ALL
		[ -z "$2" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|$GREP -i subtitle|$GREP -q -i $1
		return $?
		LC_ALL="" ; export LC_ALL
	}
	listIDs() { # [VIDEO]
	# Prints a basic table of stream ID CONTENT (and if found) LANG
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		LC_ALL=C ; export LC_ALL
		[ -z "$1" ] && \
			[ -f "$TMP.info" ] && \
			cmd="cat \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		IFS=' :()'
		eval "$cmd"| while read strs map id lang ignore kind other
			do
			   printf "%s\t" "$id" "$lang" "$kind"
			   printf "\n"
			done
		IFS=$OIFS
		LC_ALL="" ; export LC_ALL
	}
	listAttachents(){ #
	# To call after StreamInfo or vhs -i video
	#
		for TaID in $($GREP Attach $TMP.info.2|$AWK '{print $2}');do # |$GREP mjpg
			printf " ${TaID:3:(-1)} "
		done
	}
	listAudioIDs() { # [VIDEO]
	# Returns a list of audio stream ids
	#
		listIDs "$1" |$GREP -i audio|$AWK '{print $1}' | $GREP -iv iso
	}
	listVideoIDs() { # [VIDEO]
	# Returns a list of audio stream ids
	#
		listIDs "$1" |$GREP -i video|$AWK '{print $1}'
	}
	listSubtitleIDs() { # [VIDEO]
	# Returns a list of subtitle stream ids
	#
		listIDs "$1" |$GREP -i subtitle |$AWK '{print $1}'
	}
	getRes() { # [-l] ID
	# Returns 2 digits (W*H) according to ID
	# use -l to get a list of valid ID's
		[ "-l" = "$1" ] && \
			$AWK '{print $1}' "$PRESETS" && \
			return 0
		[ -z "$1" ] && \
			printf "Must provide an ID!" && \
			return 1
		case "$1" in
		screen|scrn)
			xrandr|$GREP \*|$AWK '{print $1}'
			;;
		*)	$GREP ^"$1"[[:space:]] "$PRESETS" | \
				$AWK '{print $2}'
			;;
		esac
		return 0
	}
	getQualy() { # [-l] ID
	# Returns 2 numbers (audio video) according to ID
	# use -l to get a list of valid ID's
		[ "-l" = "$1" ] && \
			$AWK '{print $1}' "$PRESETS" && \
			return 0
		[ -z "$1" ] && \
			printf "Must provide an ID!" && \
			return 1
		$GREP ^"$1"[[:space:]] "$PRESETS" | \
			$AWK '{print $4" "$3}'
		return 0
	}
	doExecute() { # SCRIPT [OF STR1 STR2]
	# Executes the script according to script options
	#
		[ -z "$1" ] && tui-echo "Must provide at least a script to execute!" && return 1
		$beVerbose && tui-echo "showFFMPEG is set to: $showFFMPEG"
		$beVerbose && tui-title "Executing:" "$(cat $TMP)"
		if $showFFMPEG
		then	case $MODE in
			dvd|video)	msg="Encoded to"	;;
			screen|webcam)	msg="Recorded to"	;;
			esac
			tui-status $RET_TODO "$msg $2"
			[ -z "$SHELL" ] && \
				bash "$1" || \
				$SHELL "$1"
			tui-status $? "$msg $2"
			RET=$?
		else	tui-bgjob -f "$2" "$1" "$3" "$4"
			RET=$?
		fi
		return $RET
	}
	doSubs() { # [VIDEO]
	# Fills the variable/list: subtitle_ids
	# Its just a list of the subtitle id's available
		sub_ids=$(listSubtitleIDs)
		subtitle_maps=""
		for SI in $sub_ids;do
			$beVerbose && tui-echo "Parsing subtitle id: $SI"
			for l in $lang $lang_alt $langs;do
				$beVerbose && tui-echo "Parsing subtitle id: $SI / $l"
				if listIDs|$GREP $SI|$GREP $l
				then	# subtitle_maps+=" -map 0:$SI" && \
					subtitle_ids+=" $SI"
					$beVerbose && \
						tui-echo "Found subtitle for $l on $SI" "$DONE" ##  ($subtitle_ids)"
				fi
			done
		done
		printf "$subtitle_ids" > "$TMP"
		export subtitle_maps
	}
	doAudio() { # [VIDEO]
	# Fills the variable/list: audio_ids
	# Its just a list of the audio id's used
		countAudio=$(countAudio)
		$beVerbose && tui-echo "Found $countAudio audio stream/s in total"
		case $countAudio in
		00)	if $exit_on_missing_audio
			then	msg="No audio streams found, aborting!"
				tui-status 1 "$msg"
				doLog "$msg"
				exit $RET_FAIL
			fi
			;;
		1)	audio_ids=$(listAudioIDs)
			$beverbose && tui-echo "Using only audio stream found ($audio_ids)..." "$DONE"
			printf $audio_ids > $TMP
			;;
		*)	count=0
			# If ids are forced, use them instead and return
			if [ ! -z "$ID_FORCED" ]
			then	$beVerbose && tui-echo "Forced audio IDs:" "$ID_FORCED"
				printf "$ID_FORCED" > $TMP
				return
			#else	echo no forced ids
			fi
		# Regular handling
			for l in $lang $lang_alt $langs;do
				((count++))
				# 'this' contains all the ids for the specific langauge...
				if hasLang $l
				then 	# Prefered language found, is it dts, downcode it?
					hasLangDTS $l && \
						$channel_downgrade && \
						cmd_run_specific="-ac $channel" && \
						$beVerbose && tui-echo "Downgrading channels from DTS to $channel"
					# Get all stream ids for this language
					found=0
					this=""
					for i in $(listAudioIDs);do
						if listIDs|$GREP ^$i |$GREP -q $l
						then	this+=" $i" 
							((found++)) 
							$beVerbose && tui-echo "Found $l on stream $i"
						fi
					done
					
					$beVerbose && tui-echo "There are $found audio streams found for $l"
					# found is the amount of indexes per langauge
					case $found in
					1)	# $count represents the order of languages: lang lang_alt 'list of added langs'
						case $count in
						1)	[ $countAudio -eq 1 ] || audio_ids="$this"	;;
						2)	# This applies only to $lang_alt
							if [ -z "$audio_ids" ]
							then	$beVerbose && tui-echo "Prefered langauge ($lang) not found"
								audio_ids="$this"
							else	$beVerbose && \
									tui-echo "Prefered langauge ($lang) found, so is $lang_alt" && \
									tui-echo "Force to use both languages: $lang_force_both"
								$lang_force_both && audio_ids+=" $this"
							fi			;;
						*)	# This is the prefered langauge, or all additional ones
							audio_ids+=" $this"	;;
						esac
						;;
					*)	$beVerbose && tui-echo "Parsing for possible default output"
						for i in $this;do 
							if $GREP Audio "$TMP.info"|$GREP $l|$GREP -q default
							then 	audio_ids+=" $i"
								$beVerbose && \
									tui-echo "Found default entry for language $l" && \
									tui-echo "Current ids to use: $audio_ids"
								break #1
							else	$beVerbose && tui-echo "ID $i is not default"
								tui-echo "Please select the stream id you want to use:"
								
                                                                i=$(tui-select $this)
								printf "\n"
								audio_ids+=" $i"
							fi
						done
					esac
					found=0
				else	tui-echo "Didnt find: $l"
				fi
			done
			;;
		esac
		printf "$audio_ids" > "$TMP"
	}
	doDVD() { # FILEforCOMMAND
	# Writes the generated command to 'FILEforCommand'
	#
		tui-title "Encoding $name" # from $MODE"
		dvd_tmp="$HOME/.cache/$name"
		dvd_reuse=nothing
		errors=0
		
		dvd_base="/run/media/$USER/$name"
		
		# Verify its mounted...
		if mount | $GREP -q sr0
		then	# Its already mounted
			tui-status 4 "DvD already mounted to: $(mount | $GREP sr0|$AWK '{print $3}')"
		else	tui-printf -rS 2 "Mounting DVD to \"$dvd_base\""
			RET=1
			tui-bol-sudo && \
				sudo mkdir -p $dvd_base && \
				sudo mount /dev/sr0 $dvd_base -o ro && \
				RET=0 || \
				( tui-echo "Please provide root password to mount DVD";su -c "RET=1;mkdir -p $dvd_base;mount /dev/sr0 $dvd_base -o ro" && RET=0 && export RET)
			tui-status $RET "Mounted DVD to $dvd_base"
		fi
		
                vobs=""
		vob_list=""
		total=0
		yadif="-vf yadif"
	                
                # Cop vobs to local or directly from dvd?
		A="Encode directly from DVD (ffmpeg only)"
		B="Copy largest files to local (with vobcopy)"
		C="Copy largest files to local (with cp)"
		tui-echo "Please select a method:"
		
		
                dvd_copy=$(tui-select "$B" "$A")
		printf "\n"
		case "$dvd_copy" in
		"$A")	cd "$dvd_base/VIDEO_TS"
			cmd="$FFMPEG $vobs $EXTRA_CMD -acodec $audio_codec -vcodec $video_codec $extra $yadif $METADATA $F \"${OF}\""
			;;
		"$B")	# Copy VOB with vobcopy
			[ -d "$dvd_tmp" ] && \
			 	tui-yesno "$dvd_tmp already exists, reuse it?" && \
				dvd_reuse=true || \
				dvd_reuse=false
			# Create tempdir to copy vob files into
			if [ false = "$dvd_reuse" ]
			then 	mkdir -p "$dvd_tmp"
				doLog "DVD: Copy vobs to \"$dvd_tmp\""
				tui-echo "Copy vob files to \"$dvd_tmp\", this may take a while..." "$WORK"
			
				tui-status -r 2 "Initialize DvD..." #$(readlink /dev/sr0)"
				[ -f "$dvd_tmp/vobcopy.bla" ] && rm "$dvd_tmp/vobcopy.bla"
				doVobCopy "$dvd_tmp"
				exit_vobcopy=$?
				[ -f "$dvd_tmp/vobcopy.bla" ] && rm "$dvd_tmp/vobcopy.bla"
				[ 1 -eq $exit_vobcopy ] && \
					tui-printf -S 1 "There was an error copying the files..." && \
					exit 1
				
				# Clean up
				tui-status -r 2 "Unmounting DVD"
				tui-bol-sudo && \
					( sudo umount "$dvd_base" 2>/dev/zero ; RET=$? ; export RET  ; sudo rm -fr "$dvd_base" ) || \
					( su -c "umount $dvd_base && rm -fr $dvd_base" ; RET=$? ; export RET )
				tui-status $RET "Unmounted DVD"
				if [ 0 -eq $? ]
				then	eject /dev/cdrom
                                	tui-status $? "Ejected disc."
				else	tui-status $? "There was an error"
				fi
			fi
			BIG="$dvd_tmp/bigvob.vob"
			[ ! -f "$BIG" ] && \
				echo -e "cd $dvd_tmp\neval cat *vob > bigvob.vob" > "$TMP" && \
				tui-bgjob -f "$BIG" "$TMP" "Merging into single temp file..." "Merged into single vob file."
			#"$(ls $dvd_tmp/*.vob)"
			
			# Show info on video
			showHeader=false vhs -i "$BIG"
			
			# Check for audio streams
			if [ -z "$ID_FORCED" ]
			then	tui-title "Parsing for audio streams..."
				doAudio "$BIG"		## Fills the list: audio_ids
				audio_ids=$(cat "$TMP") 
				if [ ! -z "$audio_ids" ]
				then	# all good
					for i in $audio_ids;do cmd_audio_maps+=" -map 0:$i";done
					$beVerbose && tui-echo "Using these audio maps:" "$audio_ids"
				else	# handle empty
					tui-echo "No audio stream could be recognized"
					tui-echo "Please select the ids you want to use, choose done to continue."
					#select i in $(seq 1 1 $(countAudio)) done;do 
					i=""
					while [ ! "$i" = "done" ]
					do	i=$(tui-select $(listAudioIDs) done)
						[ "$i" = "done" ] || audio_ids+=" ${i/done/}"
						#cmd_audio_maps+=" -map 0:$i"
						tui-echo "Now using audio ids: $audio_ids"
					done
				fi
			else	audio_ids="$ID_FORCED"
				$beVerbose && tui-echo "Using forced ID's:" "$audio_ids"
			fi
			msg="Using for audio streams: $audio_ids"
			doLog "$msg"		
			
			# Apply found streams to command
			for aid in $audio_ids;do
				cmd_audio_all+=" -map 0:$aid"
			done
			
			# Finalize the command
			cmd="$FFMPEG -probesize 50M -analyzeduration 100M -i $BIG $EXTRA_CMD -q:a 0 -q:v 0 $web $extra $bits -vcodec $video_codec $cmd_video_all -acodec $audio_codec $cmd_audio_all $yadif $TIMEFRAME $METADATA $F \"${OF}\""
			;;
		esac
		
		doLog "DVD: Using \"$dvd_copy\" command"
		printf "$cmd" > "$TMP"
		doLog "DVD-Command: $cmd"
	}
	doVobCopy() { # "OUTDIR"
	# Uses vobcopy to copy the vobs to OUTDIR
	#
		[ -z "$1" ] && return 1
		declare files
		unset files
		count=0
		
		if [ ! -z "$1" ] &&  cd "$1"
		then	if [ ! "" = "$( ls |$GREP -i vob)" ] && tui-yesno "Delete existing vob files?"
			then	#echo $PWD ; set -x
				rm -f *vob 	#2>/dev/zero
				rm -f *partial 	#2>/dev/zero
				rm -f vobcopy.bla
				#exit
			fi
			cd "$OLDPWD"
		fi
		
		# TODO FIXME, wait for vobcopy update to fix its background incompatibilty - buffer overrun
		#if true
		if $showFFMPEG
		then	#vobcopy -l -o "$1"
			vobQ=""
		else	# Do the job in the background
			vobQ="q"
		fi
		
		# Default or 'custom' options for vobcopy?
		if tui-yesno "Use default vobcopy settings?"
		then	tui-echo "Using default scanmode:" "Title with most chapters"
			cmd="vobcopy -${vobQ}l -o \"$1\""
		else	tui-echo "What vobcopy mode shall be attempted?"
			copyMode=$(tui-select "Playtime" "TitleNr") ##"Mirror")
			case "$copyMode" in
			Playtime)
					tui-echo "Using other scanmode:" "Title with longest playtime"
					cmd="vobcopy -${vobQ}M -o \"$1\""
					;;
			TitleNr)	tui-title "Set a title number:"
					tui-echo "Using other scanmode:" "Copy a specific title"
					[ -f vobcopy.bla ] && rm vobcopy.bla
					title="" ; titles="" ; vobcopy -${vobQ}Ix

					$AWK	'BEGIN  { print "Title Chapters" }
							NR==1 ||
							# on either leading comments or or NOT starting with [Info], move onto next loop/line
							/^#/ ||
							/^![Info]/ {next}
							{
							# Output
							if($2 == "Title") {
								if($6 == "chapters.") {
									print $3 "\t" $5
								}
							}
						}' vobcopy.bla > "$TMP"
					
					# Print the titles and let the user select
					tui-echo "Which title to use:"
					declare -a titles
					while read TITLE CHAP;do
						echo $TITLE | $GREP -q ^[0-9] && \
							titles[$TITLE]="Title $TITLE with $CHAP chapters" #&& \
					done<$TMP
					
					#titles=$($GREP ^[0-9] "$TMP"|$AWK '{print $1}')
					[ "" = "$(echo ${titles[*]})" ] && \
						tui-printf -S 1 "FATAL - No titles found!" && \
						exit 1
					title=$(tui-select "${titles[@]}")
					title=$(echo ${title} | $AWK '{print $2}')
					$beVerbose && tui-echo "Selected Title: $title"
					tui-echo
					cmd="vobcopy -${vobQ}n $title -o \"$1\""
					;;
			esac
		fi
		[ -f "vobcopy.bla" ] && rm vobcopy.bla
		doLog "DVD: Generated vobcopy command"
		doLog "Command: $cmd"
		
		# Copy the data
		if $showFFMPEG
		then	# Be verbose
			eval "$cmd"
			echo "$?" > "$TMP.out"
		else	# Do the job in the background -- TODO fine tuning
			echo "$cmd" > "$TMP"
			tui-bgjob "$TMP" "Copying vob files..." "Copied all required vob files."
			echo "$?" > "$TMP.out"
		fi
		[ -f "vobcopy.bla" ] && rm vobcopy.bla
		RET=$(cat $TMP.out)
		return $RET
	}
	doWebCam() { #
	#
	#
		# TODO
		# Done ?? dont work for me, but seems to for others
		# Maybe because i have disabled the laptop's internal webcam in BIOS
		msg+=" Capturing"
		srcs=($(ls /dev/video*)) 
		[ -z "$srcs" ] && tui-echo "No video recording device found!" "$TUI_FAIL" && exit 1
		if [ "$(printf $srcs)" = "$(printf $srcs|$AWK '{print $1}')" ]
		then 	input_video="$srcs"
		else	tui-echo "Please select the video source to use:"
			
                        input_video=$(tui-select  in $srcs)
			printf "\n"
		fi
		
		[ -z "$verbose" ] && verbose="-v quiet"
                doLog "Overwrite already generated name, for 'example' code.. "
               	[ -z "$OF" ] && OF="$(tui-str-genfilename "$XDG_VIDEOS_DIR/webcam-out.$container" $container)"
                #sweb_audio="-f alsa -i default -c:v $video_codec -c:a $audio_codec"
                web_audio=" -f alsa -i default"
                cmd="$FFMPEG -f v4l2 -s $webcam_res -i $input_video $EXTRA_CMD $web_audio $cmd_output_all \"${OF}\""
		doLog "WebCam: Using $webcam_mode command"
                doLog "Command-Webcam: $cmd"
		printf "$cmd" > "$TMP"
		#OF="$OF"
		#doExecute "$OF" "Saving Webcam to '$OF'"
	}
	UpdateLists() { #
	# Retrieve values for later use
	# Run again after installing new codecs or drivers
		tui-title "Generating a list file"
		$beVerbose && tui-progress "Retrieve raw data..."
		[ -f "$LIST_FILE" ] && \
			printf "" > "$LIST_FILE" || \
			touch "$LIST_FILE"
		[ -z "$verbose" ] && verbose="-v quiet"
		ffmpeg $verbose -codecs | $GREP \ DE > "$TUI_FILE_TEMP"
		
		for TASK in DEA DES DEV;do
			case $TASK in
			DEA)	txt_prog="Audio-Codecs"	; 	var=codecs_audio 	;;
			DES)	txt_prog="Subtitle-Codecs"; 	var=codecs_subtitle	;;
			DEV)	txt_prog="Video-Codecs"	; 	var=codecs_video	;;
			esac
			tui-progress "Saving $txt_prog"
			raw=$($GREP $TASK "$TUI_FILE_TEMP"|$AWK '{print $2}'|sed s,"\n"," ",g)
			clean=""
			for a in $raw;do clean+=" $a";done
			printf "$var=\"$clean\"\n" >> "$LIST_FILE"
			doLog "Lists: Updated $txt_prog"
		done
		
		tui-progress "Saving Codecs-Format"
		ffmpeg $verbose -formats > "$TUI_FILE_TEMP"
		formats_raw=$($GREP DE "$TUI_FILE_TEMP"|$AWK '{print $2}'|sed s,"\n"," ",g)
		formats=""
		for f in $formats_raw;do formats+=" $f";done
		printf "codecs_formats=\"$formats\"\n" >> "$LIST_FILE"
		doLog "Lists: Updated Codecs-Format"

		
		if [ -e /dev/video0 ]
		then 	#v4l2-ctl cant handle video1 .. ??
			tui-progress "Saving WebCam-Formats"
			webcam_formats=""
			[ -z "$webcam_fps" ] && webcam_fps=5
			wf="$(v4l2-ctl --list-formats-ext|$GREP $webcam_fps -B4 |$GREP Siz|$AWK '{print $3}'|sort)"
			for w in $wf;do webcam_formats+=" $w";done
			printf "webcam_formats=\"$webcam_formats\"\n" >> "$LIST_FILE"
			doLog "Lists: Updated WebCam-Format"

			tui-progress "Saving WebCam-frames"
			webcam_frames=""
			wf="$( v4l2-ctl --list-formats-ext|$GREP -A6 Siz|$AWK '{print $4}')"
			C=0
			for w in $wf;do webcam_frames+=" ${w/(/}";((C++));[ $C -ge 6 ] && break;done
			printf "webcam_frames=\"$webcam_frames\"\n"|sed s,"\.000","",g >> "$LIST_FILE"
			doLog "Lists: Updated WebCam-Frames"
		elif [ -e /dev/video1 ]
		then 	#v4l2-ctl cant handle video1 .. ??
			tui-status 1 "As far as i tried, i could not make v4l2-ctl handle video1."
		fi
		tui-status $? "Updated $LIST_FILE"
	}
	MenuSetup() { # 
	# Configures the variables/files used by the script
	# Write the default configuration if missing
	#
	#	Variables
	#
		! source "$LIST_FILE" && \
			 UpdateLists && \
			 source "$LIST_FILE"
		if [ ! -f "$CONFIG" ] 
		then 	touch "$CONFIG"
			doLog "Setup: Write initial configuration file"
			cat > "$CONFIG" << EOF
# $CONFIG, generated by $ME ($script_version)
# The defaults are optimized for HDR videos within mkv container

# Required applications found?
req_inst=false

# Available (yet supported) containers:
# VIDEO -> avi flv mkv mp4 ogg webm wmv
# AUDIO -> aac ac3 dts mp3 wav wma
# Understand that the audio container is only used for streaming!
container=mkv
container_audio=mp3

# Audio bitrate suggested range (values examples): 72 96 128 144 192 256
# Note that these values are ment for mono or stereo, to ensure quality of surround sound, 384 should be your absolute minimum
audio_bit=192

# Video bitrate suggested range (value examples): 128 256 512 768 1024 1280 1536 1920 2048 2560 4096 5120
# Note that he lower the resolution, the lower the visual lossless bitrate
video_bit=768

# Make sure the video has at least this amount of Frames per Second
# This is only applied, if you pass -F, -f ARG will overwrite this value
FPS=25

# This is the sound device/codec to be use for webcam, screenrecording or 'guide' more
sound=alsa

# See ffmpeg output (vhs -i FILE // ffmpeg -psnr -i FILE) for your language abrevihation
# if 'lang' is not found it will take 'lang_alt' if available
# Alternativly, you could set the lang_alt to the numeric code of your langauge, if (once) you know it.
lang=eng
lang_alt=ger
lang_force_both=true

# If DTS is found, to how many channels shall it 'downgrade'?
# Range::  1) Mono, 2) Stereo, [3-5]) unkown, 6) 5.1 Surround, 7) '6.1' Surround
# If you use a surround system, just set channel_downgrade=false
channels=2
channel_downgrade=true

# Suggested audio rates (hz) are around 44000 to 96000
audio_rate=48000
useRate=false
exit_on_missing_audio=true

# Subtitle
subtitle=ssa

# How long to wait by default between encodings if multiple files are queued?
# Note that 's' is optional, and could be as well either: 'm' or 'h'.
sleep_between=90s

# This is a default value that should work on most webcams
# Please use the script's Configscreen (-C) to change the values
# Default values are for res: 640x480
# Default values are for fps: 25
webcam_res=640x480
webcam_fps=25

# Set the default zone of screen to record from
# Top Left at FullHD:  0 0 520 960
# Top Right at FullHD: 0 960 520 960
# Lower Left at FullHD:  520 0 960 520
# Lower Right at FullHD: 520 960 520 960
screen_zone="520 960 0  520"
#$(SIZE=$(xrandr | $AWK  '/\*/ {print $1}'))

# Streaming
FFSERVER_CONF=$(locate ffserver.conf|head -n1)
URL_UP="udp://$(ifconfig | grep broadcast | awk '{print $2}'):8090/live.ffm"
URL_PLAY="udp://$(ifconfig | grep broadcast | awk '{print $2}'):8090"
EOF
			tui-status $? "Wrote $CONFIG" 
			
		fi
	#
	#	Setup menu
	#
		tui-title "Setup : $TITLE"
		
		# Get a list of ALL variables within the $CONFIG file
		VARS=$(tui-conf-get -l "$CONFIG"|$GREP -v req)
		
		# Make a tempfile without empty or commented lines
		# And display both, variable and value to the user
		oIFS="$IFS" ; IFS="="
		touch $TMP.cfg
		printf "$($GREP -v '#' $CONFIG)" > $TMP.cfg
		while read var val;do
			[ ! "#" = "${var:0:1}" ] && \
				[ ! -z "$var" ] && \
				tui-echo "$var" "$val"
		done < $TMP.cfg
		IFS="$oIFS"
		
		tui-echo
		tui-echo "Which variable to change?"
		LIST_BOOL="false true"
		LIST_LANG="ara bul chi cze dan eng fin fre ger hin hun ice nor pol rum spa srp slo slv swe tur"
		
                var=$(tui-select  Back UpdateLists ReWriteContainers $VARS)
		while [ ! "$var" = Back ]
		do
		
                case $var in
			Back)		break	;;
			UpdateLists)	$var 	;;
			ReWriteContainers) WriteContainerFile ;;							
			*)	val=$(tui-conf-get "$CONFIG" "$var")
				newval=""
				tui-echo "${var^} is set to:" "$val"
				if tui-yesno "Change the value of $var?"
				then	newLine=true
					case $var in
					container)	tui-echo "Please select a new one:"
							newval=$(tui-select $(cd "$(dirname $CONFIG)/containers";ls))
							;;
					channnels)	tui-echo "Please select a new amount:"
							newval=$(tui-select $(seq 1 1 6))
							;;
					webcam_res)	tui-echo "Please select the new resolution:"
							newval=$(tui-select $webcam_formats)
							;;
					webcam_fps)	tui-echo "Please select the new framerate:"
							newval=$(tui-select $webcam_frames)
							;;
					subtitle)	tui-echo "Please select the new subtitle codec:"
							newval=$(tui-select $codecs_subtitle)
							;;
					lang_force_both|useRate|channel_downgrade)
							tui-echo "Do you want to toggle this?"
							newval=$(tui-select $LIST_BOOL)
							;;
					lang|lang_alt)	tui-echo "Which language to use as $var?"
							newval=$(tui-select $LIST_LANG)
							;;
					*)		newval=$(tui-read "Please type new value:")
							newLine=false
							;;
					esac
					$newLine && printf "\n"
					msg="Changed \"$var\" from \"$val\" to \"$newval\""
					# Save the new value to variable in config 
					if [ -z "$newval" ]
					then	tui-status 1 "$msg"
						doLog "Setup: Failed to c$(printf ${msg:1}|sed s,ged,ge,g)"
					else	tui-conf-set "$CONFIG" "$var" "$newval"
						tui-status $? "$msg" && \
						doLog "Setup: $msg" || \
						doLog "Setup: Failed to c$(printf ${msg:1}|sed s,ged,ge,g)"
					fi
				fi
			;;
			esac
			var=$(tui-select  Back UpdateLists ReWriteContainers $VARS)
			printf "\n"
			tui-echo "Press [ENTER] to see the menu:" "$INFO"
		done
	}
	function build_ffmpeg () { # [mini]
	# Build ffmpeg with default packages, or just mini (x265,libfdk_aac,libass)
	#
		tui-header "$ME ($script_version)" "$(date +'%F %T')"
		tui-title "Building ffmpeg from scratch"$( [ -z "$1" ] || echo " ($2)")
	#
	#	Build environment
	#
		tui-echo "Please select the target CHROOT"
		CHROOT=$(tui-select $intPlayRows / /usr/local $HOME/.local $HOME)
		LOG_DIR="$CHROOT/logs"		#/$TASK.log will be added
		LOG=~/ffmpeg-build.log		# 'main' logfile is always @ home
		SKIPTHIS="$DIR_SRC/skip_these"
	#
	#	Variables	:	Environment
	#
		[ -f "$HOME/.config/user-dirs.dirs" ] && \
			source "$HOME/.config/user-dirs.dirs" || \
			XDG_DOWNLOAD_DIR="$HOME/Downloads"
		> "$LOG"
		TMP="${LOG_DIR}/command.sh"
	#
	#	Variables	:	Hardcoded
	#
		DIR_SRC="$XDG_DOWNLOAD_DIR/ffmpeg_sources"
		LOG_DIR="$DIR_SRC/logs"
		DIR_CONF="$CHROOT/etc"
		# Dirs using PREFIX
		PREFIX="$CHROOT/usr"
		DIR_BIN="$PREFIX/bin"
		DIR_LIB="$PREFIX/lib"
		[ $(uname -m) = x86_64 ] && DIR_LIB+=64
		DIR_INC="$PREFIX/include"
	#
	#	Variables	:	Optic fixes
	#
		DIR_BIN=${DIR_BIN/\/\//\/}
		DIR_CONF=${DIR_CONF/\/\//\/}
		PREFIX=${PREFIX/\/\//\/}
		DIR_LIB=${DIR_LIB/\/\//\/}
		DIR_INC=${DIR_INC/\/\//\/}
	#
	#	Variables	:	Build Environment
	#
		CC="$(which gcc)"
		CXX="$(which g++)"
		PATHS_LIBS32="/lib:/usr/lib:/usr/local/lib:$CHROOT/lib:$PREFIX/lib"
		PATHS_LIBS+="$PATHS_LIBS32:$(echo $PATHS_LIBS32|sed s,lib,lib64,g)"
		PATHS_INC="/include:/usr/include:/usr/local/include:$CHROOT/include:$PREFIX/include"
	#
	#	Variables	:	Remote locations	
	#
		GIT_FFMPEG="git://source.ffmpeg.org/ffmpeg.git"
		# Audio
		URL_flac="http://flac.cvs.sourceforge.net/viewvc/flac/?view=tar"
		GIT_libfdk_aac="git://git.code.sf.net/p/opencore-amr/fdk-aac"
		URL_libmp3lame="http://downloads.sourceforge.net/project/lame/lame/3.99/lame-3.99.5.tar.gz"
		URL_libogg="http://downloads.xiph.org/releases/ogg/libogg-1.3.2.tar.gz"
		GIT_libopus="git://git.opus-codec.org/opus.git"
		URL_faac="http://downloads.sourceforge.net/faac/faac-1.28.tar.bz2"
		# Video
		GIT_x264="git://git.videolan.org/x264.git"
		HG_x265="http://hg.videolan.org/x265"	
		URL_libvorbis="http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.4.tar.gz"
		GIT_libvpx="https://chromium.googlesource.com/webm/libvpx.git"
		URL_libtheora="http://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.xz"
		URL_xvid="http://downloads.xvid.org/downloads/xvidcore-1.3.3.tar.gz"
		URL_webp="http://downloads.webmproject.org/releases/webp/libwebp-0.4.3.tar.gz"
		URL_vdpau="http://people.freedesktop.org/~aplattner/vdpau/libvdpau-1.1.tar.bz2"
		URL_libva="http://www.freedesktop.org/software/vaapi/releases/libva/libva-1.5.1.tar.bz2"
		URL_libva_intel="http://www.freedesktop.org/software/vaapi/releases/libva-intel-driver/libva-intel-driver-1.5.1.tar.bz2"
		GIT_libcaca="https://github.com/cacalabs/libcaca"
		# Images
		SVN_openjpeg="http://openjpeg.googlecode.com/svn/trunk/"
		URL_png="http://downloads.sourceforge.net/libpng/libpng-1.6.16.tar.xz"
		# Fonts
		URL_fribidi="http://fribidi.org/download/fribidi-0.19.6.tar.bz2"
		URL_fontconfig="http://www.freedesktop.org/software/fontconfig/release/fontconfig-2.11.1.tar.bz2"
		URL_freetype2="http://downloads.sourceforge.net/freetype/freetype-2.5.5.tar.bz2"
		URL_xml="http://xmlsoft.org/sources/libxml2-2.9.2.tar.gz"
		# Subtitle
		URL_ass="https://github.com/libass/libass/releases/download/0.12.1/libass-0.12.1.tar.xz"
		# Extras
		URL_libffi="ftp://sourceware.org/pub/libffi/libffi-3.2.1.tar.gz"
		URL_mako="https://pypi.python.org/packages/source/M/Mako/Mako-1.0.1.tar.gz"
		# v4l
		URL_v4l="http://www.linuxtv.org/downloads/v4l-utils/v4l-utils-1.6.2.tar.bz2"
		URL_v4l_mesa_drm="http://dri.freedesktop.org/libdrm/libdrm-2.4.60.tar.bz2"
		URL_v4l_mesa="ftp://ftp.freedesktop.org/pub/mesa/10.5.2/mesa-10.5.2.tar.xz"
		URL_v4l_glu="ftp://ftp.freedesktop.org/pub/mesa/glu/glu-9.0.0.tar.bz2"
		URL_v4l_libjpeg="http://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-1.4.0.tar.gz"
		URL_v4l_libalsa="http://alsa.cybermirror.org/lib/alsa-lib-1.0.29.tar.bz2"
		# Hardware
		GIT_bluray="git://git.videolan.org/libbluray.git"
		URL_libcddb="http://prdownloads.sourceforge.net/libcddb/libcddb-1.3.2.tar.bz2"
		URL_libcdio="http://ftp.gnu.org/gnu/libcdio/libcdio-0.93.tar.bz2"
		URL_libcdio_para="http://ftp.gnu.org/gnu/libcdio/libcdio-paranoia-10.2+0.93+1.tar.bz2"
		GIT_libdc1394="git://git.code.sf.net/p/libdc1394/code"
		URL_libdc1394="https://sourceforge.net/projects/libdc1394/files/latest/download"
	#
	#	Functions
	#
		skip_this() { # PKG
		# Returns true (0) if passed PKG is found in SKIPFILE
		# Returns false (1) otherwise
			#set -x
			$GREP -q ^"$1"$ "$SKIPTHIS"
		}
	#
	#	Verify paths
	#
		for d in "$DIR_SRC" "$CHROOT" "$LOG_DIR" "$(dirname $TMP)"
		do	[ -z "$d" ] || tui-bol-dir -v "$d"
		done
		cd "$DIR_SRC" || exit 1
		[ -f "$SKIPTHIS" ] || touch "$SKIPTHIS"
	#
	#	Info & Check for build tools
	#
		tui-title "Important Information"
		tui-echo "To build ffmpeg and several of its features, the following will be required:"
		tui-list -1 	"Aprox 200mb for the build tools" \
				"aprox 350 mb of the bandwidth" \
				"aprox 500 mb diskspace for temp files" \
				"aprox 30 minutes of your time, depending on you machine & internet"
		tui-echo

		if tui-yesno "Install all building tools? (the last 4 might report failure)"
		then	# Last line (packageblock) fails on Fedora 22
			sudo tui-install -v git hg svn \
					cpp make  cmake nasm yasm \
					gcc cross-gcc-common libtool \
					autoconf automake git2cl help2man \
					gcc-c++ enca \
					texinfo aclocal makeinfo libiconv-devel
		fi
	#
	#	Download & Compile dep-tree
	#
		
	#
	#	Download, Configure & Compile FFMPEG
	#
		configured=false
		if tui-yesno "Download and configure ffmpeg now?"
		then
			tui-title "Downloading ffmpeg"
			LOG_THIS="$DIR_SRC/ffmpeg.log"
			touch "$LOG_THIS"
			cd "$DIR_SRC"
			default_git ffmpeg "$GIT_FFMPEG"
			# Prepare the enable strings
			enable_VIDEO="--enable-libx264  --enable-libx265  --enable-libxvid --enable-libcaca --enable-libwebp --enable-vdpau --enable-libtheora" # --enable-libva --enable-libva-intel"
			enable_AUDIO="--enable-libmp3lame --enable-libfdk_aac --enable-libopus --enable-libvorbis "
			enable_TITLE="--enable-fontconfig --enable-libfreetype --enable-libass"
			enable_HW="--enable-x11grab --enable-libv4l2" #--enable-libcdio " # --enable-gnutls"
			enable_IMG="--enable-libopenjpeg "
			TMP="$(dirname $LOG_THIS)"	# this ./configure seems to use TMP internaly...
			
			# Configure FFMPEG for the enables
			./configure 	--prefix="$PREFIX" --bindir="$DIR_BIN" --libdir=$DIR_LIB --incdir=$DIR_INC --docdir=$PREFIX/share/doc/ffmpeg \
					--enable-shared  --enable-nonfree --enable-gpl \
					$enable_AUDIO \
					$enable_VIDEO \
					$enable_HW 1>"$LOG_THIS" 2>"$LOG_THIS"
			tui-status $? "Configured ffmpeg"
			RET=$?
			[ $RET -ne 0 ] && tui-edit "$LOG_THIS"
			readonly configured=true
			export configured
		fi

		if $configured && tui-yesno "So you just want to build it now?"
		then	tui-status 111 "Expected build time... aprox. 10mins..."
			TMP="$LOG_DIR/ffmpeg.sh"
			cat > "$TMP" <<-EOF
			time make V=1	 	1>>"$LOG_THIS" 2>>"$LOG_THIS"
			tui-status \$? "ffmpeg: Make"
			tui-title "ffmpeg made"
			sudo make install	1>>"$LOG_THIS" 2>>"$LOG_THIS"
			tui-status \$? "ffmpeg: make install"
			make distclean		1>>"$LOG_THIS" 2>>"$LOG_THIS"
			hash -r
			EOF
			if tui-bgjob "$TMP" "Building ffmpeg..." "Built ffmpeg."
			then	# Some ENV settings are required if its build in a custom dir
				PKG_CONFIG_PATH="$DIR_LIB:$DIR_LIB/pkgconfig:${DIR_LIB}64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig"
				LD_LIBRARY_PATH="$DIR_LIB:${DIR_LIB}64:/usr/local/lib:/usr/local/lib64:/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib64:/usr/lib"
				tui-conf-set ~/.bashrc PKG_CONFIG_PATH "$PKG_CONFIG_PATH"
				tui-conf-set ~/.bashrc LD_LIBRARY_PATH "$LD_LIBRARY_PATH"
			fi
		fi
	}
	PlayStatus() { # FILE
	# Prints the extra status play bar
	# Time as Progress, yay 
		# Vars
		$ME -i "$video"
		PT=$(PlayTime)		# Get nice displayed playtime
		PTS=$(PlayTimeSecs)	# Get playtime as seconds
		[ "00" = "${PT:0:2}" ] && \
			PT="${PT/00:}"	# Cut off 'empty' leading hours
		PT="${PT/.*}"		# Cut off miliseconds
		[ "0" = "${PT:0:1}" ] && \
			PT="${PT:1}"
		STATUS="$TMP.playstatus"
		# Be easy on display
		function secs2time() { # SECS
		# Returns given SECS as readable TIME (hh:mm:ss)
		#
			[ ! -z "$(echo $1|tr -d [:digit:])" ] && echo "Usage: secs2time SECS" && return 1
			SECS=$1
			MINS=$(( $SECS / 60  ))
			HRS=$(( $MINS / 60 ))
			SECS=$(( $SECS - $MINS * 60  ))
			[ $HRS -eq 0 ] && HRS=""
			[ $MINS -eq 0 ] && MINS=""
			[ -z "$HRS" ]  || printf "${HRS}:"
			if [ -z "$MINS" ] 
			then	[ ! -z "$HRS" ] && printf "00"
			else	printf "${MINS}:"
			fi
			if [ -z "$SECS" ]
			then	printf "00"
			else	[ ${#SECS} -eq 1 ] && [ ! -z "$MINS" ] && PRE="0" || PRE=""
				printf "${PRE}${SECS}"
			fi
			return 0
		}
		
		# Make required changes at the command file
		$SED s,'v quiet','hide_banner',g -i "$TMP"
		$SED s,"||"," 2\>$STATUS ||",g -i "$TMP"
		
		# Start job
		$SHELL "$TMP" &
		PID=$!
		sleep 0.7
				
		# Print information line
		while ps $PID > /dev/null
		do	CUR=$(tr '\r' '\n' < "$STATUS" | tail -n 1  | awk '{print $1}')
			
			# If progress works, this is the next to be tested - multiple files
			CUR="${CUR/.*/}"
			[ -z "$(echo $CUR|tr -d [:alpha:] | tr -d [\[\]])" ] && CUR=0
			tui-progress -bm "$PTS" -c "${CUR/.*/}" "$video :: $(secs2time ${CUR/.*/})/$PT"
		#	echo >&2
		#	echo $PTS  >&2
		#	echo  >&2
			[ ${CUR:-0} -eq ${PTS:-0} ] && printf "\n" && pkill ffplay && break
			sleep 1
		done
		rm -f "$STATUS"
	}
#
#	Environment checks
#
	# This is optimized for a one-time setup
	if [ ! -f "$CONFIG" ]
	then 	tui-header "$ME ($script_version)" "$(date +'%F %T')"
		tui-bol-dir "$CONFIG_DIR"
		$beVerbose && tui-echo "Entering first time setup." "$SKIP"
		req_inst=false
		
		doLog "Setup: Writing container and list files"
		WriteContainerFile
                #WriteTemplateFile
		UpdateLists
		
		# Install missing packages
		tui-progress -ri movies-req -m $(printf ${REQUIRES}|wc|$AWK '{print $2}') " "
		if [ false = "$req_inst" ]
		then 	# Packages are not yet installed
			tui-title "Verify all required packages are installed"
			doLog "Req : Installing missing packages: $REQUIRES"
			# Do the installation
			tui-install -vl "$LOG" $REQUIRES && \
				FIRST_RET=true || FIRST_RET=false
			# Prints result to user, and generate log entry
			tui-status $? "Installed: $REQUIRES" && \
				ret_info="succeeded" || \
				ret_info="failed"
			# Print log file
			doLog "Req: Installing $REQUIRES $ret_info"
		fi	
		
		MenuSetup
		tui-conf-set "$CONFIG" "req_inst" "$FIRST_RET"
	fi
	source "$CONFIG"
	if [ ! -f "${URLS}.play" ]
	then	for T in play stream;do
		cat > "${URLS}.${T}" <<-EOF
			#######################
			###    Favorites    ###
			#######################
			
			#######################
			###    Last Added   ###
			#######################
			EOF
		done
	fi
	# Print Log entry only if its neither:
	#	info, help, Log
	printf '%s\n' "$@" | $GREP -q -- '-[Lih]' || \
		tui-log -e "$LOG" "\r---- New call $$ ----"
#
##
###
####	Catching Arguments
###
##
#
	A=1 			# Files added counter
	image_overlay=""	# Clean variable for 'default' value
	#showHeader=false
	while getopts "2a:ABb:c:Cd:De:E:f:FGhHi:I:jJKLl:O:Pp:Rr:Ss:tT:q:Q:Uu:vVwWxXyz:Z:" opt
	do 	log_msg=""
		case $opt in
		2)	PASS=2	;;
		a)	log_msg="Appending to input list: $OPTARG"
			ARG=""
			out_str=""
			case ${OPTARG/*.} in
		#	aac|ac3|dts|flac|mp3|ogg|wav|wma)
		#		adders+=" -map $A"
		#		;;
			jpg|jpeg|gif|bmp|png|ico)
				out_str="out$A"
				#ARG=" -filter_complex 'overlay$image_overlay'"
				ARG=" -filter_complex ${video_overlay/[X/[$A}"
				;;
			avi|xvid|webm|ogm|mkv|mp4|mpeg|ogv|ogm|flv|wmv)
				adders+=" -map $A:a -map $A:v -filter_complex ${video_overlay/[X/[$A}"
				;;
			svg)	tui-status 1 "Not supportet: ${OPTARG/*.}" ; exit $?	;;
			*)	# Audio & Subtitle stream files
				adders+=" -map $A"
				;;
			esac
			A=$(( A+1 ))
			[ -z "$out_str" ] && \
				ADDERS+=" -i '$OPTARG'" || \
				ADDERS+=" -i '$OPTARG' $ARG"
			;;
		A)	ADVANCED=true
			log_msg="set ADVANCED=$ADVANCED"
			;;
		b)	char="${OPTARG:0:1}"
			case "$char" in
			a)	log_msg="Override audio bitrate ($BIT_AUDIO) with ${OPTARG:1}"
				BIT_AUDIO="${OPTARG:1}"
				;;
			v)	log_msg="Override video bitrate ($BIT_VIDEO) with ${OPTARG:1}"
				BIT_VIDEO="${OPTARG:1}"
				;;
			*)	log_msg="You did not define whether its audio or video: -$opt a|v$OPTARG"
				tui-status 1 "$log_msg"
				exit 1
				;;
			esac
			;;
		B)	BIT_AUDIO=$audio_bit
			BIT_VIDEO=$video_bit
			log_msg="Using bitrates from $CONFIG (A:$BIT_AUDIO V:$BIT_VIDEO )"
			;;
		c)	char="${OPTARG:0:1}"
			case "$char" in
			a)	override_audio_codec=true
				log_msg="Override audio codec ($audio_codec) with ${OPTARG:1}"
				audio_codec_ov="${OPTARG:1}"
				;;
			t)	override_sub_codec=true
				log_msg="Override subtitle codec ($video_codec) with ${OPTARG:1}"
				sub_codec_ov="${OPTARG:1}"
				;;
			v)	override_video_codec=true
				log_msg="Override video codec ($video_codec) with ${OPTARG:1}"
				video_codec_ov="${OPTARG:1}"
				;;
			*)	log_msg="You did not define whether its audio or video: -$opt a|v|s$OPTARG"
				tui-status 1 "$log_msg"
				exit 1
				;;
			esac
			;;
		C)	$showHeader && tui-header "$ME ($script_version)" "$(date +'%F %T')"
			showHeader=false
			log_msg="Entering configuration mode"
			MenuSetup
			source "$CONFIG"
			;;
		d)	# -af volume=-3dB
			#doVolume=true
			case "${OPTARG:0:1}" in
			"-"|"+")
				VOL="-af volume=${OPTARG}dB"
				;;
			*)
				VOL="-af volume=${OPTARG}"
				;;
			esac
			
			;;
		D)	MODE=dvd
			log_msg="Options: Set MODE to ${MODE^}"
			override_container=true
			tui-status -r 2 "Reading from DVD"
			name="$(blkid|sed s," ","\n",g|$GREP LABEL|sed 's,LABEL=,,'|sed s,\",,g)"
			;;
		e)	override_container=true
			log_msg="Overwrite \"$container\" to file extension: \"$OPTARG\""
			container="$OPTARG"
			;;
		E)	EXTRA_CMD="$OPTARG"
			;;
		f)	useFPS=true
			FPS_ov="$OPTARG"
			doLog "Force using $FPS_ov FPS"
			;;
		F)	useFPS=true
			doLog "Force using FPS from config file ($FPS)"
			;;
		G)	MODE=guide
#			OF=$(tui-str-genfilename "$XDG_VIDEOS_DIR/guide-out.$container" $ext)
			log_msg="Options: Set MODE to ${MODE^}"
			;;
		h)	doLog "Show Help"
			printf "$help_text"
			exit $RET_HELP
			;;
		i)	# Creates $TMP.info
			for A in "${@}";do
			if [ -f "$A" ]
			then	$beVerbose && tui-echo "Video exist, showing info"
				tui-printf -rS 2 "Retrieving data from ${A##*/}"
				StreamInfo "$A" > "$TMP.info.2"
				
				$doStream && \
					tui-title "Next title: ${A##*/}"  || \
					tui-title "Input: ${A##*/}"
				$GREP -v "\--version" "$TMP.info.2" | while read line;do tui-echo "$line";done
			else	$beVerbose && tui-echo "Input '$A' not found, skipping..." "$SKIP"
			fi
			done
			log_msg="Options: Showed info of $@ videos"
			exit $RET_DONE
			;;
		I)	# TODO
			ID_FORCED+="$OPTARG "
			log_msg="Options: Foced to use this id: $ID_FORCED"
			;;
		j)	useJpg=true
			log_msg="Use attached images"
			;;
		J)	doJoin=true
			;;
		K)	#tui-header "$ME ($script_version)" "$(date +'%F %T')"
			tui-title "VHS Task Killer"
			RAW=""
			fine=""
			RAW=$(ps -ha|$GREP -v $GREP|$GREP -e vhs -e ffmpeg |$GREP  bgj|$AWK '{print $8}')
			for R in $RAW;do [ "" = "$(echo $fine|$GREP $R)" ] && fine+=" $R";done

			tui-echo "Please select which tasks to end:"
			
                        TASK=$(tui-select Abort $fine)
			printf "\n"
			[ "$TASK" = Abort ] && tui-echo "Thanks for aborting ;)" && exit
			tui-printf -Sr 2 "Ending task: $TASK"

			pids=$(ps -ha|$GREP "$TASK"|$GREP -v $GREP|$AWK '{print $1}')
			for p in $pids;do kill $p;done
			tui-status $? "Ended $TASK"
			exit $?
			;;
		l)	log_msg="Adding '$OPTARG' to the list of language: $langs"
			langs+=" $OPTARG"
			;;
		L)	doLog "Show Logfile"
			sleep 0.1
			less "$LOG"
			exit $RET_DONE
			;;
		O)	log_msg="Forced Output File -> $OPTARG"
			OF_FORCED="$OPTARG"
			;;
		p)	# Picture in Picure alignments
			log_msg="Picture in Picure alignment"
			# default :: '[0:v:0] scale=320:-1 [a] ; [1:v:0][a]overlay'
			num=$(printf $OPTARG|tr -d [[:alpha:]])
			char=$(printf $OPTARG|tr -d [[:digit:]])
			
			[ -z "$num" ] && \
				pip_scale=320 || pip_scale=$num
				
			pip_h=$[ ( $pip_scale * 9 ) / 16 ]
			
			GS=$(getRes screen)
			W=${GS/x*/}
			H=${GS/*x/}
			horizont_center=$[ ( $H / 2 ) - ( $pip_scale / 2 )  ]
			width_center=$[ ( $W / 2 ) - ( $pip_scale / 2 )  ]
			
			case $char in
			# Tops
			tl)	# Default
				guide_complex="'[0:v:0] scale=$pip_scale:-1 [a] ; [1:v:0][a]overlay'"
				video_overlay="'[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay'"
				#image_overlay=""
				;;
			tc)	guide_complex="'[0:v:0] scale=$pip_scale:-1 [a] ; [1:v:0][a]overlay=$width_center:main_h-overlay_h-$[ $H - $pip_h ]'"
				video_overlay="'[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$width_center:main_h-overlay_h-$[ $H - $pip_h ]'"
				#image_overlay="=[0:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$width_center:main_h-overlay_h-$[ $H - $pip_h ]"
				;;
			tr)	guide_complex="'[0:v:0] scale=$pip_scale:-1 [a] ; [1:v:0][a]overlay=$[ $W - $pip_scale ]:main_h-overlay_h-$[ $H - $pip_h ]'"
				video_overlay="'[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$[ $W - $pip_scale ]:main_h-overlay_h-$[ $H - $pip_h ]'"
				#image_overlay="=[1:v:0]overlay=$[ $W - $pip_scale ]:main_h-overlay_h-$[ $H - $pip_h ]"
				;;
			# Bottoms
			bl)	guide_complex="'[0:v:0] scale=$pip_scale:-1 [a] ; [1:v:0][a]overlay=0:main_h-overlay_h-0'"
				video_overlay="'[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=0:main_h-overlay_h-0'"
				#image_overlay="=[1:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=0:main_h-overlay_h-0"
				;;
			bc)	guide_complex="'[0:v:0] scale=$pip_scale:-1 [a] ; [1:v:0][a]overlay=$width_center:main_h-overlay_h-0'"
				video_overlay="'[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$width_center:main_h-overlay_h-0'"
				#image_overlay="[1:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$width_center:main_h-overlay_h-0"
				;;
			br)	guide_complex="'[0:v:0] scale=$pip_scale:-1 [a] ; [1:v:0][a]overlay=$[ $W - $pip_scale ]:main_h-overlay_h-0'"
				video_overlay="'[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$[ $W - $pip_scale ]:main_h-overlay_h-0'"
				#image_overlay="=[1:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$[ $W - $pip_scale ]:main_h-overlay_h-0"
				;;
			# Special centers
			cl)	guide_complex="'[0:v:0] scale=$pip_scale:-1 [a] ; [1:v:0][a]overlay=0:main_h-overlay_w-$horizont_center'"
				video_overlay="'[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=0:main_h-overlay_w-$horizont_center'"
				#image_overlay="=[1:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=0:main_h-overlay_w-$horizont_center"
				;;
			cc)	guide_complex="'[0:v:0] scale=$pip_scale:-1 [a] ; [1:v:0][a]overlay=$width_center:main_h-overlay_w-$horizont_center'"
				video_overlay="'[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$width_center:main_h-overlay_w-$horizont_center'"
				#image_overlay="=[1:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$width_center:main_h-overlay_w-$horizont_center"
				;;
			cr)	guide_complex="'[0:v:0] scale=$pip_scale:-1 [a] ; [1:v:0][a]overlay=$[ $W - $pip_scale ]:main_h-overlay_w-$horizont_center'"
				video_overlay="'[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$[ $W - $pip_scale ]:main_h-overlay_w-$horizont_center'"
				#image_overlay="=[X:v:0] scale=$pip_scale:-1 [a] ; [0:v:0][a]overlay=$[ $W - $pip_scale ]:main_h-overlay_w-$horizont_center"
				;;
			esac
			
			log_msg+=", orietiation: $char @ $num"
			;;
		P)	log_msg="Stream: Playmode enabled"
			$doPlay && doSelect=true && PlayFile=false #&& echo $PlayFile
			doPlay=true
			doStream=true
			[ -z "$COUNTER_STREAM_PLAY" ] && \
				COUNTER_STREAM_PLAY=1 || \
				COUNTER_STREAM_PLAY=$(( $COUNTER_STREAM_PLAY + 1 ))
			;;
		q)	Q=$(getQualy "$OPTARG")
			RES=$(getRes $OPTARG)
			RES=${RES/x*/:-1}
			C=0
			for n in $Q;do 
				[ $C -eq 1 ] && BIT_VIDEO=$n && break # Just to be sure
				[ $C -eq 0 ] && BIT_AUDIO=$n && ((C++))
			done
			log_msg="Set Quality to $BIT_AUDIO for audio, and $BIT_VIDEO for video bitrates"
			
			;;
		Q)	RES=$(getRes $OPTARG)
			Q=$(getQualy "$OPTARG")
			C=0
			for n in $Q;do 
				[ $C -eq 1 ] && BIT_VIDEO=$n && break # Just to be sure
				[ $C -eq 0 ] && BIT_AUDIO=$n && ((C++))
			done
			log_msg="Set Quality to $OPTARG ($RES) with $BIT_AUDIO for audio, and $BIT_VIDEO for video bitrates"
			;;
		R)	useRate=true
			log_msg="Force audio_rate to $audio_rate"
			;;
		r)	audio_rate="$OPTARG"
			useRate=true
			log_msg="Force audio_rate to $audio_rate"
			;;
		s)	RES="$OPTARG"
			log_msg="Scale video to $RES"
			;;
		S)	MODE=screen
			#OF=$(tui-str-genfilename "$XDG_VIDEOS_DIR/webcam-out.$container" $ext)
			log_msg="Set MODE to ${MODE^}, saving as $OF"
			;;
		t)	useSubs=true
			log_msg="Use subtitles ($langs)"
			;;
		T)	log_msg="Changed delay between jobs from \"$sleep_between\" to \"$OPTARG\""
			sleep_between="$OPTARG"
			;;
		u)	URL="$OPTARG"
			log_msg="Stream: Using $URL"
			## $GREP -q "$URL" "$URLS" || echo "$URL" >> "$URLS"
			doStream=true
			PlayFile=false
			;;
		U)	$doStream && doSelect=true
			doStream=true
			PlayFile=false
			log_msg="Stream: Using an existing URL"
			[ -z "$COUNTER_STREAM_STREAM" ] && \
				COUNTER_STREAM_STREAM=1 || \
				COUNTER_STREAM_STREAM=$(( $COUNTER_STREAM_STREAM + 1 ))
			;;
		v)	log_msg="Be verbose (ffmpeg)!"
			FFMPEG="$ffmpeg_verbose"
			showFFMPEG=true
			;;
		V)	log_msg="Be verbose ($ME)!"
			beVerbose=true
			tui-title "Retrieve options"
			optLogVerb="v"
			;;
		w)	web="-movflags faststart"
			log_msg="Moved 'faststart' flag to front, stream/web optimized"
			;;
		W)	MODE=webcam
			override_container=true
			#OF=$(tui-str-genfilename "$XDG_VIDEOS_DIR/webcam-out.$container" $ext)
			log_msg="Options: Set MODE to Webcam" #, saving as $OF"
			;;
		x)	$showHeader && tui-header "$ME ($script_version)" "$TITLE" "$(date +'%F %T')"
			tui-printf "Clearing logfile" "$TUI_WORK"
			printf "" > "$LOG"
			tui-status $? "Cleaned logfile"
			showHeader=false
			#exit $?
			;;
		X)	$showHeader && tui-header "$ME ($script_version)" "$TITLE" "$(date +'%F %T')"
			showHeader=false
			if tui-yesno "Are you sure to remove '$CONFIG_DIR'?"
			then	rm -fr "$CONFIG_DIR"
				exit $?
			fi
			;;
		y)	override_audio_codec=true
			override_sub_codec=true
			override_video_codec=true
			video_codec_ov=copy
			audio_codec_ov=copy
			sub_codec_ov=copy
			log_msg="Just copy streams, no encoding"
			;;
		z)	t_secs=""
			t_mins=""
			
			SS_START="${OPTARG/-*/}"
			SS_END="${OPTARG/*-/}"
			
			if [ "$SS_START" = "$SS_END" ]
			then	# They are equal, endtime minute must be increased"
				t_mins="${SS_END/:*/}"
				t_secs="${SS_END/*:/}"
				((t_mins++))
				SS_END="$t_mins:$t_secs"
			fi
			#z_cur=${#TIMEFRAME[@]}
			#count=$(( $z_cur - 1 ))
			TIMEFRAME=" -ss $SS_START -to $SS_END"
			log_msg="Set starttime to \"$SS_START\" and endtime to \"$SS_END\""
			;;
		Z)	# ZONE
			shift
			doZone=true
			if [ Z = "$OPTARG" ] && [ -z "$Z_TOP" ]
			then	screen_zone=$(tui-conf-get "$CONFIG" screen_zone|sed s,'"',,g)
				Z_TOP=$(echo $screen_zone | $AWK '{print $1}')
				Z_LEFT=$(echo $screen_zone | $AWK '{print $2}')
				Z_HEIGHT=$(echo $screen_zone | $AWK '{print $3}')
				Z_WIDTH=$(echo $screen_zone | $AWK '{print $4}')
				shift
			else
				( [ -z "$4" ] || [ ! -z "$(echo $4 | tr -d [:digit:])" ] ) && echo "Usage: $ME -Z TOP LEFT WIDTH HEIGHT" && exit 1
				Z_TOP=$1
				Z_LEFT=$2
				Z_WIDTH=$3
				Z_HEIGHT=$4
				shift 4
				screen_zone="$Z_TOP $Z_LEFT $Z_WIDTH $Z_HEIGHT"
			fi
			;;
		*)	log_msg="Invalid argument: $opt : $OPTARG"
			exit
			;;
		esac
		#$beVerbose && tui-echo "$log_msg"
		doLog "Options: $log_msg"
	done
	shift $(($OPTIND - 1))
#
#	First handling of arguments
#
	$showHeader && \
		tui-header \
			"$ME ($script_version)" \
			"$TITLE" "$(date +'%F %T')"
	case "$1" in
	calc)	bit_calculator $2 $3 $4
		exit $?
		;;
	ip|myip)
		myIp
		exit $?
		;;
	build-ffmpeg)
		build_ffmpeg
		exit $?
		;;
	esac
	# Edit the URL files
	[ -z "$COUNTER_STREAM_STREAM" ] && COUNTER_STREAM_STREAM=0
	[ -z "$COUNTER_STREAM_PLAY" ] && COUNTER_STREAM_PLAY=0
	if [ $COUNTER_STREAM_PLAY -eq 3 ]
	then	tui-echo "Edit $URLS.play"
		tui-edit "$URLS.play"
		exit $?
	elif [ $COUNTER_STREAM_STREAM -eq 3 ]
	then	tui-echo "Edit $URLS.stream"
		tui-edit "$URLS.stream"
		exit $?
	fi
	ARGS=("${@}")
	if [ ! -z "$ADDERS" ] && [ ! -z "$ADDED_VIDEO" ]
	then	[ -z "$guide_complex" ] && \
		tui-echo "Must pass '-p ORIENTATION' when including a videostream" "$TUI_INFO" && \
		exit 1 
	fi
#
#	Little preparations before we start showing the interface
#
	$doStream && container=mpegts
	doLog "Loading: $container"
	#set -x 
	LoadContainer "$container"
	#set +x ; exit
	doLog "FFMPEG: $FFMPEG"
	cmd_all="$FFMPEG"
			
	
	if [ ! -z "$video_codec" ] 
	then	# There is a video codec
		$override_video_codec && \
			cmd_video_all+=" -c:v $video_codec_ov" || \
			cmd_video_all+=" -c:v $video_codec"
		# Set video resolution only if codec is not copy
		[ ! copy = "$video_codec_ov" ] && \
			[ ! -z "$RES" ] && \
			cmd_video_all+=" -vf scale=$RES"
		if [ ! -z "$BIT_VIDEO" ]
		then	buffer="-minrate $[ 2 * ${BIT_VIDEO} ]K -maxrate $[ 2 * ${BIT_VIDEO} ]K -bufsize ${BIT_VIDEO}K"
			cmd_video_all+=" -b:v ${BIT_VIDEO}K $buffer"		# Set video bitrate if requested
		fi
		if $useFPS
		then	[ -z "$FPS_ov" ] || FPS="$FPS_ov"
			cmd_video_all+=" -r $FPS"
		fi
		# codec requires strict, toggle by container
		$code_extra && extra+=" -strict -2"
	else	# There is NO video
		MODE=audio
		cmd_video_all+=" -vn"
		[ -z "${audio_codec/-/}" ] && \
			tui-printf -S 1 "Without video, an audio codec is required!" && \
			exit 1
		#set -x
		if $doStream
		then	# Its a stream, use the 'default' audio codec
			container=$(tui-conf-get $CONFIG container_audio)
			LoadContainer $container
			doLog "Loading: $container"
		fi
		#echo "--> $ext <--" > /dev/stderr ; exit 99
	fi
	
	doLog "MODE: $MODE"
	[ "$MODE" = screen ] || for v in $(listVideoIDs "$1");do cmd_video_all+=" -map 0:$v";done	# Make sure video stream is used always
	# Already and has to be handled above
	doLog "Video: $cmd_video_all"
	
	if [ ! -z "${audio_codec/-/}" ]
	then	# There is an audio codec
		$override_audio_codec && \
			cmd_audio_all+=" -c:a $audio_codec_ov" || \
			cmd_audio_all+=" -c:a $audio_codec"		# Set audio codec if provided
		[ -z "$BIT_AUDIO" ] || cmd_audio_all+=" -b:a ${BIT_AUDIO}K"		# Set audio bitrate if requested
		$channel_downgrade &&  cmd_audio_all+=" -ac $channels"			# Force to use just this many channels
		if $useRate 
		then	[ $container = flv ] && \
				cmd_audio_all+=" -r 44100" || \
				cmd_audio_all+=" -ar $audio_rate"		# Use default hertz rate
		fi
		# Volumecheck
		[ -z "$VOL" ] || cmd_audio_all+=" $VOL"
		# Check of strict
		$codec_extra && \
			cmd_audio_all+=" -strict -2"
	fi
	doLog "Audio: $cmd_audio_all"
	
	if $useSubs
	then	$override_sub_codec && subtitle="$sub_codec_ov"
		cmd_subtitle_all="-c:s $subtitle"
	else	cmd_subtitle_all="-sn"
	fi
	doLog "Subtitles: $cmd_subtitle_all"
	[ -z "$langs" ] || doLog "Additional Languages: $langs"
	
	F=""
	if $doStream
	then	
		file_extra=true
		if $doPlay
		then	# Print the stream play header only on these conditions
			if $doSelect || ! $PlayFile
			then	tui-title "Stream : Play"
			fi
			if $doSelect
			then	URL=$(tui-select $intPlayRows $($GREP -v ^"#" "$URLS.play"|$AWK '{print $1}'))
			else	if [ -z "$URL" ]
				then	URL=$(tui-conf-get $CONFIG URL_PLAY)
				else	$GREP -q $URL $URLS.play || echo "$URL" >> "$URLS.play"
				fi
			fi	
			log_msg="Stream play:"
		else	tui-title "Stream $MODE : Up"
			if $doSelect
			then	URL=$(tui-select $intPlayRows $($GREP -v ^"#" "$URLS.stream"|$AWK '{print $1}'))
			else	if [ -z "$URL" ]
				then	URL=$(tui-conf-get $CONFIG URL_UP)
				else	$GREP -q "$URL" "$URLS.stream" || echo "$URL" >> "$URLS.stream"
				fi
			fi	
			log_msg="Stream Server:"
		fi
		log_msg+=" $URL"
		OF="$URL"
		F="-f mpegts"
		[ -z "$URL" ] && exit 1
	else	# File extra, toggle by container
		#LoadContainer
		$file_extra && F="-f $ext"
	fi
	doLog "$log_msg"
	# Generate general target
	METADATA="$txt_mjpg -metadata encoded_by=$txt_meta_me"
	cmd_output_all="$METADATA"
	[ -z "$F" ] || cmd_output_all+=" $F"
	
	# Special container treatment
	case "$container" in
	"webm")	threads="$($GREP proc /proc/cpuinfo|wc -l)" && threads=$[ $threads - 1 ] 
		cmd_audio_all+=" -cpu-used $threads"
		cmd_video_all+=" -threads $threads -deadline realtime"
		msg="$container: Found $threads hypterthreads, leaving 1 for system"
		doLog "$msg"
		$beVerbose && tui-echo "$msg"
		;;
#	*)	cmd_video_all+=" $buffer"	;;
	esac
#
##
###
#### SPECIAL MODE & AUDIO EXTRACTION
###
##
#
#
#	Display & Action
#
	$beVerbose && tui-echo "Take action according to MODE ($MODE):"
	case "$MODE" in
	dvd|screen|webcam)
			# TODO For these 3 i can implement the bitrate suggestions...
			$beVerbose && tui-echo "Set outputfile to $OF"
			msg="Beginn:"
			msgA="Generated command for $MODE-encoding in $TMP"
			[ ! -z "$Z_TOP" ] && msgA="${msgA/encoding/encoding ($screen_zones)}"
			doLog "${msgA/ed/ing}"
			case "$MODE" in
			webcam) doWebCam	;;
			screen) #doScreen
				[ -z "$OF" ] && OF=$(tui-str-genfilename "$XDG_VIDEOS_DIR/screen-out.$container" $ext )
				$doStream && OF="$URL"
				msg="Options: Saving as $OF"
				doLog "$msg"
				$beVerbose && tui-echo "$msg"
				msg+=" Capturing"
				[ -z "$DISPLAY" ] && DISPLAY=":0.0"	# Should not happen, setting to default
				if $doZone
				then	# Special treatement
					cmd_input_all="-f x11grab -video_size  ${Z_WIDTH}x${Z_HEIGHT} -i $DISPLAY+${Z_LEFT},${Z_TOP} -f $sound -i default"
				else	# Default
					cmd_input_all="-f x11grab -video_size  $(getRes screen) -i $DISPLAY -f $sound -i default"
				fi
				cmd="$cmd_all $cmd_input_all $EXTRA_CMD $cmd_video_all $cmd_audio_all $web $extra $METADATA $F \"${OF}\""
				cmd="$cmd_all $cmd_input_all $EXTRA_CMD $cmd_video_all $cmd_audio_all $web $extra $METADATA $F \"${OF}\""
				printf "$cmd" > "$TMP"
				doLog "Screenrecording: $cmd"
				$beVerbose && tui-echo "$msgA"
				;;
			dvd)	tempdata=( $(ls /run/media/$USER 2>/dev/zero) )
				[ ${#tempdata[@]} -ge 2 ] && \
					tui-echo "Please select which entry is the DVD:" && \
					name=$(tui-select "${tempdata[@]}") && \
					printf "\n"
				[ -z "$name" ] && \
					tui-status -r 2 "Scanning for DVD" && \
					name="$(blkid|$SED s," ","\n",g|$GREP LABEL|$SED 's,LABEL=,,'|$SED s,\",,g)"
				$beVerbose && tui-echo "Name selected:" "$name"

				if [ -z "$name" ]
				then	name=$(tui-read "Please enter a name for the DVD:")
				else	[ "PARTBasic" = $(echo $name|$AWK '{print $1}') ] && \
						tui-printf -S 1 "Please insert a DVD and try again!" && \
						exit 1
				fi
				OF=$(tui-str-genfilename "$XDG_VIDEOS_DIR/dvd-$name.$container" $ext )
				[ -f "$dvd_tmp/vobcopy.bla" ] && rm "$dvd_tmp/vobcopy.bla"
				doDVD
				[ -f "$dvd_tmp/vobcopy.bla" ] && rm "$dvd_tmp/vobcopy.bla"
				;;
			esac
			
			doLog "$msgA"
			if $ADVANCED
			then	tui-echo "Please save the file before you continue"
				tui-edit "$TMP"
				tui-press "Press [ENTER] when ready to encode..."
			fi
			
			tui-status ${RET_INFO:-111} "Press 'CTRL+C' to stop recording the $MODE..."
			if $doStream
			then	tui-bgjob "$TMP" "Streaming $MODE to '$OF'" "Saved to '$OF'"
				RET=$?
			else	if ${doScreen:-false}
				then	tui-bgjob -f "$OF" "$TMP" "Saving to '$OF' ($screen_zone)" "Saved to '$OF'"
					RET=$?
				else	doExecute "$TMP" "$OF" "Saving to '$OF'" "Saved to '$OF'"
					RET=$?
				fi
			fi
			[ $MODE = dvd ] && \
				[ -f "$dvd_tmp/vobcopy.bla" ] && \
				rm "$dvd_tmp/vobcopy.bla"
			
			if [ $RET -eq 0 ]
			then	# All good, clean up temp data...
				doLog "Successfully encoded $mode"
				if [ -z "$TIMEFRAME" ]
				then	# But only if the whole dvd was encoded
					if [ ! -z "$dvd_tmp" ] && [ -d "$dvd_tmp" ]
					then	cd "$dvd_tmp"
						LC_ALL=C ; export LC_ALL
						numTotal=$($LS -lh|$GREP total|$AWK '{print $2}')
						LC_ALL="" ; export LC_ALL
						
						if tui-yesno "Removing temporary data? ($numTotal)"
						then	[ "$PWD" = "$dvd_tmp" ] && \
								rm -fr *vob
						fi
					fi
				fi
			else	doLog "Failed to encode $mode"
			fi
			exit $RET
			;;
	guide)		[ -z "$ext" ] && source $CONTAINER/$container
			[ -z "$OF" ] && OF=$(tui-str-genfilename "$XDG_VIDEOS_DIR/guide-out.$container" $ext )
			$doStream && OF="$URL"
			cmd="$cmd_all -f v4l2 -s $webcam_res -framerate $webcam_fps -i /dev/video0 $EXTRA_CMD -f x11grab -video_size  $(getRes screen) -framerate $FPS -i :0 -f $sound -i default -filter_complex $guide_complex -c:v $video_codec -crf 23 -preset veryfast -c:a $audio_codec -q:a 4 $extra $METADATA $F \"$OF\""
			
			printf "$cmd" > "$TMP"
			
			tui-status $RET_INFO "Press 'CTRL+C' to stop recording the $MODE..."
			if $ADVANCED
			then	tui-echo "Please save the file before you continue"
				tui-edit "$TMP"
				tui-press "Press [ENTER] when read to encode..."
			fi
			doLog "Command-Guide: $(cat $TMP)"
			$doStream && \
				tui-bgjob "$TMP" "Streaming 'Guide' to '$OF'" "Streamed 'Guide' to '$OF'" || \
				doExecute "$TMP" "$OF" "Encoding 'Guide' to '$OF'" "Encoded 'Guide' to '$OF'"
			
			exit $?
		;;
#video)		echo just continue > /dev/zero	;;
	*)	[ -z "$1$URL" ] && \
			printf "$help_text" && \
			exit 1
		;;
	esac
# Join files	
	if $doJoin
	then	declare -a JOIN_VIDS
		declare -i C=0
		declare ORG_VID="$1"
		OLD_EXT="${1##*./}"
		NEW_ORG=$(tui-str-genfilename "$ORG_VID" $ext)
		TMP_JOIN=$(tui-str-genfilename "joined_files.mpg")
		
		tui-title "Appending/Joining $# Videos"
		tui-echo "Step 1: Creating temp files"
		for item in "${@}"
		do	this=$(tui-str-genfilename "$item" mpg)
			JOIN_VIDS[$C]="$this"
			N=$C
			C=$(( $C + 1 ))
			cmd="$FFMPEG -i \"$item\" -qscale:v 1 \"$this\""
			$beVerbose && tui-echo "Executing:" "$cmd"
			if $showFFMPEG
			then	eval $cmd
			else	echo "$cmd" > "$TMP"
				tui-bgjob -f "${JOIN_VIDS[$N]}" -s "$item" "$TMP" "Creating tempfile: $this #$C..." "Created tempfile: $this #$C."
				doLog "Join-Temp: Created #$C: $this with exit code $?"
			fi
		done
		
		tui-echo
		tui-echo "Step 2: Merging"
		string=""
		for V in "${JOIN_VIDS[@]}";do
			[ -f "$V" ] && string+="$V|"
		done
		string="${string:0:(-1)}"
		
		cmd="$FFMPEG -i concat:\"$string\" -c copy \"$TMP_JOIN\""
		doLog "Join-Merge: $cmd"
		$beVerbose && tui-echo "Executing:" "$cmd"
		if $showFFMPEG
		then	eval $cmd
		else	echo "$cmd" > "$TMP"
			tui-bgjob -f "$TMP_JOIN" "$TMP" "Merging tempfiles..." "Merged tempfiles."
		fi
		
		# Remove unrequired files
		for V in "${JOIN_VIDS[@]}";do
			rm "$V"
			tui-status $? "Deleted $V"
		done
		
		tui-echo
		tui-echo "Step 3: Finalize"
		
		new=$(tui-str-genfilename "$TMP_JOIN" $ext)
		doLog "Join-Final: Now starting to encode to custom settings."
		unset ARGS[@]
		ARGS[0]="$TMP_JOIN"
		EXTRA_CMD="-qscale:v 2"
		doLog "Join-Final: Adding \"$EXTRA_CMD\" to command."
	fi
	if $doStream && ! $PlayFile && ! $doPlay
	then	[ -z "$FFSERVER_CONF" ] && FFSERVER_CONF=/share/doc/ffmpeg/ffserver.conf
		ps -hau | $GREP -v $GREP | $GREP -q ffserver || ffserver -f $FFSERVER_CONF &
		case "$MODE" in
		dvd|screen|webcam)	# Requirement met
			echo failure
			exit $?
			;;
		video|audio)
			if [ -z "$1$URL" ]
			then	doLog "Stream: Aborting, no $MODE file passed"
				tui-status 1 "Must pass a file to stream!"
				exit $?
			fi
			;;
		*)	tui-echo "Mode is currently set to: $MODE"
			tui-status 1 "Required mode is either: Screen, Webcam or Guide"
			exit $?
			;;
		esac
	fi
#
#
##
###
#### HERE THE ACTUAL VIDEO ENCODING STARTS
###
##
#
#	Show menu or go for the loop of files
#
	wait_now=false
	cmd_video_all_outside="$cmd_video_all"
	cmd_audio_all_outside="$cmd_audio_all"
	$PlayFile && URL=""
	for video in "${ARGS[@]}" "$URL" ;do 
		# Only wait for 2nd loop and later
		if $wait_now
		then	doLog "--------------------------------"
			msg="Timeout - $sleep_between between encodings..."
			[ ! -z "$sleep_between" ] && \
				doLog "Script : $msg" && \
				tui-echo && tui-wait $sleep_between "$msg" #&& tui-echo
			# Show empty log entry line as optical divider
			doLog ""
		fi
		
if $doPlay
then	#$doSelect && [ -z "$URL" ] && \
	#	tui-echo "Please select an url you want to replay:" && \
	#	URL=$(tui-select $intPlayRows $($GREP -v ^"#" "$URLS.play" | $AWK '{print $1}' ))
	[ -z "$URL$1" ] && tui-printf -S 1 "-P requires either '-U' or '-u URL' or a file to play!" && exit 1
	# Audio or Video?
	$showFFMPEG && \
			strPlayType=video || strPlayType=audio
	$showFFMPEG && \
		showdisp="-fs" && \
		doLog "Stream: Play, expecting video..." || \
		showdisp="-nodisp"
	# Show title and write command
	if [ -z "$1" ]
	then	tui-title "Playing $strPlayType stream" #&& PlayFilesShown=true
		echo "ffplay -v quiet -window_title \"VHS ($script_version) : Play $strPlayType Stream : $URL\" -i \"$URL?buffer=5\" $showdisp || exit 1" > "$TMP"
	else	! $PlayFilesShown && tui-title "Playing $strPlayType file" && PlayFilesShown=true
		echo "ffplay -v quiet -window_title \"VHS ($script_version) : Play $strPlayType File : $video\" -i \"$video\" $showdisp || exit 1" > "$TMP"
	fi
	# Edit before executing?
	if $ADVANCED
	then	tui-edit "$TMP"
		tui-press
	fi
	doLog "Stream: Play-Command:" "$(<$TMP)"
	# Show video handling keys before the status bar
	$showFFMPEG && \
		! $VideoInfoShown && \
		tui-list -n 	"q) Quit/Next" "f) Toggle Fullscreen" "p) Pause" \
				"a) Cycle Audio streams" "v) Cycle video streams" "t) Cycle Subtitles" \
				"LEFT/RIGHT) Seek back-forwards 10 secs" "UP/DOWN) Seek back-/forwards 1 min" && \
		VideoInfoShown=true
	sleep 0.001
	# Start the backgroundjob and playstatus AFTER printed keys
	if [ -z "$1" ]
	then	tui-bgjob "$TMP" "Streaming from: $URL" "Saving bandwith as i cant reach: $URL..." 1.5
		RET=$?
	else	#tui-bgjob "$TMP" "Playing $video ($PT)..." "Done playing $1" 1.5
		PlayStatus "$video"
		RET=$?
		continue
	fi
	exit $RET
fi
		
		# Start initial log per video to parse
		doLog "----- $video -----"
		$beVerbose && tui-title "Video: $video"
		$doStream && \
			OF="$URL" || \
			OF=$(tui-str-genfilename "${video}" "$ext")		# Output File
		audio_ids=						# Used ids for audio streams
		audio_maps=""						# String generated using the audio maps
		subtitle_ids=""
		subtitle_maps=""
		found=0							# Found streams per language
		cmd_audio_maps=""
		cmd_audio_all="$cmd_audio_all_outside"
		cmd_video_all="$cmd_video_all_outside"
		cmd_input_all="-i \\\"$video\\\""				
		cmd_output_all="$F \\\"$OF\\\""
		cmd_run_specific=""					# Contains stuff that is generated per video
		cmd_audio_external=""					# 
	#
	#	Output per video
	#
		$doStream && \
			$0 -Ui "$video" || \
			$0 -i "$video"
			#tui-title "Next title: $video" #&& \
		#	( $0 -i "$video" )  > /dev/zero && \
		#	sleep 0.5 || \
			#$0 -Ui "$video"	# Calling itself with -info for video
		
		if ! $GREP -i "video:" -q "$TMP.info" # | $GREP -q video # || ! $GREP video "$TMP"
		then	tui-echo "No Video found!"
			MODE=audio
			
			container=$(tui-conf-get $CONFIG container_audio)
			LoadContainer $container
			doLog "Loading: $container"
			
			cmd_video_all="-nv"
			#cmd_audio_all=" -c:a $audio_codec"		# Set audio codec if provided
			[ -z "$BIT_AUDIO" ] || cmd_audio_all+=" -b:a ${BIT_AUDIO}K"		# Set audio bitrate if requested
			#$channel_downgrade &&  cmd_audio_all+=" -ac ${channels:-2}"			# Force to use just this many channels
			if $useRate 
			then	[ $container = flv ] && \
					cmd_audio_all+=" -r 44100" || \
					cmd_audio_all+=" -ar $audio_rate"		# Use default hertz rate
			fi
		fi
		
		
		PT=$(PlayTimeSecs)
		echo "$BIT_AUDIO$BIT_VIDEO" | $GREP -q [0-9] && \
			EXPECTED="$(( ( ${PT:-1} * ( $BIT_VIDEO + $BIT_AUDIO ) ) * 1024 / 8))" || \
			EXPECTED=$(fs_expected)
		
		
		# Allthough this applies to all vides, give the user at least the info of the first file
		#for n in 123 105 101 137 167 141 163 137 150 145 162 145;do printf \\$n > /dev/stdout;done
		if [ "" != "$(echo $num|tr -d [:alpha:])" ]
		then	num="${RES/[x:]*/}"
			[ -z "$num" ] && num=3840

			if [ 3840 -lt $num ]
			then	tui-echo
				tui-status 111 "Attention, encoding higher than 4k/uhd (your value: $RES) may cause a system freeze!"
				tui-yesno "Continue anyway?" || exit 0
			fi
		fi
		
		if $useJpg
		then	tui-echo
			tui-echo "Be aware, filesize update might seem to be stuck, it just writes the data later..." "$TUI_INFO"
			tui-echo
			for i in $(listAttachents);do
				txt_mjpg+=" -map 0:$i"
			done
		fi
	
	# Audio	
		tui-echo
		#echo "" > "$TMP"
		doAudio "$video"					## Fills the list: audio_ids
		audio_ids=$(cat "$TMP") 
		
		if [ "$MODE" = audio ]
		then	# Handle just audio files, and loop
			$doStream && OF="$URL"
			for AID in $audio_ids;do
			# Generate command
				if ! $doStream
				then	[ -z "$video_codec" ] && \
						OF=$(tui-str-genfilename "$video" $ext) || \
						OF=$(tui-str-genfilename "${video}" id-$AID.$ext)
				fi
				tOF=$(basename "$OF")
				audio_maps=" -map 0:$AID"
					
				$doStream && \
					cmd="$FFMPEG -i \"$video\" $EXTRA_CMD $cmd_audio_all $audio_maps $extra -vn $TIMEFRAME $METADATA -y -f $ext \"$URL\"" || \
					cmd="$FFMPEG -i \"$video\" $EXTRA_CMD $cmd_audio_all $audio_maps $extra -vn $TIMEFRAME $METADATA -y \"$OF\""
			# Display progress	
				$doStream || tui-echo "Saving audio stream: $AID"

				printf "$cmd" > "$TMP"
				if $ADVANCED
				then	tui-echo "Please save the file before you continue"
					tui-edit "$TMP"
					tui-press "Press [ENTER] when read to encode..."
				fi
				doLog "Command-Audio: $cmd"

				if $doStream
				then	tui-bgjob "$TMP" "Streaming \"$video:$AID\" to \"$URL\"" "Streamed $video-$AID to \"$URL\""
				else	doExecute "$TMP" "$OF" "Encoding to \"$OF\"" "Encoded audio to \"$tOF\""
				fi
			done
			continue	# Its just video, continue with next passed argument
		else 	# Regular video handling
			if [ ! -z "$ID_FORCED" ]
			then	# Just this one ID
				$beVerbose && tui-echo "However, this ID is forced:" "$ID_FORCED"
			# Generate command
				for AID in $ID_FORCED;do
					audio_maps+=" -map 0:$AID"
				done
				$beVerbose && tui-echo "Outputfile will be:" "$OF"
				$doStream && \
					OF="$URL" && \
					cmd="$FFMPEG -i \"$video\" $cmd_video_all $EXTRA_CMD $cmd_audio_all $audio_maps  $TIMEFRAME $METADATA $extra -y -f mp3 \"$OF\"" || \
					cmd="$FFMPEG -i \"$video\" $cmd_video_all $EXTRA_CMD $cmd_audio_all $audio_maps  $TIMEFRAME $METADATA $extra -y \"$OF\""
				printf "$cmd" > "$TMP"
			#	if $ADVANCED
			#	then	tui-echo "Please save the file before you continue"
			#		tui-edit "$TMP"
			#		tui-press "Press [ENTER] when read to encode..."
			#	fi
				doLog "Command-Audio: $(cat $TMP)"
			# Execute	
			#	if $doStream
			#	then	tui-bgjob "$TMP" "Streaming \"$video\" to \"$OF\"" "Streamed $video to \"$OF\""
			#	else	doExecute "$TMP" "$OF" "Encoding \"$tIF\" to \"$OF\"" "Encoded audio to \"$tOF\""
			#	fi
			#	exit $?
			else	# Parse all available audio streams
				doLog "Audio: Found $audio_ids audio streams"
				for AID in $audio_ids;do
				# Generate command
					[ $countAudio -eq 1 ] && \
						audio_maps="-map 0:$AID" || \
						audio_maps+=" -map 0:$AID"
				done
			fi
			cmd_audio_all+=" $audio_maps"
		fi
## Copied end
		msg="Using for audio streams: $audio_ids"
		doLog "$msg"
	# Subtitles
		tmp_of="${OF##*/}"
		tmp_if="${video##*/}"
		if [ "$MODE" = video ]
		then	doLog "Video: Parse sub"
			if $useSubs
			then	doSubs > /dev/zero
				$beVerbose && tui-echo "Parsing for subtitles... ($subtitle_ids)"
				subtitle_list=$(cat "$TMP") 			## Fills the list: subtitle_maps, if used
				if [ ! -z "$subtitle_list" ]
				then # all good
					for i in $subtitle_ids;do subtitle_maps+=" -map 0:$i";done
				else	# handle empty
					tui-echo "No subtitle stream could be recognized"
					tui-echo "Please select the ids you want to use, choose done to continue."
					select i in $subtitle_ids done;do 
						[ "$i" = done ] && break
						subtitle_ids+=" $i"
						tui-echo "Now using subtitles ids: $subtitle_ids"
					done
				fi
			fi
	#
	#	Handle video pass 1 if 2 enabled
	#
		# 2-Pass encoding enabled?
			if [ $PASS -eq 2 ]
			then	# Do first pass if 2 pass
				STR2="Encoded \"$tmp_if\" pass 2/2" # to \"$tmp_of\""
				STR1="Encoding \"$tmp_if\" pass 2/2" # to \"$tmp_of\""

				STR2pass1="Encoded \"$tmp_if\" pass 1/2"
				STR1pass1="Encoding \"$tmp_if\" pass 1/2" # to ffmpeg2pass-0.log.mbtree"

				cmd2pass="$FFMPEG -i \"${video}\" -an -pass 1 -y -vcodec $video_codec  -map 0:v -f rawvideo  /dev/null" #/dev/zero" # \"$tmp_of\"" # -f rawvideo -y /dev/null
				echo "$cmd2pass" > "$TMP"
				doLog "Command-Video-Pass1: $cmd2pass"
				#doExecute "$TMP" "ffmpeg2pass-0.log.mbtree" "$STR1pass1" "$STR2pass1" || exit 1
				tui-bgjob "$TMP"  "$STR1pass1" "$STR2pass1" || exit 1
			else	STR2="Encoded to \"$tmp_of\"" # \"$tmp_if\"
				STR1="Encoding to \"$tmp_of\"" # \"$tmp_if\"
			fi
		else	# Its just audio
			OF=
		fi
	#
	#	Handle video pass 2 or only one
	#
		# Make these strings match onto a single line
		tmp_border=$[ ${#TUI_BORDER_LEFT} + ${#TUI_BORDER_RIGHT} + 8 + 4 + 8 ]	# Thats TUI_BORDERS TUI_WORK and 4 space chars + filesize
		string_line=$[ ${#tmp_if} + ${#tmp_of} + $tmp_border ]
		# Currently shortens every file... :(
		if [ $string_line -gt $(tput cols) ]
		then	tmp_if="${tmp_if:0:${#tmp_if}/4}...${tmp_if:(-6)}"
			tmp_of="${tmp_of:0:${#tmp_of}/4}...${tmp_of:(-6)}"
		fi
		oPWD="$(pwd)"
	# Verify file does not already exists
	# This is not required, its just a failsafe catcher to blame the enduser when he confirms to overwrite an exisiting file
		skip=false
		if [ -f "$OF" ]
		then 	tui-echo "ATTENTION: Failsafe catcher!"
			if tui-yesno "Outputfile ($OF) exists, overwrite it?"
			then 	[ -f "$OF" ] && rm -f "$OF"
			else	skip=true
			fi
		fi
	# Skip if it was not removed
		if ! $skip
		then
		#
		#	Execute the command
		#
			# Command just needs to be generated
			$useSubs && cmd_run_specific+=" $cmd_subtitle_all $subtitle_maps"
			if $doStream
			then	#echo todo
				OF="$URL"
				## ffmpeg -i "$input" -f mpegts udp://$ip:$port
				[ $MODE = video ] && ext=mpegts #&& tui-header oh no
				tVID=${video##*/}
				#set -x
				[ -z "$COLUMNS" ] && COLUMNS=$(tput cols)
				[ $(( 2 * ${#tVID} )) -gt $COLUMNS ] && \
					tVIDa=${tVID:0:${#tVID}/4} && \
					tVIDb=${tVID:${#tVID}/4*3}:${#tVID}/4} && \
					tVID="$tVIDa...$tVIDb"
				STR1="Streaming $tVID as $MODE to $OF"
				#for n in 123 105 101 137 167 141 163 137 150 145 162 145;do printf \\$n > /dev/stdout;done
				STR1="Streaming $tVID to $OF"
				cmd="$cmd_all $cmd_input_all $EXTRA_CMD $ADDERS $web $extra $cmd_video_all $txt_mjpg $cmd_audio_all $cmd_run_specific $cmd_audio_maps $TIMEFRAME $METADATA $adders -f $ext $URL"
				#cmd="$FFMPEG -i \"$video\" -f mpegts $URL"
				printf "$cmd" > "$TMP"
				#cat "$TMP" ; exit
			else	cmd="$cmd_all $cmd_input_all $EXTRA_CMD $ADDERS $web $extra $cmd_video_all $txt_mjpg $cmd_audio_all $cmd_run_specific $cmd_audio_maps $TIMEFRAME $METADATA $adders $cmd_output_all"
			fi
			doLog "Command-Simple: $cmd"
			msg+=" Converting"
		
			if ! $doStream
			then	printf "$cmd" > "$TMP"
				if $ADVANCED
				then	tui-echo "Please save the file before you continue"
					tui-edit "$TMP"
					tui-press "Press [ENTER] when ready to encode..."
				fi
			fi
			$showFFMPEG && tui-echo "Executing:" "$(cat $TMP)"
			
			if $showFFMPEG && ! $doStream
			then	#echo run here?
				$SHELL "$TMP"
				RET=$?
			else	#echo run there?
				$beVerbose && \
					tui-echo "Due to the nature of encoding files, the old filesize usualy doesnt match the new file its size." && \
					tui-echo "The progress bar is only ment for a rough visual orientation for the encoding progress."
				#echo stream $doStream
				#echo ffmpeg $showFFMPEG
			##	exit
				if $doStream && ! $showFFMPEG
				then	tui-bgjob "$TMP" "$STR1" "$STR2"
					RET=$?
				elif $showFFMPEG
				then	tui-bgjob "$TMP" "$STR1" "$STR2"
					RET=$?
				elif [ 0 -eq $EXPECTED ] #&& [ ! -z "$EXPECTED_FILE_SIZE2"
				then	tui-bgjob -f "$OF" "$TMP" "$STR1" "$STR2"
					RET=$?
				else	
					#tui-bgjob -f "$OF" -s "$video" "$TMP" "$STR1" "$STR2"
					tui-bgjob -f "$OF" -e "$EXPECTED" "$TMP" "$STR1" "$STR2"
					RET=$?
				fi
			fi
			echo "$tmp" > /dev/zero
			# Remove tempfiles from 2pass 
			if [ $PASS -gt 1 ]
			then	for f in ffmpeg2pass-*.log*
				do	rm $f
					tui-status $? "Removed $f"
				done
			fi
			# Remove tempfile from joining...
			if $doJoin
			then	
				if [ -f "$new" ]
				then	tui-mv "$new" "$NEW_ORG"
					tui-status $? "Your final file is: $NEW_ORG" && \
						rm "$TMP_JOIN" #&& rm "$new"
					RET=$?
					#exit $?
				else	tui-status $? "Could not find expected $new"
					tui-status $? "Exiting now, leaving tempfiles behind..."
					exit $?
				fi
			fi
		#
		#	Do some post-encode checks
		#	
			if [ mkv = $container ] && [ $RET -eq 0 ] && [ $PASS -ge 2 ]
			then	# Set default language if mkv encoding was a successfull 2-pass
				lang2=$(listIDs|$GREP Audio|$GREP ^${audio_ids:0:1}|$AWK '{print $2}')
				[ ${#lang2} -gt 3 ] && \
					tui-echo "Could not determine proper langauge, probably it wasnt labled before" "$FAIL" && \
					lang2=$(echo $lang2|$AWK '{print $1}') && \
					tui-echo "Labeling it as '$lang2', eventhough that might be wrong" && \
					lang=$lang2 #|| \
					#lang=$lang2
				msg="* Set first Audiostream as enabled default and labeling it to: $lang"
				tui-printf -rS 2 "$msg"
				#tui-echo "aid $aid .$audio_ids"
				aid="$(showHeader=false vhs -i \"$OF\" |$GREP Audio|while read hash line stream string drop;do echo ${string:3:-1};done)"
				#aid=1
				doLog "Audio : Set default audio stream $aid"
				case "$container" in
				mkv)	mkvpropedit -q "$OF"	--edit track:a$aid --set flag-default=0 \
							--edit track:a$aid --set flag-enabled=1 \
							--edit track:a$aid --set flag-forced=0 \
							--edit track:a$aid --set language=$lang
					;;
				esac
				tui-status $? "$msg"
			fi
			#Generate log message
			[ 0 -eq $RET ] && \
				ret_info="successfully (ret: $RET) \"$OF\"" || \
				ret_info="a faulty (ret: $RET) \"$OF\""
		#
		#	Log if encode was successfull or not
		#
			doLog "End: Encoded $ret_info "
			wait_now=true
		else	msg="Skiped: $video"
			doLog "$msg"
			tui-status 4 "$msg"
		fi
	done
#
#	Clean exit
#
	[ -z "$oPWD" ] || cd "$oPWD"
	[ ! -z "$dvd_tmp" ] && [ -d "$dvd_tmp" ] && \
		tui-yesno "There are remaining tempfiles from dvd encoding, remove them now?" && \
		rm -fr "$dvd_tmp"
	if [ -z "$1$URL" ]
	then 	printf "$help_text"
		exit $RET_HELP
	fi
exit 0
# for n in 123 105 101 137 167 141 163 137 150 145 162 145;do printf \\$n ;done
