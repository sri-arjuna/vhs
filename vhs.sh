#!//usr/bin/env bash
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
#	Changed:	2015.03.11
#	Description:	All in one movie handler, wrapper for ffmpeg
#			Simplyfied commands for easy use
#			The script is designed (using the -Q toggle) use create the smallest files with a decent quality
#			
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
	S=$(which tui) 2>/dev/zero 1>/dev/zero
	if [ ! -f "$S" ]
	then 	[ ! 0 -eq $UID ] && \
			printf "\n#\n#\tPlease restart the script as root to install TUI (Text User Interface).\n#\n#\n" && \
			exit 1
		if ! git clone https://github.com/sri-arjuna/tui.git /tmp/tui.inst
		then 	mkdir -p /tmp/tui.inst ; cd /tmp/tui.inst/
			curl --progress-bar -L https://github.com/sri-arjuna/tui/archive/master.zip -o master.zip
			unzip master.zip && rm -f master.zip
			mv tui-master/* . ; rmdir tui-master
		fi
    		if ! sh /tmp/tui.inst/install.sh
    		then	printf "\n#\n#\tPlease report this issue of TUI installation fail.\n#\n#\n"
			exit 1
		fi
    	fi
    	source $S ; S=""
#
#	Get XDG Default dirs
#
	X="$HOME/.config/user-dirs.dirs"
	[ -f "$X" ] && source "$X" || tui-status $? "Missing XDG default dirs configuration file, using: $HOME/Videos"
	# Setting default videos dir and create it if none is present
	[ -z "$XDG_VIDEOS_DIR" ] && XDG_VIDEOS_DIR="$HOME/Videos" && ( [ -d "$XDG_VIDEOS_DIR" ] || mkdir -p "$XDG_VIDEOS_DIR" )
#
#	Script Environment
#
	ME="${0##*/}"				# Basename of $0
	ME_DIR="${0/\/$ME/}"			# Cut off filename from $0
	ME="${ME/.sh/}"				# Cut off .sh extension
	script_version=1.3.4
	TITLE="Video Handler Script"
	CONFIG_DIR="$HOME/.config/$ME"		# Base of the script its configuration
	CONFIG="$CONFIG_DIR/$ME.conf"		# Configuration file
	CONTAINER="$CONFIG_DIR/containers"	# Base of the container definition files
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
	ADDED_VIDEO=false
	ADVANCED=false
	showFFMPEG=false		# -v 	Debuging help, show the real encoder output
	beVerbose=false			# -V 	Show additional steps done
	doCopy=false			# -C
	doExternal=false		# -E
	override_audio_codec=false	# -c a	/ -C
	override_sub_codec=false	# -c s	/ -C
	override_video_codec=false	# -c v	/ -C
	override_container=false	# -e ext
	useFPS=false			# -f / -F
	useRate=false			# -R
	useSubs=false			# -t
	useJpg=false			# -j
	codec_extra=false		# Depends on container /file extension
	file_extra=false		# Depends on container /file extension
	# Values - 
	MODE=video			# -D, -W, -S, -e AUDIO_EXT	audio, dvd, webcam, screen, guide
	ADDERS=""			# Stream to be added / included
	cmd_all=""
	#cmd_data=""			# Actualy, ffmpeg uses the datastream by default.
	cmd_audio_all=""
	cmd_audio_maps=""
	cmd_audio_rate=""
	cmd_input_all=""
	cmd_output_all=""
	cmd_subtitle_all=""
	cmd_video_all=""
	langs=""			# -l LNG 	will be added here
	PASS=1				# -p 		toggle multipass video encoding, also 1=disabled
	RES=""				# -d		dimension will set video resolution if provided
	OF=""				#		Empty: Output File
	ffmpeg_silent="ffmpeg -v quiet" # [-V]		Regular or debug verbose
	ffmpeg_verbose="ffmpeg -v verbose"	# -v		ffmpeg verbose
	hwaccel="-hwaccel vdpau"	# NOT USED -H		Enable hw acceleration
	txt_meta_me="'Encoded by VHS ($TITLE $script_version - (c) 2014-2015 by sea), using $(ffmpeg -version|$GREP ^ffmpeg|sed s,'version ',,g)'"
	txt_mjpg=""
	FPS_ov=""			# -f NUM -- string check
	SS_START=""			# -z 1:23[-1:04:45.15] start value, triggered by beeing non-empty
	SS_END=""			# -z 1:23[-1:04:45.15] calculated end value
	TIMEFRAME=""			# the codesegment containg the above two variables.
	# Default overlays
	guide_complex="'[0:v:0]scale=320:-1[a] ; [1:v:0][a]overlay'"
	video_overlay="'[X:v:0]scale=320:-1[a] ; [0:v:0][a]overlay'"
#
#	Check for PRESETS, required for proper help display
#
	WritePresetFile() { #
        # Write a basic table of the presets
        # 
	cat > "$PRESETS" << EOF
# Presets 'RES' configuration, there must be no empty line or output will fail.
# Label	Resolution 	Vidbit	Audbit	1min	Comment	(Up to 7 elements/words)
scrn	resolve 	1024	256	8.9mb	This is only used for screenrecording
a-vga	  640x480	512	196	5.2mb	Anime optimized, VGA
a-dvd	  720x576	640	256	6.7mb	Anime optimized, DVD-wide - PAL
a-hd	 1280x720	768	256	7.2mb	Anime optimized, HD
a-fhd	1920x1080	1280	256	12.5mb	Anime optimized, Full HD
qvga	  320x240	240	128	2.7mb	Quarter of VGA, mobile devices 
hvga	  480x320	320	192	3.8mb	Half VGA, mobile devices
nhd	  640x360	512	256	5.6mb	Ninth of HD, mobile devices
vga	  640x480	640	256	6.6mb	VGA
dvdr	  720x480	744	384	8.3mb	DVD-regular - PAL
dvd	  720x576	768	384	8.5mb	DVD-wide - Pal
fwvga	  854x480	768	384	7.5mb	DVD-wide - NTCS, mobile devices
hd	 1280x720	1280	384	12.1mb	HD aka HD Ready
fhd	1920x1080	2560	448	21.8mb	Full HD
qhd	2560x1440	3840	448	30.9mb	2k, Quad HD - 4xHD
uhd	3840x2160	7680	512	59.2mb	4K, Ultra HD TV
# Below are presets which fail on (freeze!) my machine.
# Feel free to uncomment the below 4 lines at your own risk.
#uhd+	5120x2880	14400	768	??.?mb	5K, UHD+
#fuhd	7680x4320	32160	1280	??.?mb	8K, Full UHD TV
#quhd	15360x8640	128720	1280	??.?mb	16k, Quad UHD - 4xUHD
#ouhd	30720x17380	512000	2048	??.?mb	32k, Octo UHD - 8xUHD, my suggestion
#
# It is strongly recomended to NOT modify the youtube preset bitrates or resolutions,
# as they are set that high to meet google its standard: 
# See:	https://support.google.com/youtube/answer/1722171?hl=en
# for more details.
#
yt-240	  426x240	768	196	6.8mb	YT, seriously, no reason to choose
yt-360	  640x360	1000	196	8.7mb	YT, Ninth of HD, mobile devices
yt-480	  854x480	2500	196	19.6mb	YT, DVD-wide - NTCS, mobile devices
yt-720	 1280x720	5000	512	39.9mb	YT, HD
yt-1080	1920x1080	8000	512	61.1mb	YT, Full HD
yt-1440	2560x1440	10000	512	75.2mb	YT, 2k, Quad HD - 4xHD
yt-2160	3840x2160	40000	512	325.7mb	YT, 4K, Ultra HD TV
EOF
	}
	[ -f "$PRESETS" ] || \
		WritePresetFile
#
#	Help text
#
	BOLD="$TUI_FONT_BOLD"
	RESET="$TUI_COLOR_RESET"
help_text="
$ME ($script_version) - ${TITLE^}
Usage: 		$ME [options] filename/s ...

Examples:	$ME -C				| Enter the configuration/setup menu
		$ME -b ${BOLD}a${RESET}128 -b ${BOLD}v${RESET}512 filename	| Encode file with audio bitrate of 128k and video bitrate of 512k
		$ME -c ${BOLD}a${RESET}AUDIO -c ${BOLD}v${RESET}VIDEO -c ${BOLD}s${RESET}SUBTITLE filename	| Force given codecs to be used for either audio or video (NOT recomended, but as bugfix for subtitles!)
		$ME -e mp4 filename		| Re-encode a file, just this one time to mp4, using the input files bitrates
		$ME -[S|W|G]			| Record a video from Screen (desktop) or Webcam, or make a Guide-video placing the webcam stream as pip upon a screencast
		$ME -l ger			| Add this language to be added automaticly if found (applies to audio and subtitle (if '-t' is passed)
		$ME -Q fhd filename		| Re-encode a file, using the screen res and bitrate presets for FullHD (see RES info below)
		$ME -Bjtq fhd filename		| Re-encode a file, using the bitrates from the config file, keeping attachment streams and keep subtitle for 'default 2 languages' if found, then forcing it to a Full HD dimension

Where options are: (only the first letter)
	-h(elp) 			This screen
	-2(-pass)			Enabled 2 Pass encoding: Video encoding only (Will fail when combinied with -y (copy)!)
	-a(dd)		FILE		Adds the FILE to the 'add/inlcude' list, most preferd audio- & subtitle files (images can be only on top left position, videos 'anywhere' -p allows ; just either one Or the other at a time)
	-A(dvanced)			Will open an editor before executing the command
	-b(itrate)	[av]NUM		Set Bitrate to NUM kilobytes, use either 'a' or 'v' to define audio or video bitrate
	-B(itrates)			Use bitrates (a|v) from configuration ($CONFIG)
	-c(odec)	[atv]NAME	Set codec to NAME for audio, (sub-)title or video, can pass '[atv]copy' as well
	-C(onfig)			Shows the configuration dialog
	-d(imension)	RES		Sets to ID-resolution, but keeps aspect-ratio (:-1) (will probably fail, use AFTER '-Q RES')
	-D(VD)				Encode from DVD (not working since code rearrangement)
	-e(xtension)	CONTAINER	Use this container (ogg,webm,avi,mkv,mp4)
	-f(ps)		FPS		Force the use of the passed FPS
	-F(PS)				Use the FPS from the config file (25 by default)
	-G(uide)			Capures your screen & puts Webcam as PiP (default: top left @ 320), use -p ARGS to change
	-i(nfo)		filename	Shows a short overview of the video its streams and exits
	-I(d)		NUM		Force this audio ID to be used (if multiple files dont have the language set)
	-j(pg)				Thought to just include jpg icons, changed to include all attachments (fonts, etc)
	-K(ill)				Lets you select the job to kill among currenlty running VHS jobs.
	-l(anguage)	LNG		Add LNG to be included (3 letter abrevihation, eg: eng,fre,ger,spa,jpn)
	-L(OG)				Show the log file
	-p(ip)		LOCATION[NUM]	Possible: tl, tc, tr, br, bc, bl, cl, cc, cr ; optional appending (NO space between) NUM would be the width of the PiP webcam
	-q(uality)	RES		Encodes the video at ID's bitrates from presets
	-Q(uality)	RES		Sets to ID-resolution and uses the bitrates from presets, video might become sctreched
	-r(ate)		48000		Values from 48000 to 96000, or similar
	-R(ate)				Uses the frequency rate from configuration ($CONFIG)
	-S(creen)			Records the fullscreen desktop
	-t(itles)			Use default and provided langauges as subtitles, where available
	-T(imeout)	2m		Set the timeout between videos to TIME (append either 'm' or 'h' as other units)
	-v(erbose)			Displays encode data from ffmpeg
	-V(erbose)			Show additional info on the fly
	-w(eb-optimized)		Moves the videos info to start of file (web compatibility)
	-W(ebcam)			Record from webcam
	-x(tract)			Clean up the log file
	-X(tract)			Clean up system from $ME-configurations
	-y(copY)			Just copy streams, fake convert
	-z(sample)  1:23[-1:04:45[.15]	Encdodes a sample file which starts at 1:23 and lasts 1 minute, or till the optional endtime of 1 hour, 4 minutes and 45 seconds


Info:
------------------------------------------------------
After installing codecs, drivers or plug in of webcam,
it is highy recomended to update the list file.
You can do so by entering the Setup dialog: $ME -C
and select 'UpdateLists'.

Values:
------------------------------------------------------
NUM:		Number for specific bitrate (ranges from 96 to 15536
NAME:		See '$LIST_FILE' for lists on diffrent codecs
RES:		These bitrates are ment to save storage space and still offer great quality, you still can overwrite them using something like ${BOLD}-b v1234${RESET}.
		Use '${BOLD}-q${RESET} LABEL' if you want to keep the original bitrates, use '${BOLD}-Q${RESET} LABEL' to use the shown bitrates and aspect ratio below.
		Also, be aware that upcoding a video from a lower resolution to a (much) higher resolution brings nothing but wasted diskspace, but if its close to the next 'proper' resolution aspect ratio, it might be worth a try.
		See \"$BOLD$PRESETS$RESET\" to see currently muted ones or to add your own presets.

$( 
        #printf "\t\t$TUI_FONT_UNDERSCORE";$SED s,"#",, "$PRESETS" | $GREP Pix ; printf "$RESET"
	printf "\t\t${TUI_FONT_UNDERSCORE}Label	Resolution 	Pixels	Vidbit	Audbit	Bitrate	1min	Comment$RESET\n"
	
	
	$AWK	'BEGIN  {
			# Prepare Unit arrays
				split ("k M GB", BUNT)
				split ("p K M Gp", PUNT)
				ln10=log(10)	# What is this for?
				#print ln10	## 2.30259
			}

		 # Format input: Number Unit
		 function FMT(NBR, U)
			{
				# Again what for is ln10 used here and XP prepared for? And what is done anwyay?
				XP=int(log(NBR)/ln10/3)
				# print XP # = 1 or 0
				# sprintf is one topic, but what is why done with XP (1 or 0)?
				return sprintf ("%.2f%s", NBR / 10^(3*XP), U[1+XP])
				# I assumed the passed variable, represented by U, will be updated outside, but seems wrong
			}
		# NR==1 , The above is only executed if its the first "loop"/line, or otherwise do....
		NR==1 ||
		# on either leading # comments or the word 'scrn', move onto next loop/line
		/^#/ ||
		/^scrn/ { next } 

		{
		# Bitrates
			bitrate = FMT($3+$4, BUNT)
			# How can i check for the current line its UNT value?
			if("B" == U) { 		# This still prints output, but doesnt do the changes wanted
			##if("B" == BUNT) {	# This way it prints absolute nothing ??
					split(bitrate,B,".")
					bitrate=B[1]
				}
		# Pixels
			split($2, A, "x")
			pixels = FMT(A[1] * A[2], PUNT);
			
		# Output
			print "\t\t"BOLD$1RESET,$2 "   ",pixels, $3 ,$4, bitrate ,"~"$5,$6" "$7" "$8" "$9" "$10" "$11" "$12#" "$13" "$14; " "$15;
		
	}' BOLD="\033[1m" RESET="\033[0m" OFS="\t" "$PRESETS"
)

CONTAINER (a):	aac ac3 dts flac mp3 ogg vorbis wav wma
CONTAINER (v):  avi flv mkv mp4 mpeg ogv theora webm wmv xvid
VIDEO:		[/path/to/]videofile
LOCATIoN:	tl, tc, tr, br, bc, bl, cl, cc, cr :: as in :: top left, bottom right, center center
LNG:		A valid 3 letter abrevihation for diffrent langauges
HRZ:		44100 *48000* 72000 *96000* 128000
TIME:		Any positive integer, optionaly followed by either 's', 'm' or 'h'

For more information or a FAQ, please see ${BOLD}man vhs${RESET}.

Files:		
------------------------------------------------------
Script:		$0
Config:		$CONFIG
Containers:	$CONTAINER/*
Lists:		$LIST_FILE
Log:		$LOG
Presets:	$PRESETS

"

#
#	Functions
#
	doLog() { # "MESSAGE STRING"
	# Prints: Time & "Message STRING"
	# See 'tui-log -h' for more info
		tui-log -t "$LOG" "$1"
	}
	StreamInfo() { # VIDEO
	# Returns the striped down output of  ffmpeg -psnr -i video
	# Highly recomend to invoke with "vhs -i VIDEO" then use "$TMP.info"
		ffmpeg  -psnr -i "$1" 1> "$TMP.info" 2> "$TMP.info"
		$GREP -i stream "$TMP.info" | $GREP -v @ | $GREP -v "\--version"
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
		[ -z "$1" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		eval $cmd|$GREP -i audio|wc -l
	}
	countSubtitles() { # [VIDEO]
	# Returns the number of subtitles found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[ -z "$1" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		eval $cmd|$GREP -i subtitle|wc -l
	}
	hasLang() { # LANG [VIDEO] 
	# Returns true if LANG was found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[ -z "$2" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|$GREP -i audio|$GREP -q -i "$1"
		return $?
	}
	hasLangDTS() { # LANG [VIDEO] 
	# Returns true if LANG was found in VIDEO and declares itself as DTS
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[ -z "$2" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|$GREP -i audio|$GREP -i $1|$GREP -q DTS
		return $?
	}
	hasSubtitle() { # LANG [VIDEO] 
	# Returns true if LANG was found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[ -z "$2" ] && \
			cmd="$GREP -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|$GREP -i subtitle|$GREP -q -i $1
		return $?
	}
	listIDs() { # [VIDEO]
	# Prints a basic table of stream ID CONTENT (and if found) LANG
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
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
	genFilename() { # Filename_with_ext container
	# Parses for file extension and compares with new container
	# If identical, add a number to avoid overwriting sourcefile.
		[ $# -lt 2 ] && tui-echo "Requires 'filename-with.ext' and 'extension/container'." "$FAIL" && return 1
		video="$1"
		container="$2"
		# TODO find better way to get extension
		for ext in $(printf "$video"|sed s,"\."," ",g);do printf "" > /dev/zero;done
		[ "$ext" = "$video" ] && ext="$container" && video="$video.$container"
		
		if [ ! "$ext" = "$container" ]
		then 	outputfile="${video/$ext/$container}"
			[ ! -f "$outputfile" ] && \
				doLog "Output: \"$outputfile\"" && \
				printf "$outputfile" && return 0 || \
				name="${video/$ext/}"
		else	name="${video/$container/}"
		fi
		
		# new file name would be the same
		N=0
		while [ -f "$name$N.$container" ] ; do ((N++));done
		outputfile="$name$N.$container"
		doLog "Output: Has same extension, incrementing to \"$outputfile\""
		printf "$outputfile"
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
				sh "$1" || \
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
		0)	msg="No audio streams found, aborting!"
			tui-status 1 "$msg"
			doLog "$msg"
			exit $RET_FAIL
			;;
		1)	tui-echo "Using only audio stream found..." "$DONE"
			audio_ids=$(listAudioIDs)
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
						1)	audio_ids="$this"	;;
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
			cmd="$FFMPEG $vobs -acodec $audio_codec -vcodec $video_codec $extra $yadif $METADATA $F \"${OF}\""
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
			BIG="$(ls $dvd_tmp/*.vob)"
			
			# Show info on video
			vhs -i "$BIG"
			
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
						[ "$i" = "done" ] || audio_ids+=" $i"
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
			cmd="$FFMPEG -probesize 50M -analyzeduration 100M -i $BIG                    -q:a 0 -q:v 0 $web $extra $bits -vcodec $video_codec $cmd_video_all -acodec $audio_codec $cmd_audio_all $yadif $TIMEFRAME $METADATA $F \"${OF}\""
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
		
		#set -x
		if cd "$1"
		then	if [ ! "" = "$( ls |$GREP -i vob)" ] && tui-yesno "Delete existing vob files?"
			then	#echo $PWD ; set -x
				rm -f *vob 	#2>/dev/zero
				rm -f *partial 	#2>/dev/zero
				rm -f vobcopy.bla
				#exit
			fi
			cd "$OLDPWD"
		fi
		
		#showFFMPEG=true
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
			eval "$cmd"
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
                OF="$(genFilename $XDG_VIDEOS_DIR/webcam-out.$container $container)"
                #sweb_audio="-f alsa -i default -c:v $video_codec -c:a $audio_codec"
                web_audio=" -f alsa -i default"
                cmd="$FFMPEG -f v4l2 -s $webcam_res -i $input_video $web_audio $extra $METADATA $F \"${OF}\""
		doLog "WebCam: Using $webcam_mode command"
                doLog "Command-Webcam: $cmd"
		printf "$cmd" > "$TMP.cmd"
		OF="$OF"
		#doExecute "$OF" "Saving Webcam to '$OF'"
	}
	WriteContainers() { # 
	# Writes several container files and their default / suggested values
	#
		$beVerbose && tui-title "Write Containers"
		header="# $ME ($script_version) - Container definition"
		[ -d "$CONTAINER" ] || mkdir -p "$CONTAINER"
		cd "$CONTAINER"
		for entry in aac ac3 avi dts flac flv mpeg mp4 mkv ogg ogv mp3 theora vorbis webm wma wmv wav xvid;do	# clip dvd
			case $entry in
		# Containers
			avi)	# TODO, this is just assumed / memory
				ca=libmp3lame 	# Codec Audio
				cv=msvideo1	# Codec Video
				ce=false	# Codec extra (-strict 2)
				fe=true		# File extra (audio codec dependant '-f ext')
				ba=128		# Bitrate Audio
				bv=384		# Bitrate Video
				ext=$entry	# Extension used for the video file
				;;
			#									## These bitrates are NOT used... !!
			flv)	ca=aac		; cv=flv	; ce=false	; fe=false	; ba=128	; bv=384	; ext=$entry	;;
			mp4)	ca=aac		; cv=libx264	; ce=true	; fe=true	; ba=192	; bv=768	; ext=$entry 	;;
			mpeg)	ca=libmp3lame 	; cv=mpeg2video	; ce=false	; fe=false	; ba=128	; bv=768	; ext=$entry	;;
			mkv)	ca=ac3		; cv=libx264	; ce=false	; fe=false	; ba=256	; bv=1280	; ext=$entry	;;
			ogv)	ca=libvorbis 	; cv=libtheora	; ce=true	; fe=false	; ba=192	; bv=1024	; ext=ogv	;;
			theora)	ca=libvorbis 	; cv=libtheora	; ce=true	; fe=false	; ba=192	; bv=1024	; ext=ogv	;;
			webm)	ca=libvorbis 	; cv=libvpx	; ce=true	; fe=true	; ba=256	; bv=1280	; ext=$entry	;;
			wmv)	ca=wmav2  	; cv=wmv2	; ce=false	; fe=false	; ba=256	; bv=768	; ext=$entry	;;
			xvid)	ca=libmp3lame  	; cv=libxvid	; ce=false	; fe=true	; ba=256	; bv=768	; ext=avi	;;
		# Audio Codecs
			aac)	ca=aac 		; cv=		; ce=false 	; fe=false	; ba=256	; bv=		; ext=$entry	;;
			ac3)	ca=ac3 		; cv=		; ce=false 	; fe=false	; ba=256	; bv=		; ext=$entry 	;;
			dts)	ca=dts 		; cv=		; ce=false 	; fe=false	; ba=512	; bv=		; ext=$entry	;;
			flac)	ca=flac		; cv=		; ce=false 	; fe=false	; ba=512	; bv=		; ext=$entry	;;
			mp3)	ca=libmp3lame	; cv=		; ce=false	; fe=false	; ba=256 	; bv=		; ext=$entry	;;
			ogg)	ca=libvorbis 	; cv=		; ce=false 	; fe=false	; ba=256 	; bv=		; ext=$entry	;;
			vorbis)	ca=libvorbis 	; cv=		; ce=false 	; fe=false	; ba=256 	; bv=		; ext=ogg	;;
			wma)	ca=wmav2  	; cv=		; ce=false	; fe=true	; ba=256	; bv=		; ext=$entry	;;
			wav)	ca=pcm_s16le	; cv=		; ce=false	; fe=false	; ba=384	; bv=		; ext=$entry	;;
		# Experimental
		#	clip)	ca=aac 		; cv=libx264	; ce=true	; fe=true	; ba=128	; bv=384	; ext=mp4	;;
		#	dvd)	ca=mpeg2video 	; cv=mp3	; ce=		; fe=		; ba=128	; bv=512	; ext=mpeg	;;
		#	webcam)	# TODO
		#		ca=mpeg2video ;	cv=mp3		; ce= 		; fe=		; ba=128	; bv=512	; ext=mpeg	;;
			# blob)	ca=	; cv=	; ce=false	; fe=false	; ba=	; bv=	; ext=$entry	;;
			esac
			touch $entry
			tui-printf "Write container info ($entry)" "$WORK"
			printf "$header
ext=$ext
audio_codec=$ca
video_codec=$cv
codec_extra=$ce
file_extra=$fe" > $entry
			if [ 0 -eq $? ] 
			then	tui-status $? "Wrote container info ($entry)"
				doLog "Container: Created '$entry' definitions succeeded" 
			else	tui-status $?  "Wrote container info ($entry)"
				doLog "Container: Created '$entry' definitions failed"
			fi
			$beVerbose && printf "\n"
		done
	}
	UpdateLists() { #
	# Retrieve values for later use
	# Run again after installing new codecs or drivers
		[ -f "$LIST_FILE" ] || touch "$LIST_FILE"
		tui-title "Generating a list file"
		$beVerbose && tui-progress "Retrieve raw data..."
		[ -z "$verbose" ] && verbose="-v quiet"
		ffmpeg $verbose -codecs | $GREP \ DE > "$TUI_TEMP_FILE"
		printf "" > "$LIST_FILE"
		
		for TASK in DEA DES DEV;do
			case $TASK in
			DEA)	txt_prog="Audio-Codecs"	; 	var=codecs_audio 	;;
			DES)	txt_prog="Subtitle-Codecs"; 	var=codecs_subtitle	;;
			DEV)	txt_prog="Video-Codecs"	; 	var=codecs_video	;;
			esac
			tui-progress "Saving $txt_prog"
			raw=$($GREP $TASK "$TUI_TEMP_FILE"|$AWK '{print $2}'|sed s,"\n"," ",g)
			clean=""
			for a in $raw;do clean+=" $a";done
			printf "$var=\"$clean\"\n" >> "$LIST_FILE"
			doLog "Lists: Updated $txt_prog"
		done
		
		tui-progress "Saving Codecs-Format"
		ffmpeg $verbose -formats > "$TUI_TEMP_FILE"
		formats_raw=$($GREP DE "$TUI_TEMP_FILE"|$AWK '{print $2}'|sed s,"\n"," ",g)
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
container=mkv

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

# Subtitle
subtitle=ssa

# How long to wait by default between encodings if multiple files are queued?
# Note that 's' is optional, and could be as well either: 'm' or 'h'.
sleep_between=1m

# This is a default value that should work on most webcams
# Please use the script's Configscreen (-C) to change the values
# Default values are for res: 640x480
# Default values are for fps: 25
webcam_res=640x480
webcam_fps=25
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
			ReWriteContainers) WriteContainers ;;							
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
							tui-echo "Do you want to enable this?"
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
		WriteContainers
                WriteTemplateFile
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
	while getopts "2a:ABb:c:Cd:De:f:FGhHi:I:jKLl:O:p:Rr:SstT:q:Q:vVwWxXyz:" opt
	do 	case $opt in
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
				ARG=" -filter_complex 'overlay$image_overlay'"
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
		C)	tui-header "$ME ($script_version)" "$(date +'%F %T')"
			log_msg="Entering configuration mode"
			MenuSetup
			source "$CONFIG"
			;;
		d)	RES=$(getRes $OPTARG|sed s/x*/":-1"/g)
			log_msg="Set video dimension (resolution) to: $RES"
			;;
		D)	# TODO very low prio, since code restructure probably dont work
			MODE=dvd
			log_msg="Options: Set MODE to ${MODE^}"
			override_container=true
			tui-status -r 2 "Reading from DVD"
			name="$(blkid|sed s," ","\n",g|$GREP LABEL|sed 's,LABEL=,,'|sed s,\",,g)"
			;;
		e)	override_container=true
			log_msg="Overwrite \"$container\" to file extension: \"$OPTARG\""
			container="$OPTARG"
			;;
		f)	useFPS=true
			FPS_ov="$OPTARG"
			doLog "Force using $FPS_ov FPS"
			;;
		F)	useFPS=true
			doLog "Force using FPS from config file ($FPS)"
			;;
		G)	MODE=guide
		#	guide_complex="'[0:v:0] scale=320:-1 [a] ; [1:v:0][a]overlay'"
			log_msg="Options: Set MODE to ${MODE^}, saving as $OF"
			;;
		h)	doLog "Show Help"
			printf "$help_text"
			exit $RET_HELP
			;;
		i)	# Creates $TMP.info
			#shift $(($OPTIND - 1))
			for A in "${@}";do
			if [ -f "$A" ]
			then	$beVerbose && tui-echo "Video exist, showing info"
				tui-printf "Retrieving data from ${A##*/}" "$WORK"
				StreamInfo "$A" > "$TMP.info.2"
				tui-title "Input: ${A##*/}"
				$GREP -v "\--version" "$TMP.info.2" | while read line;do tui-echo "$line";done
			else	$beVerbose && tui-echo "Input '$A' not found, skipping..." "$SKIP"
			fi
			done
			log_msg="Options: Showed info of $@ videos"
			exit $RET_DONE
			;;
		I)	# TODO
			ID_FORCED+="$OPTARG"
			log_msg="Options: Foced to use this id: $ID_FORCED"
			;;
		j)	useJpg=true
			log_msg="Use attached images"
			;;
		K)	tui-header "$ME ($script_version)" "$(date +'%F %T')"
			tui-title "VHS Task Killer"
			RAW=""
			fine=""
			RAW=$(ps -ha|$GREP -v $GREP|$GREP -e vhs -e ffmpeg |$GREP  bgj|$AWK '{print $8}')
			for R in $RAW;do [ "" = "$(echo $fine|$GREP $R)" ] && fine+=" $R";done

			tui-echo "Please select which tasks to end:"
			
                        TASK=$(tui-select Abort $fine)
			printf "\n"
			[ "$TASK" = Abort ] && tui-echo "Thanks for aborting ;)" && exit
			tui-printf -Sr 2 "Ending task: $TASK" #"$TUI_WORK"

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
			log_msg="Force audio_rate to $audio_rate"
			;;
		S)	MODE=screen
			log_msg="Set MODE to ${MODE^}, saving as $OF"
			;;
		t)	useSubs=true
			log_msg="Use subtitles ($langs)"
			;;
		T)	log_msg="Changed delay between jobs from \"$sleep_between\" to \"$OPTARG\""
			sleep_between="$OPTARG"
			;;
		v)	log_msg="Be verbose (ffmpeg)!"
			FFMPEG="$ffmpeg_verbose"
			showFFMPEG=true
			;;
		V)	log_msg="Be verbose ($ME)!"
			FFMPEG="$ffmpeg_silent"
			beVerbose=true
			tui-title "Retrieve options"
			;;
		w)	web="-movflags faststart"
			log_msg="Moved 'faststart' flag to front, stream/web optimized"
			;;
		W)	MODE=webcam
			OF=$(genFilename "$XDG_VIDEOS_DIR/webcam-out.$container" $ext )
			override_container=true
			log_msg="Options: Set MODE to Webcam, saving as $OF"
			;;
		x)	tui-header "$ME ($script_version)" "$TITLE" "$(date +'%F %T')"
			tui-printf "Clearing logfile" "$TUI_WORK"
			printf "" > "$LOG"
			tui-status $? "Cleaned logfile"
			#exit $?
			;;
		X)	tui-header "$ME ($script_version)" "$TITLE" "$(date +'%F %T')"
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
			TIMEFRAME="-ss $SS_START -to $SS_END"
			
			log_msg="Set starttime to \"$SS_START\" and endtime to \"$SS_END\""
			;;
		*)	log_msg="Invalid argument: $opt : $OPTARG"
			;;
		esac
		$beVerbose && tui-echo "$log_msg"
		doLog "Options: $log_msg"
	done
	shift $(($OPTIND - 1))
	if [ ! -z "$ADDERS" ] && [ ! -z "$ADDED_VIDEO" ]
	then	[ -z "$guide_complex" ] && \
		tui-echo "Must pass '-p ORIENTATION' when including a videostream" "$TUI_INFO" && \
		exit 1 
	fi
#
#	Little preparations before we start showing the interface
#
	src="$CONTAINER/$container" ; source "$src"
	# If (not) set...
	[ -z "$video_codec" ] && [ ! -z $audio_codec ] && MODE=audio		# If there is no video codec, go audio mode
	#[ ! -z "$video_codec" ] && [ $PASS -lt 2 ] && \
	for v in $(listVideoIDs "$1");do cmd_video_all+=" -map 0:$v";done	# Make sure video stream is used always
	$showFFMPEG && \
		FFMPEG="$ffmpeg_verbose" || \
		FFMPEG="$ffmpeg_silent"	# Initialize the final command
	[ -z "$FFMPEG" ] && \
		cmd_all="$ffmpeg_silent" || \
		cmd_all="$FFMPEG"	
	[ -z "$BIT_AUDIO" ] || \
		cmd_audio_all+=" -b:a ${BIT_AUDIO}K"		# Set audio bitrate if requested
	[ -z "$BIT_VIDEO" ] || \
		cmd_video_all+=" -b:v ${BIT_VIDEO}K"		# Set video bitrate if requested
	[ ! copy = "$video_codec_ov" ] && \
		[ ! -z "$RES" ] && \
		cmd_video_all+=" -vf scale=$RES"		# Set video resolution
#	[ -z "$ASP" ] || \
#		cmd_video_all+=" -aspect=$ASP"			# Set video aspect ratio
	[ -z "$OF" ] || \
		cmd_output_all="$OF"				# Set output file 
	[ -z "$BIT_VIDEO" ] || \
		buffer=" -minrate $[ 2 * ${BIT_VIDEO} ]K -maxrate $[ 2 * ${BIT_VIDEO} ]K -bufsize ${BIT_VIDEO}K"
	# Bools...
	$file_extra && \
		F="-f $ext"					# File extra, toggle by container
	$code_extra && \
		extra+=" -strict -2"				# codec requires strict, toggle by container
	$channel_downgrade && \
		cmd_audio_all+=" -ac $channels"			# Force to use just this many channels
	if $useFPS
	then	[ -z $FPS_ov ] || FPS=$FPS_ov
		cmd_video_all+=" -r $FPS"
		doLog "Added '$FPS' to commandlist"
	fi
	$useRate && \
		cmd_audio_all+=" -ar $audio_rate"		# Use default hertz rate
	$override_sub_codec && \
		subtitle=$sub_codec_ov
	$useSubs && \
		cmd_subtitle_all=" -c:s $subtitle" || \
		cmd_subtitle_all=" -sn"
	$override_audio_codec && \
		cmd_audio_all+=" -c:a $audio_codec_ov" || \
		cmd_audio_all+=" -c:a $audio_codec"		# Set audio codec if provided
	if $override_video_codec				# Set video codec if provided
	then	cmd_video_all+=" -c:v $video_codec_ov"
	else	[ -z $video_codec ] || cmd_video_all+=" -c:v $video_codec"				
	fi

	if $beVerbose
	then	tui-echo "MODE:"	"$MODE"
		tui-echo "FFMPEG:"	"$cmd_all"
		tui-echo "Audio:"	"$cmd_audio_all"
		tui-echo "Video:"	"$cmd_video_all"
		tui-echo "Subtitles:"	"$cmd_subtitle_all"
		[ -z $langs ] || tui-echo "Additional Languages:"	"$langs"
	fi
	# Metadata
	METADATA="$txt_mjpg -metadata encoded_by=$txt_meta_me"
	
	# Special container treatment
	case "$container" in
	"webm")	threads="$($GREP proc /proc/cpuinfo|wc -l)" && threads=$[ $threads - 1 ] 
		cmd_audio_all+=" -cpu-used $threads"
		cmd_video_all+=" -threads $threads  -deadline realtime"
		msg="$container: Found $threads hypterthreads, leaving 1 for system"
		doLog "$msg"
		$beVerbose && tui-echo "$msg"
		;;
	flv)	cmd_audio_all+=" -r 44100"	;;
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
	tui-header "$ME ($script_version)" "$TITLE" "$(date +'%F %T')"
	$beVerbose && tui-echo "Take action according to MODE ($MODE):"
	case $MODE in
	dvd|screen|webcam)
			# TODO For these 3 i can implement the bitrate suggestions...
			$beVerbose && tui-echo "Set outputfile to $OF"
			msg="Beginn:"
			msgA="Generated command for $MODE-encoding in $TMP"
			doLog "${msgA/ed/ing}"
			case $MODE in
			webcam) doWebCam	;;
			screen) #doScreen
				OF=$(genFilename "$XDG_VIDEOS_DIR/screen-out.$container" $container )
				msg="Options: Set MODE to Screen, saving as $OF"
				doLog "$msg"
				$beVerbose && tui-echo "$msg"
				msg+=" Capturing"
				[ -z $DISPLAY ] && DISPLAY=":0.0"	# Should not happen, setting to default
				cmd_input_all="-f x11grab -video_size  $(getRes screen) -i $DISPLAY -f $sound -i default"
			##	cmd="$cmd_all $cmd_input_all $ADDERS $web $extra $cmd_video_all $buffer $cmd_audio_all $cmd_run_specific $cmd_audio_maps $TIMEFRAME $METADATA $adders $cmd_output_all"
				cmd="$cmd_all $cmd_input_all $cmd_video_all $buffer $cmd_audio_all $web $METADATA $extra $METADATA $F \"${OF}\""
				#printf "$cmd < /dev/stdin" > "$TMP"
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
				OF=$(genFilename "$XDG_VIDEOS_DIR/dvd-$name.$container" $container )
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
			doExecute $TMP "$OF" "Saving to '$OF'" "Saved to '$OF'"
			RET=$?
			[ $MODE = dvd ] && \
				[ -f "$dvd_tmp/vobcopy.bla" ] && \
				rm "$dvd_tmp/vobcopy.bla"
			
			if [ $RET -eq 0 ]
			then	# All good, clean up temp data...
				doLog "Successfully encoded $mode"
				if [ -z "$TIMEFRAME" ]
				then	# But only if the whole dvd was encoded
					if [ -d "$dvd_tmp" ]
					then	cd "$dvd_tmp"
						LC_ALL=C ; export LC_ALL
						numTotal=$(ls -lh|$GREP total|$AWK '{print $2}')

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
			OF=$(genFilename "$XDG_VIDEOS_DIR/guide-out.$container" $ext )
			
			cmd="$cmd_all -f v4l2 -s $webcam_res -framerate $webcam_fps -i /dev/video0 -f x11grab -video_size  $(getRes screen) -framerate $FPS -i :0 -f $sound -i default -filter_complex $guide_complex -c:v $video_codec -crf 23 -preset veryfast -c:a $audio_codec -q:a 4 $extra $METADATA $F \"$OF\""
			printf "$cmd" > "$TMP"
			
			doLog "Command-Guide: $cmd"
			
			tui-status $RET_INFO "Press 'CTRL+C' to stop recording the $MODE..."
			if $ADVANCED
			then	tui-echo "Please save the file before you continue"
				tui-edit "$TMP"
				tui-press "Press [ENTER] when read to encode..."
			fi
			doExecute "$TMP" "$OF" "Encoding 'Guide' to '$OF'" "Encoded 'Guide' to '$OF'"
			
			exit $?
			;;
	audio)		doAudio "$video"					## Fills the list: audio_ids
			audio_ids=$(cat "$TMP") 
			tui-echo "Found audio ids:" "$audio_ids"
		# Shared vars	
			tDir=$(dirname "$(pwd)/$1")
			tIF=$(basename "$1")
			tui-echo "Audio files are encoded within pwd:" "$tDir"
			
		# If ID is forced, just do this	
			if [ ! -z "$ID_FORCED" ]
			then	# Just this one ID
				tui-echo "However, this ID is forced:" "$ID_FORCED"
			# Generate command
				audio_maps="-map 0:$ID_FORCED"
				[ -z "$OF_FORCED" ] && \
					OF=$(genFilename "${1}" $ext) && OF=${OF/.$ext/.id$ID_FORCED.$ext} || \
					OF=$(genFilename "$OF_FORCED" $ext)
				tOF=$(basename "$OF")
				tui-echo "Outputfile will be:" "$tOF"
				cmd="$FFMPEG -i \"$1\" $cmd_audio_all $audio_maps -vn $TIMEFRAME $METADATA $extra -y \"$OF\""
				printf "$cmd" > "$TMP"
				doLog "Command-Audio: $cmd"
			# Execute
				doExecute "$TMP" "$OF" "Encoding \"$tIF\" to $tOF" "Encoded audio to \"$tOF\""
				exit $?
			else	# Parse all available audio streams
				
				
				for AID in $audio_ids;do
				# Generate command
					OF=$(genFilename "${1}" $ext)
					OF=${OF/.$ext/.id$AID.$ext}
					tOF=$(basename "$OF")
					audio_maps=""
					for i in $FORCED_IDS;do
						audio_maps+=" -map 0:$i"
					done

					cmd="$FFMPEG -i \"$1\" $cmd_audio_all $audio_maps $extra -vn $TIMEFRAME $METADATA -y \"$OF\""
					printf "$cmd" > "$TMP"
					doLog "Command-Audio: $cmd"
				# Display progress	
					tui-title "Saving audio stream: $AID"
					
					if $ADVANCED
					then	tui-echo "Please save the file before you continue"
						tui-edit "$TMP"
						tui-press "Press [ENTER] when read to encode..."
					fi
					doExecute "$TMP" \
						"$OF" \
						"Encoding \"$tIF\" to \"$tOF\"" "Encoded audio to \"$tOF\""
				done
			fi
			
			#$beVerbose && 
			#	tui-echo "Saved as $OF_FORCED, using $ID_FORCED"
			$showFFMPEG && \
				FFMPEG=$ffmpeg_verbose || \
				FFMPEG=$ffmpeg_silent
			
			exit $?
			;;
	# video)		echo just continue	;;
	esac
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
	for video in "${@}";do 
		doLog "----- $video -----"
		$beVerbose && tui-title "Video: $video"
		OF=$(genFilename "${video}" "$ext")		# Output File
		audio_ids=						# Used ids for audio streams
		audio_maps=""						# String generated using the audio maps
		subtitle_ids=""
		subtitle_maps=""
		found=0							# Found streams per language
		cmd_audio_maps=""
		cmd_input_all="-i \\\"$video\\\""				
		cmd_output_all="$F \\\"$OF\\\""
		cmd_run_specific=""					# Contains stuff that is generated per video
		cmd_audio_external=""					# 
	#
	#	Output per video
	#
		$0 -i "$video"						# Calling itself with -info for video
		# Allthough this applies to all vides, give the user at least the info of the first file
		num="${RES/[x:]*/}"
		[ -z "$num" ] && num=3840
		
		if [ 3840 -lt $num ]
		then	tui-echo
			tui-status 111 "Attention, encoding higher than 4k/uhd (your value: $RES) may cause a system freeze!"
			tui-yesno "Continue anyway?" || exit 0
		fi
		
		if $useJpg
		then	tui-echo
			tui-echo "Be aware, filesize update might seem to be stuck, it just writes the data later..." "$TUI_INFO"
			for i in $(listAttachents);do
				txt_mjpg+=" -map 0:$i"
			done
		fi
	
	# Audio	
		tui-echo
		doAudio "$video"					## Fills the list: audio_ids
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
				audio_ids+=" $i"
				cmd_audio_maps+=" -map 0:$i"
				tui-echo "Now using audio ids: $audio_ids"
				tui-echo
			done
		fi
		msg="Using for audio streams: $audio_ids"
		doLog "$msg"
	# Subtitles
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
		tmp_of="${OF##*/}"
		tmp_if="${video##*/}"
		# 2-Pass encoding enabled?
		if [ $PASS -eq 2 ]
		then	# Do first pass if 2 pass
			STR2="Encoded \"$tmp_if\" pass 2/2 to \"$tmp_of\""
			STR1="Encoding \"$tmp_if\" pass 2/2 to \"$tmp_of\""
			
			STR2pass1="Encoded \"$tmp_if\" pass 1/2"
			STR1pass1="Encoding \"$tmp_if\" pass 1/2" # to ffmpeg2pass-0.log.mbtree"
			
			cmd2pass="$FFMPEG -i \"${video}\" -an -pass 1 -y -vcodec $video_codec  -map 0:0 -f rawvideo  /dev/null" #/dev/zero" # \"$tmp_of\"" # -f rawvideo -y /dev/null
			echo "$cmd2pass" > "$TMP"
			doLog "Command-Video-Pass1: $cmd2pass"
			#doExecute "$TMP" "ffmpeg2pass-0.log.mbtree" "$STR1pass1" "$STR2pass1" || exit 1
			tui-bgjob "$TMP"  "$STR1pass1" "$STR2pass1" || exit 1
		else	STR2="Encoded \"$tmp_if\" to \"$tmp_of\""
			STR1="Encoding \"$tmp_if\" to \"$tmp_of\""
			
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
		
		# Command just needs to be generated
		$useSubs && cmd_run_specific+=" $cmd_subtitle_all $subtitle_maps" 
		cmd="$cmd_all $cmd_input_all $ADDERS $web $extra $cmd_video_all $buffer $txt_mjpg $cmd_audio_all $cmd_run_specific $cmd_audio_maps $TIMEFRAME $METADATA $adders $cmd_output_all"
		doLog "Command-Simple: $cmd"
		msg+=" Converting"

	# Verify file does not already exists
	# This is not required, its just a failsafe catcher to blame the enduser when he confirms to overwrite an exisiting file
		skip=false
		if [ -f "$OF" ]
		then 	tui-echo "ATTENTION: Failsafe catcher!"
			if tui-yesno "Outputfile ($OF) exists, overwrite it?"
			then 	rm -f "$OF"
			else	skip=true
			fi
		fi
	# Skip if it was not removed
		if [ false = "$skip" ] 
		then
		#
		#	Execute the command
		#
			printf "$cmd" > "$TMP"
			if $ADVANCED
			then	tui-echo "Please save the file before you continue"
				tui-edit "$TMP"
				tui-press "Press [ENTER] when read to encode..."
			fi
			
			$showFFMPEG && tui-echo "Executing:" "$(cat $TMP)"
			doExecute "$TMP" "$OF" "$STR1" "$STR2"
			RET=$?
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
				tui-printf "$msg" "$WORK"
				#tui-echo "aid $aid .$audio_ids"
				aid="$(vhs -i \"$OF\" |$GREP Audio|while read hash line stream string drop;do echo ${string:3:-1};done)"
				#aid=1
				doLog "Audio : Set default audio stream $aid"
				case $container in
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
			if [ ! -z "$2" ] 
			then	doLog "--------------------------------"
				msg="Timeout - $sleep_between between encodings..."
				[ ! -z "$sleep_between" ] && \
					doLog "Script : $msg" && \
					tui-echo && tui-wait $sleep_between "$msg" #&& tui-echo
				# Show empty log entry line as optical divider
				doLog ""
			fi
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
	if [ -z "$1" ]
	then 	printf "$help_text"
		exit $RET_HELP
	fi
exit 0
