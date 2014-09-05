#!/bin/bash
checkfiles=( 	"/mnt/windows/Users/Arjuna/Videos/Gantz 2011 BRRip 470MB [Audio-JAP,ENG] x264 AAC - VYTO/Gantz (jap-eng,2011,BRRip.mkv" \
		"/mnt/windows/Users/Arjuna/Videos/Stargate SG1/SG 1 - S09/03.Origin.mkv"
	)
# ------------------------------------------------------------------------
#
# Copyright (c) 2014 by Simon Arjuna Erat (sea)  <erat.simon@gmail.com>
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
#-----------------------------------------------
#
#
#
#	File:		vhs
#	Author: 	Simon Arjuna Erat (sea)
#	Contact:	erat.simon@gmail.com
#	License:	GNU Lesser General Public License (LGPL3)
#	Created:	2014.05.18
#	Changed:	2014.08.06
	script_version=0.7
	TITLE="Video Handler Script"
#	Description:	All in one movie handler, wrapper for ffmpeg
#			Simplyfied commands for easy use
#
#			It should encode a DVD with your prefered language only - when called from terminal,
#			but let you choose which languages, when your prefered langauge is not found.
#
#			Easy mass re-code files as it takes each file's name as replaces its container extension for the output.
#			If that new name exists, it numbers it incremently, so you cannot delete your input file by accident (from the script
#
#	Resources:	http://ffmpeg.org/index.html
#			https://wiki.archlinux.org/index.php/FFmpeg
#			https://support.google.com/youtube/answer/1722171?hl=en&ref_topic=2888648
#
#
# This script requires TUI - Text User Interface
# See:		https://github.com/sri-arjuna/tui
#
#	Check if TUI is installed...
#
	S=/etc/profile.d/tui.sh
	if [[ ! -f $S ]]
	then 	[[ ! 0 -eq $UID ]] && \
			printf "\n#\n#\tPlease restart the script as root to install TUI (Text User Interface).\n#\n#\n" && \
			exit 1
		if ! git clone https://github.com/sri-arjuna/tui.git /tmp/tui.inst
		then 	mkdir -p /tmp/tui.inst ; cd /tmp/tui.inst/
			curl --progress-bar -L https://github.com/sri-arjuna/tui/archive/master.zip -o master.zip
			unzip master.zip && rm -f master.zip
			mv tui-master/* . ; rmdir tui-master
		fi
    		sh /tmp/tui.inst/install.sh || \
    			(printf "\n#\n#\tPlease report this issue of TUI installation fail.\n#\n#\n";exit 1)
    	fi
    	source $S ; S=""
#
#	Script Environment
#
	ME="${0##*/}"				# Basename of $0
	ME_DIR="${0/\/$ME/}"			# Cut off filename from $0
	ME="${ME/.sh/}"				# Cut off .sh extension
	CONFIG_DIR="$HOME/.config/$ME"		# Base of the script its configuration
	CONFIG="$CONFIG_DIR/$ME.conf"		# Configuration file
	CONTAINER="$CONFIG_DIR/containers"	# Base of the container definition files
	LOG="$CONFIG_DIR/$ME.log" 		# If a daily log file is prefered, simply insert: -$(date +'%T')
	LIST_FILE="$CONFIG_DIR/$ME.list"	# Contains lists of codecs, formats
	TMP_DIR="$TUI_TEMP_DIR"			# Base of possible temp files
	TMP="$TMP_DIR/$ME.tmp"			# Direct tempfile access
	
	# Get basic container, set to open standard if none exist
	[[ -f "$CONFIG" ]] && container=$(tui-value-get "$CONFIG" "container") || container=webm
	# Create temp directory if not existing
	[[ -d "$TMP_DIR" ]] || mkdir -p "$TMP_DIR"
	# Create configuration directory if not existing
	[[ -d "$CONFIG_DIR" ]] || mkdir -p "$CONFIG_DIR"
#
#	Variables
#
	REQUIRES="ffmpeg v4l-utils mkvtoolnix" # mencoder"		# This is absolutly required 
#
#	Defaults for proper option catching, do not change
#
	# BOOL's
	showFFMPEG=false		# -v 	Debuging help, show the real encoder output
	beVerbose=false			# -V 	Show additional steps done
	doCopy=false			# -C
	override_audio_bit=false	# -b a	/ -B
	override_audio_codec=false	# -c a	/ -C
	override_video_bit=false	# -b v	/ -B
	override_video_codec=false	# -c v	/ -C
	override_container=false	# -e ext 
	# Values - 
	MODE=video			# -D, -W, -S, -e AUDIO_EXT	audio, dvd, webcam, screen
	cmd_audio_all=""
	cmd_audio_maps=""
	cmd_audio_rate=""
	cmd_input_all=""
	cmd_output_all=""
	cmd_subtitle_all=""
	cmd_video_all=""
	langs=""			# -l LNG 	will be added here
	PASS=1				# -p 		toggle multipass video encoding	
	
	extra=""
	verbose=" -v quiet"	# -hide-banner
	#accel="-hwaccel vdpau"
	web=""
	#pass=""
	mode="file"
	
	
	
	
	
	
	MODE="files"		# dvd screen webcam
	# Set vars as command-string parts, which will remain empty for 'default-clean' use
	BITS=""
	CODEC_ALL=""
	CODEC_AUDIO=""
	CODEC_VIDEO=""
	
	
	
	
#
#	Help text
#
	help_text="
$ME ($script_version) - ${TITLE^}
Usage: 		$ME [options] [arguments]

Examples:	$ME -b a128 -b v512 filename	| Encode file with audio bitrate of 128k and video bitrate of 512k
		$ME -Cvwe webm *ogg		| Re-encodes all files ending with ogg as webm, 
						+ optimized to be played in a browser/stream, while beeing verbose
		$ME filename			| Encodes a file
		$ME -DC filename		| Re-encode a DVD
		$ME -s				| Captures screen
		$ME -W				| Captures webcam

Where options are: (only the first letter)
	-h(elp) 			This screen
	-b(itrate)	[av]NUM		Set Bitrate to NUM kilobytes, use either 'a' or 'v' to define audio or video bitrate
	-B(itrates)			Use bitrates (av) from configuration
	-C(opy)				Just copy streams, fake convert
	-c(odec)	[av]NAME	Set codec to NAME for audio or video
	-D(VD)				Encode from DVD
	-e(xtension)	CONTAINER	Use this container (ARG) instead of \"$container\"
	-f(aststart)			Moves the videos info to start of file (web compatibility)
	-i(nfo)		VIDEO		Shows a tui-title per video and tui-echo its streams
	-l(anguage)	LNG		Only encode LNG audio stream (3 letter abrevihation, eg: eng,fre,ger,spa)
	-L(OG)				Show the log file
(BETA)	-p(ass)				Encodes the video with 2-Pass
	-s(creen)			Records the fullscreen desktop
	-S(etup)			Shows the setup dialog
	-t(imeout)	SECONDS		Set the timeout between videos to SECONDS
	-v(erbose)			Displays encode data from ffmpeg
	-V(erbose)			Show more information how the things made up.
(BETA)	-W(ebcam)			Encodes from webcam


Info:
------------------------------------------------------
After installing codecs, drivers or plug in of webcam,
it is highy recomended to update the list file.
You can do so by entering the Setup dialog: $ME -S
and select 'UpdateLists'.

Recording from webcam does a terminal lockup on my system.
However, forum users confirmed that the default example
command works, thus, i'm currently let you use that one,
rather than the command generated by the script.


Files:		
------------------------------------------------------
Script:		$0
Config:		$CONFIG
Containers:	$CONTAINER
Lists:		$LIST_FILE
Log:		$LOG

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
		ffmpeg  -psnr -i "$1" 2> "$TMP" 1> "$TMP"
		grep -i stream "$TMP"
	}
	countVideo() { # [VIDEO]
	# Returns the number of video streams found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[[ -z $1 ]] && \
			cmd="grep -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		eval $cmd|grep -i video|wc -l
	}
	countAudio() { # [VIDEO]
	# Returns the number of audio streams found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[[ -z $1 ]] && \
			cmd="grep -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		eval $cmd|grep -i audio|wc -l
	}
	countSubtitle() { # [VIDEO]
	# Returns the number of subtitles found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[[ -z $1 ]] && \
			cmd="grep -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		eval $cmd|grep -i subtitle|wc -l
	}
	hasLang() { # LANG [VIDEO] 
	# Returns true if LANG was found in optinal VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[[ -z $2 ]] && \
			cmd="grep -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|grep -i audio|grep -q -i "$1"
		return $?
	}
	hasLangDTS() { # LANG [VIDEO] 
	# Returns true if LANG was found in optinal VIDEO and declares itself as DTS
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[[ -z $2 ]] && \
			cmd="grep -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|grep -i audio|grep -i $1|grep -q DTS
		return $?
	}
	hasSubtitle() { # LANG [VIDEO] 
	# Returns true if LANG was found in optinal VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[[ -z $2 ]] && \
			cmd="grep -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|grep -i subtitle|grep -q -i $1
		return $?
	}
	listIDs() { # [VIDEO]
	# Prints a basic table of stream ID CONTENT (and if found) LANG
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[[ -z $1 ]] && \
			cmd="cat \"$TMP.info\"" || \
			cmd="StreamInfo \"$1\""
		eval $cmd |	while read strs maps kinds codecs other;do
					kind="${kinds:0:-1}"
					#codec="${codecs/,/}"
					lang="${maps:5:3}"
					id="${maps:3:1}"
					printf "$id \t $lang \t $kind\n"
				done
	}
	listAudioIDs() { # [VIDEO]
	# Returns a list of audio stream ids
	#
		listIDs $1 |grep -i audio|awk '{print $1}'
	}
	listSubtitleIDs() { # [VIDEO]
	# Returns a list of subtitle stream ids
	#
		listIDs $1 |grep -i subtitle|awk '{print $1}'
	}
	
	genFilename() { # Filename_with_ext container
	# Parses for file extension and compares with new container
	# If identical, add a number to avoid overwriting sourcefile.
		video="$1"
		container="$2"
		for ext in $(printf "$video"|sed s,'\.',' ',g);do printf "" > /dev/zero;done
		if [[ $ext = $container ]]
		then 	# new file name would be the same
			name="${video/$ext/}"
			N=0
			while [[ -f "$name$N.$container" ]] ; do ((N++));done
			outputfile="$name$N.$container"
			doLog "Output: Has same extension, incrementing to \"$outputfile\""
		else 	outputfile="${video/$ext/}$container"
			doLog "Output: \"$outputfile\""
		fi
		printf "$outputfile"
	}
	
	
	# set -x
	# DEBUG =
	false && \
		clear && \
		for F in "${checkfiles[@]}";do
			tui-title "$F"
			StreamInfo "$F" > $TMP.info
			echo "listIDs ::
$(listIDs)

	countVideo :: $(countVideo)		
	countAudio :: $(countAudio)
	countSubtitle :: $(countSubtitle)


	hasLang ger :: $(hasLang ger;echo $?)
	hasLangDTS ger :: $(hasLangDTS ger;echo $?)
	hasSubtitle ger :: $(hasSubtitle ger;echo $?)
"
		done && \
		exit
# OLD FUNC
	listLang() { #
	# parses the TMP file and prints each found language on a line
	#
		for var in $(cat "$TMP" | awk '{print $2}')
		do	new="${var:5:(-2)}"
			doLog "Audio : ListLang ($var) -> $new"
			printf "$new\n"
		done
	}
	GetRes() { # [-l] ID
	# Returns 2 digits (W*H) according to ID
	# use -l to get a list of valid ID's
		LIST=( screen clip dvd 720 hd)
		[[ "-l" = "$1" ]] && \
			printf "${LIST[*]}" && \
			return 0
		[[ -z $1 ]] && \
			printf "Must provide a valid ID!" && \
			exit 1
		case "$1" in
		"${LIST[0]}")
			xrandr|grep \*|sed s,x,' ',g|awk '{print $1" "$2}'|sed s,x,\ ,g		;;
		"${LIST[1]}")	printf "640 480" ;;
		"${LIST[2]}")	printf "720 576" ;;
		"${LIST[3]}")	printf "1280 720" ;;
		"${LIST[4]}")	printf "1920 1080" ;;
		esac
		return 0
	}
	GetBitrate() { # [-l] ID
	# Returns suggested audio then video bitrate according to ID
	# use -l to get a list of valid ID's
		LIST=( screen clip dvd 720 hd)
		[[ "-l" = "$1" ]] && \
			printf "${LIST[*]}" && \
			return 0
		[[ -z $1 ]] && \
			printf "Must provide a valid ID!" && \
			exit 1
		case "$1" in
		"${LIST[0]}")	printf "128 512"	;;
		"${LIST[1]}")	printf "192 384" ;;
		"${LIST[2]}")	printf "192 512" ;;
		"${LIST[3]}")	printf "256 768" ;;
		"${LIST[4]}")	printf "256 1280" ;;
		esac
		return 0
	}
	genFilename() { # Filename_with_ext container
	# Parses for file extension and compares with new container
	# If identical, add a number to avoid overwriting sourcefile.
		video="$1"
		container="$2"
		for ext in $(printf "$video"|sed s,'\.',' ',g);do printf "" > /dev/zero;done
		if [[ $ext = $container ]]
		then 	# new file name would be the same
			name="${video/$ext/}"
			N=0
			while [[ -f "$name$N.$container" ]] ; do ((N++));done
			outputfile="$name$N.$container"
			doLog "Output: Has same extension, incrementing to \"$outputfile\""
		else 	outputfile="${video/$ext/}$container"
			doLog "Output: \"$outputfile\""
		fi
		printf "$outputfile"
	}
	countAudioStreams() { # VIDEO
	# Returns the numer of audiostreams
	#
		touch "$TMP"
		ffmpeg -psnr -i "$1"  2>&1 | grep Stream |grep Audio > "$TMP"
		cat "$TMP"|wc -l
	}
	hasMultipleStreams() { # VIDEO
	# If more than one audio stream is found, returns success (0)
	#
		[[ $(countAudioStreams "$1") -gt 1 ]] && \
			return 0 || return 1
		
		# old -- backup
		touch "$TMP"
		ffmpeg -psnr -i "$1"  2>&1 | grep Stream |grep Audio > "$TMP"
		lines=$(cat "$TMP"|wc -l)
		[[ $lines -gt 1 ]] && \
			doLog "Audio: Multiple streams found" && \
			return 0			
		return 1
	}
	hasLang() { # video lang
	# checks if video has favorite language audio stream
	#
		touch "$TMP"
		ffmpeg -psnr -i "$1"  2>&1 | grep Stream |grep Audio > "$TMP"
		num=$(grep "($2)" "$TMP"|wc -l)
		if [[ ! -z $num ]] && [[ $num -gt 0 ]]
		then	doLog "Audio: Found $num entry for \"$lang\""
			return 0			
		else	doLog "Audio: ${lang^} not found in \"${1##*/}\""
			return 1
		fi
	}
	countLang() { # video lang
	# Counts entries for supplied LANG in VIDEO
	#
		touch "$TMP"
		ffmpeg -psnr -i "$1"  2>&1 | grep Stream |grep Audio | grep -i "${2}" > "$TMP"
		cat "$TMP"|wc -l
	}
	getSingleAudio() { # video lang
	# Returns the map ID of the first found audio stream.
	# If there are multiple streams, but just one with favorite lang, supply this optional
		touch "$TMP"
		ffmpeg -psnr -i "$1"  2>&1 | grep Stream |grep Audio > "$TMP"
		[[ ! -z $2 ]] && \
		 	tmp_str=$(grep "$2" "$TMP") && \
		 	printf "$tmp_str" > "$TMP"
		 #tmp_str=$(grep Audio "$TMP"|awk '{print $2}')
		 tmp_str=$(grep -n Audio "$TMP"|grep ^1|awk '{print $3}')
		 printf "$tmp_str"|grep -q "(" && \
		 	num=6 || num=1
		 printf "${tmp_str:3:-$num}"
	}
	hasDTS() { # video
	# Checks if filename-video has audio streams with dts
	#
		touch "$TMP.dts"
		grep -i dts "$TMP" > "$TMP.dts"
		lines=$(cat "$TMP.dts"|wc -l)
		[[ $lines -gt 1 ]] && \
			doLog "Audio: DTS encoding found" && \
			return 0			
		return 1
	}
	WriteContainers() { # 
	# Writes several container files and their default / suggested values
	#
		tui-title "Write Containers"
		header="# $ME ($script_version) - Container definition"
		[[ -d "$CONTAINER" ]] || mkdir -p "$CONTAINER"
		cd "$CONTAINER"
		for entry in avi mp4 mkv ogg webm aac ac3 dts mp3 vorbis clip copy dvd wav;do
			case $entry in
		# Containers
			avi)	# TODO, this is just assumed / memory
				ca=mpeg2video 	# Codec Audio
				cv=mp3		# Codec Video
				ce=false	# Codec extra
				fe=true		# File extra (audio codec dependant)
				ba=128		# Bitrate Audio
				bv=384		# Bitrate Video
				ext=$entry	# Extension used for the video file
				;;
			mp4)	ca=aac ;	cv=libx264
				ce=true ;	fe=true	
				ext=$entry	;;
			mkv)	ca=ac3	;	cv=libx264
				ce=false ;	fe=false
				ext=$entry	;;
			ogg)	ca=libvorbis ;	cv=libtheora
				ce=true	;	fe=true	
				ext=$entry	;;
			webm)	ca=libvorbis ;	cv=libvpx	
				ce=true	;	fe=true	
				ext=$entry	;;
		# Audio Codecs
			aac)	ca=aac ;	cv=
				ce=false ;	fe=false
				ext=$entry	;;
			ac3)	ca=ac3 ;	cv=
				ce=false ;	fe=false
				ext=$entry 	;;
			dts)	ca=dts ;	cv=
				ce=false ;	fe=false
				ext=$entry	;;
			mp3)	ca=mp3 ;	cv=
				ce=false ;	fe=false
				ext=$entry	;;
			vorbis)	ca=libvorbis ; 	cv=
				ce=false ; 	fe=false
				ext=$entry	;;	
		# Experimental
			copy)	ca=copy ;	cv=copy
				ce=true	;	fe=true
				ext=		;;
			clip)	ca=aac ;	cv=libx264
				ce=true	;	fe=true
				ext=mp4		;;
			dvd)	ca=mpeg2video ;	cv=mp3	
				ce= ;		fe=	
				ext=mpeg	;;
			webcam)	# TODO
				ca=mpeg2video ;	cv=mp3	
				ce= ;		fe=	
				ext=mpeg	;;
			# blob)	ca=	;	cv=
			#	ce=	;	fe=
			#	ba=	;	bv=
			#	ext=$entry	;;
			esac
			touch $entry
			tui-printf "Write container info ($entry)" "$WORK"
#container=$entry
			printf "$header
ext=$ext
audio_codec=$ca
video_codec=$cv
codec_extra=$ce
file_extra=$fe" > $entry
			[[ 0 -eq $? ]] && \
				tui-printf "Wrote container info ($entry)" "$DONE" && \
					doLog "Container: Created '$entry' definitions" || \
					( tui-printf "Wrote container info ($entry)" "$DONE" ; doLog "Container: Created '$entry' definitions")
		done
	}
	UpdateLists() { #
	# Retrieve values for later use
	# Run again after installing new codecs or drivers
		[[ -f "$LIST_FILE" ]] || touch "$LIST_FILE"
		tui-title "Generating a list file"
		tui-progress "Retrieve raw data..."
		ffmpeg $verbose -codecs | grep \ DE > "$TUI_TEMP_FILE"
		printf "" > "$LIST_FILE"
		
		for TASK in DEA DES DEV;do
			case $TASK in
			DEA)	txt_prog="Audio-Codecs"	; 	var=codecs_audio 	;;
			DES)	txt_prog="Subtitle-Codecs"; 	var=codecs_subtitle	;;
			DEV)	txt_prog="Video-Codecs"	; 	var=codecs_video	;;
			esac
			tui-progress "Saving $txt_prog"
			raw=$(grep $TASK "$TUI_TEMP_FILE"|awk '{print $2}'|sed s,"\n"," ",g)
			clean=""
			for a in $raw;do clean+=" $a";done
			printf "$var=\"$clean\"\n" >> "$LIST_FILE"
			doLog "Lists : Updated $txt_prog"
		done
		
		tui-progress "Saving Codecs-Format"
		ffmpeg $verbose -formats > "$TUI_TEMP_FILE"
		formats_raw=$(grep DE "$TUI_TEMP_FILE"|awk '{print $2}'|sed s,"\n"," ",g)
		formats=""
		for f in $formats_raw;do formats+=" $f";done
		printf "codecs_formats=\"$formats\"\n" >> "$LIST_FILE"
		doLog "Lists : Updated Codecs-Format"

		
		if [[ -e /dev/video0 ]]
		then 	#v4l2-ctl cant handle video1 .. ??
			tui-progress "Saving WebCam-Formats"
			webcam_formats=""
			[[ -z $webcam_fps ]] && webcam_fps=5
			wf="$(v4l2-ctl --list-formats-ext|grep $webcam_fps -B4 |grep Siz|awk '{print $3}'|sort)"
			for w in $wf;do webcam_formats+=" $w";done
			printf "webcam_formats=\"$webcam_formats\"\n" >> "$LIST_FILE"
			doLog "Lists : Updated WebCam-Format"

			tui-progress "Saving WebCam-frames"
			webcam_frames=""
			wf="$( v4l2-ctl --list-formats-ext|grep -A6 Siz|awk '{print $4}')"
			C=0
			for w in $wf;do webcam_frames+=" ${w/(/}";((C++));[[ $C -ge 6 ]] && break;done
			printf "webcam_frames=\"$webcam_frames\"\n"|sed s,"\.000","",g >> "$LIST_FILE"
			doLog "Lists : Updated WebCam-Frames"
		elif [[ -e /dev/video1 ]]
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
		if [[ ! -f "$CONFIG" ]] 
		then 	touch "$CONFIG"
			cat > "$CONFIG" << EOF
# $CONFIG, generated by $ME ($script_version)

# Available (supportet) containers:
# -> (avi) mkv mp4 ogg webm
container=mkv

# Audio bitrate suggested range (values examples): 72 96 128 144 192 256
audio_bit=192

# Video bitrate suggested range (value examples): 128 256 512 768 1024 1280 1536 1920 2048 2560 4096 5120
video_bit=768

# See ffmpeg output (vhs -i FILE // ffmpeg -psnr -i FILE) for your language abrevihation
# if 'lang' is not found it will take 'lang_alt' if available
lang_force_both=false
lang=ger
lang_alt=eng

# If DTS is found, to how many channels shall it 'downgrade'?
# Range::  1) Mono, 2) Stereo, [3-5]) unkown, 6) 5.1 Surround
channel_downgrade=true
channels=2

# Suggested audio rates (hz) are around 44000 to 96000
audio_rate_force=false
audio_rate=48000

# How long to wait by default between encodings if multiple files are queued?
sleep_between=45

# This is a default value that should work on most webcams
# Please use the script's Setup to change the values
webcam_res=640x480
webcam_fps=25
EOF
			tui-status $? "Wrote $CONFIG" 
			cat $CONFIG
		fi
	#
	#	Setup menu
	#
		tui-title "Setup : $TITLE"
		
		# Get a list of ALL variables within the $CONFIG file
		VARS=$(tui-value-get -l "$CONFIG"|grep -v req)
		
		# Make a tempfile without empty or commented lines
		# And display both, variable and value to the user
		oIFS="$IFS" ; IFS="="
		touch $TMP.cfg
		printf "$(grep -v "#" $CONFIG)" > $TMP.cfg
		while read var val;do
			[[ ! "#" = "${var:0:1}" ]] && \
				# [[ ! "" = "$(printf \"${var}\")" ]] && \
				[[ ! -z $var ]] && \
				tui-echo "$var" "$val"
		done < $TMP.cfg
		IFS="$oIFS"
		
		tui-echo
		tui-echo "Which variable to change?"
		select var in Back UpdateLists ReWriteContainers $VARS;do
			case $var in
			Back)		break	;;
			UpdateLists)	$var 	;;
			ReWriteContainers) WriteContainers ;;							
			*)	val=$(tui-value-get "$CONFIG" "$var")
				tui-echo "${var^} is set to:" "$val"
				if tui-yesno "Change the value of $var?"
				then	case $var in
					container)	tui-echo "Please select a new one:"
							select newval in $(cd "$(dirname $CONFIG)/containers";ls);do break;done
							;;
					channnels)	tui-echo "Please select a new amount:"
							select newval in $(seq 1 1 6);do break;done
							;;
					webcam_res)	tui-echo "Please select the new resolution:"
							select newval in $webcam_formats;do break;done
							;;
					webcam_fps)	tui-echo "Please select the new framerate:"
							select newval in $webcam_frames;do break;done
							;;
					*)		newval=$(tui-read "Please type new value:")
							;;
					esac
					msg="Changed \"$var\" from \"$val\" to \"$newval\""
					# Save the new value to variable in config 
					tui-value-set "$CONFIG" "$var" "$newval"
					tui-status $? "$msg" && \
						doLog "Setup: $msg" || \
						doLog "Setup: Failed to c$(printf ${msg:1}|sed s,ged,ge,g)"
				fi
			;;
			esac
			tui-echo "Press [ENTER] to see the menu:" "$INFO"
		done
	}
#
#	Environment checks
#
	tui-log -e "$LOG" "\r---- New call $$ ----"
	# This is optimized for a one-time setup
	if [[ ! -f "$CONFIG" ]]
	then 	mkdir -p "$(dirname $CONFIG)"
		tui-header "$ME ($script_version)" "$(date +'%F %T')"
		tui-echo "Entering first time setup." "$SKIP"
		doLog "Setup : Writing configuration and list files"
		WriteContainers
		UpdateLists
		#
		#	Install missing packages
		#
			tui-progress -ri movies-req -m $(printf ${REQUIRES}|wc|awk '{print $2}') " "
			if [[ false = "$req_inst" ]]
			then 	tui-title "Verify all required packages are installed"
				doLog "Req : Installing missing packages: $REQUIRED"
				tui-install -vl "$LOG" $REQUIRED && \
					tui-value-set "$CONFIG" req_inst "true"
				tui-status $? "Installed: $REQUIRED"
				[[ 0 -eq $? ]] && \
					ret_info="succeeded" && \
					tui-value-set "$CONFIG" "req_inst" "true"|| \
					ret_info="failed"
				doLog "Req: Installation of $REQUIRED $ret_info"
			else 	[[ ! true = "$req_inst" ]] && \
					printf "req_inst=true\n" >> "$CONFIG" && \
					doLog "Req : All required packages are already installed"
			fi
		# Load default lists with supportet codec formats
		source "$LIST_FILE"
		MenuSetup
	#else	doLog "Setup : Load $USER's configuration"
		#source "$CONFIG" || \
		#	( doLog "Failed to load: $CONFIG" ; tui-status 1 "Failed to load: $CONFIG" ; MenuSetup )
	fi
#
#	Catching Arguments
#

	
	while getopts "aBb:c:CDe:fhiLl:pRr:Sst:Q:vVW" opt
	do 	case $opt in
		b)	case "${OPTARG:0:1}" in
			a)	override_audio_bit=true
				doLog "Options: Override audio bitrate ($BIT_AUDIO) with ${OPTARG:1}"
				BIT_AUDIO="${OPTARG:1}"
				;;
			v)	override_video_bit=true
				doLog "Options: Override video bitrate ($BIT_VIDEO) with ${OPTARG:1}"
				BIT_VIDEO="${OPTARG:1}"
				;;
			*)	tui-status 1 "You did not define whether its audio or video: -$opt [a|v]$OPTARG"
				exit 1
				;;
			esac
			;;
		B)	override_audio_bit=true
			override_video_bit=true
			BIT_AUDIO=$(tui-value-get "$CONFIG" "BIT_AUDIO")
			BIT_VIDEO=$(tui-value-get "$CONFIG" "BIT_VIDEO")
			doLog "Options: Using bitrates from $CONFIG (A:$BIT_AUDIO V:$BIT_VIDEO )"
			;;
		c)	case "${OPTARG:0:1}" in
			a)	override_audio_codec=true
				doLog "Options: Override audio bitrate ($audio_codec) with ${OPTARG:1}"
				audio_codec="${OPTARG:1}"
				;;
			v)	override_video_codec=true
				doLog "Options: Override video bitrate ($video_codec) with ${OPTARG:1}"
				video_codec="${OPTARG:1}"
				;;
			*)	tui-status 1 "You did not define whether its audio or video: -$opt [av]$OPTARG"
				exit 1
				;;
			esac
			;;
		C)	doCopy=true
			override_video_codec=true
			override_audio_codec=true
			video_codec=copy
			audio_codec=copy
			doLog "Options: Just copy streams, no encoding"
			;;
		D)	mode=dvd
			doLog "Mode: DVD"
			# RE-Place code !!
			tempdata=( $(ls /run/media/$USER) )
			[[ "${#tempdata[@]}" -ge 2 ]] && \
				tui-echo "Please select which entry is the DVD:" && \
				select name in "${tempdata[@]}";do break;done || \
				name="$(printf $tempdata)"
			SCREEN_OF=$(genFilename "DVD-$tempdata.$container" $container )
			SCREENER=DVD
			override_container=true
			;;
		e)	override_container=true
			doLog "Options: Overwrite \"$container\" with \"$OPTARG\""
			container="$OPTARG"
			;;
		f)	doLog "Options: Optimize for web usage."
			web="-movflags faststart"	;;
		h)	doLog "Show Help"
			printf "$help_text"
			exit $RET_HELP
			;;
		i)	# Creates $TMP.info
			shift $(($OPTIND - 1))
			for A in "$@";do
			[[ -f "$A" ]] && \
				tui-printf "Retrieving data from ${A##*/}" "$WORK" && \
				StreamInfo "$A" > "$TMP.info" && \
				tui-title "Stream info of: ${A##*/}" && \
				while read line;do tui-echo "$line";done<"$TMP.info"
			done
			exit $RET_DONE
			;;
		l)	lang=$OPTARG
			langs+=" $lang"
			doLog "Options: Using $lang for audio stream"
			;;
		L)	doLog "Show Logfile"
			sleep 0.1
			less "$LOG"
			exit $RET_DONE
			;;
		p)	PASS="2"
			doLog "Options: Encode as $PASS-pass"
			;;
		v)	doLog "Options: Be verbose!"
			verbose="-v info"
			beVerbose=true		;;
		W)	mode=webcam
			doLog "Mode: WebCam"
			# RE-Place code !!
			SCREEN_OF=$(genFilename "webcam-out.$container" $container )
			SCREENER=webcam
			override_container=true
			;;
		R)	audio_rate=$(tui-value-get "$CONFIG" "audio_rate")
			doLog "Options : Force audio_rate to $audio_rate"
			;;
		r)	audio_rate="$OPTARG"
			doLog "Options: Force audio_rate to $audio_rate"
			;;
		s)	mode=screen
			doLog "Mode: Screen"
			# RE-Place code !!
			SCREEN_OF=$(genFilename "screen-out.$container" $container )
			SCREENER=screen
			override_container=true
			;;
		S)	tui-header "$ME ($script_version)" "$(date +'%F %T')"
			MenuSetup
			exit 0	;;
		t)	doLog "Options: Changed delay between jobs from \"$sleep_between\" to \"$OPTARG\""
			sleep_between="$OPTARG"
			;;
		*)	doLog "Invalid argument: $opt : $OPTARG"
		esac
	done
	shift $(($OPTIND - 1))
	#ARGS=(${*})			# Remaining arguments
	#ARGS_COUNT=${#ARGS[@]}		# Amount of remaining
#
#	Display & Action
#
	# Ok, we passed help screen and log view, lets present something
	tui-header "$ME ($script_version)" "$TITLE" "$(date +'%F %T')"
	#tui-title "$TITLE"
	
	
#
#	Check the mode
#
	[[ -z $mode ]] && mode="file"
	doLog "Mode: $mode"
	[[ file = "$mode" ]] && \
		[[ -z "$1" ]] && \
		show_menu=true
#
#	Get 'best' codecs for $container, unless override is true
#	
	[[ $override_container = true ]] && \
		doLog "Options: Container set to: $container" || \
		doLog "Options: Container used: $container (default)"
		
	src="$CONTAINER/$container"
	#if [[ true = $doCopy ]]
	#theSn 	echo #doLog "Options: Just copy streams..."
	#el
	if [[ true = $doQuality ]]
	then 	source "$src"
	else	bolCodecExtra=$(tui-value-get "$src" "codec_extra")
		bolFileExtra=$(tui-value-get "$src" "file_extra")
		
		[[ true = $override_video_codec ]] || video_codec+=$(tui-value-get "$src" "video_codec")
		[[ true = $override_audio_codec ]] || audio_codec+=$(tui-value-get "$src" "audio_codec")
		[[ true = $override_video_bit ]] || video_codec+=$(tui-value-get "$src" "BIT_VIDEO")
		[[ true = $override_audio_bit ]] || audio_codec+=$(tui-value-get "$src" "BIT_AUDIO")
		
		
		[[ true = $bolFileExtra ]] && ext=$(tui-value-get "$src" 'ext') && F="-f $ext"
		[[ true = $bolCodecExtra ]] && extra+=" -strict -2"
		
		# Special treatment
		case "$container" in
		"webm")	doLog "$container: Calculating hypterthreads to be used"
			threads="$(grep proc /proc/cpuinfo|wc -l)" && threads=$[ $threads - 1 ] 
			doLog "$container: Found $threads hypterthreads, leaving 1 for system"
			#video_codec+=" -minrate $[ 8 * ${BIT_VIDEO} ] -maxrate $[ 8 * ${BIT_VIDEO} ] -bufsize $[ 8 * ${BIT_VIDEO} ]"
			[[ ! "" = "$(printf $video_codec)" ]] && video_codec+=" -threads $threads  -deadline realtime"
			[[ ! "" = "$(printf $audio_codec)" ]] && audio_codec+=" -cpu-used $threads"
			;;
		esac
		#video_codec+=" -minrate ${BIT_VIDEO} -maxrate ${BIT_VIDEO} -bufsize $[ 2 * ${BIT_VIDEO} ]"
	fi
	[[ -z $lang ]] && lang=$(tui-value-get "$CONFIG" "lang")
#
#	Show menu or go for the loop of files
#
	aid=0
	#
	#	Get bitrates
	#
		bits+=" -b:a ${BIT_AUDIO}K"
		bits+=" -b:v ${BIT_VIDEO}K "
	for video in "${@}" $SCREENER;do
	#
	#	per entry defaults
	#
		audio_streams=""
		skip=false	# Init var
	#
	#	New 'file' / only input
	#
		doLog "----- $video -----"
		#tui-title "Input: $video"
		case $mode in
		screen|dvd|web)	OF="$HOME/$SCREEN_OF" ;;
		*)	#
			#	Verify Inputfile exists and outputfile has not the same name
			#	
				#[[ -f "$video" ]] && \
				#	tui-status $? "Inputfile ($video) checked." && \
				#	doLog "Input Found: $video" || \
				#	( tui-status $? "Input ($video) not found!" ; doLog "Input Missing: $video" ; exit 1 )
				# Output File
				OF=$(genFilename "${video}" "$container")
			#
			#	Get audio stream
			#				
				[[ -z $lang ]] && lang=$(tui-value-get "$CONFIG" "lang")
				[[ -z $langs ]] && langs="$lang"
				
				found=0
				langs_todo=""
				
				#tui-title "Available audio streams"
				aStreams=$(countAudioStreams "$video")
				# Show general info on audio streams
				#while read line;do tui-echo "$line";done<"$TMP"
				vhs -i "$video"
				tui-echo
			case $PASS in
			1)	##	countLang $video $g
				#	exit
					#hasLang "$video" "$lang" && \
					#	getSingleAudio "$video" $lang 
					for id in $(seq 1 1 $(getSingleAudio "$video" $lang));do
						audio_maps=" -map 0:$id"
						msg="Added '$lang' from Audio-stream: '$id'"
						tui-status 0 "$msg"
						#doLog "$msg"
					done
					[[ $(countLang "$video" "$lang") -ge 1 ]] && \
						tui-echo "$msg" && \
						doLog "Audio: $msg"
					# || $(countAudioStreams "$video") -gt 1
					[[ "" = "$(printf '$audio_maps')" ]] && \
						tui-echo "Select which stream id you want to map (additionaly):" && \
						select id in $(countAudioStreams $video);do
							audio_maps+=" -map 0:$id"
						done
				;;
			2)	# Generate list for each supplied and found langauge
				unset TASKS
				for l in $langs;do
					lStreams=$(countLang "$video" $l)
					
					# Report collected data to log
					msg="Found $lStreams streams of '$lang' langauge of totaly $aStreams streams"
					doLog "$msg"
					
					# Parse for favorite or supplied langs
					getAudioID() { # lang
					# Returns the single ID or
					# lets the user choose an ID
						grep "$1" "$TMP"
					}
					
					case $lStreams in
					0)	printf " " > /dev/zero	;;
					1)	raw=" $(getAudioID $l)"
						TASKS[$found]="$l $raw"
						doLog "Audio: Added $l ($(printf $raw))"
						langs_todo+=" $l"
						((found++))
						;;
					*)	raw=" $(getAudioID $l)"
						select id in Continue $(printf "$raw"|wc -l);do 
							[[ Continue = $id ]] && break
							TASKS[$found]="$l $raw"
							doLog "Audio: Added $l ($(printf $id))"
							((found++))
						done
						;;
					esac	
				done
				tui-status $RET_INFO "$msg"
				[[ $lStreams -eq 1 ]] && tui-echo "Autoselected favorite langauge stream:" "$l"
				
				# If none of provided or favorite langauges were found,
				# select among all streams
				aStreams=$(countAudioStreams "$video")	# required to prepare TMP file
				if [[ $found -eq 0 ]]
				then	lines=$(cat $TMP|wc -l)
					if [[ $lines -eq 1 ]]
					then	this=$(listLang $L)
						[[ -z $this ]] && grep -q default $TMP && this="default"
						#echo $this
						
						if [[ -z $this ]]
						then	# error
							msg2="No languages found!"
							#cat "$TMP"
							doLog "Audio : $msg2"
							tui-status 1 "$msg2"
							exit 1
						else	langs_todo+=" $this"
							msg2="Autoselected the only language available:"
							aid=1
							lang=$this
							tui-echo "$msg2" "$langs_todo"
							doLog "Audio : $msg2 $langs_todo"
						fi
					else	tui-echo "Select which streams you want to add (multiple are possible):"
						select stream in $(listLang) Done;do
						case $stream in
						Done)	break	;;
						*)	langs_todo+=" $stream"
							msg2="Added '$stream'"
							aid=1
							[ -z $aid ] && aid=$(getAudioID $stream)
							tui-echo "$msg"
							doLog "Audio : $msg2"
							;;
						esac
						done
					fi
				fi
				
				tui-echo
				tui-title "Encoding streams"
				tui-echo "Final video name will be:" "\"$OF\""
				done=0
				unset done_files
				
				
				#echo $langs_todo
				
				for L in $langs_todo;do
					tmp_of="$video-$L.$audio_codec"
					if [[ -f "$tmp_of" ]]
					then 	N=0
						while [[ -f "${tmp_of:0:-${#audio_codec}}$N.$audio_codec" ]];do ((N++));done
						tmp_of="${tmp_of:0:-${#audio_codec}}$N.$audio_codec"
					fi
					
					# retrieve the proper id
					# TODO: check if id is greater than 1, user select
					# Should be easy when array "TASKS" is used.
					id="$(getAudioID $L|awk '{print $2}')"
					id="${id:3:1}"
					
					[[ -z $audio_rate ]] || \
						custom_rate="-ar $audio_rate"
					custom_channels=""
					CHANNELS=
					hasDTS "$video" && \
						custom_channels="-ac $(tui-value-get $CONFIG channels)"
					custom_bit=""
					[[ -z $BIT_AUDIO ]] || \
						custom_bit="-b:a ${BIT_AUDIO}K"
					cmd_audio="ffmpeg $verbose \
-i \"${video}\" \
-vn \
-acodec $audio_codec \
$custom_rate \
$custom_channels \
$custom_bit \
-map 0:$id  \"${tmp_of}\""
					doLog "Command-Audio: $cmd_audio"
					printf "$cmd_audio" > "$TMP"
					
				#
				#	Execute the command
				#
					STR2="* Encoded Audiostream ($l:$id) to \"${tmp_of##*/}\""
					STR1="* Encode Audiostream to \"${tmp_of##*/}\""
					# Acutaly encode the audio stream to the file now
					if tui-bgjob -f "$tmp_of" "$TMP" "$STR1" "$STR2"
					#if tui-bgjob -f "$tmp_of" "echo" "$STR1" "$STR2"
					then	done_files[$done]+="$tmp_of"
						doLog "Audio: Saved $tmp_of ($l:$id)"
						((done++))
						RET=0
					else	tui-status 1 "Failed to encode $tmp_of ($l:$id)"
						tui-yesno "Continue anyway?" || exit 0
						RET=1
					fi
					if [[ $RET -eq 0 ]]
					then	#tui-title "TODO"
						tui-echo "* Optimize Audio (optionaly placeholder, todo)" "$TODO"
					fi
				done
				;;
			esac
			;;
		esac

		if [[ -f "$OF" ]]
		then 	if tui-yesno "Outputfile ($OF) exists, overwrite it?"
			then 	rm -f "$OF"
			else	skip=true
			fi
		fi
		
		if [[ false = $skip ]] 
		then 
		#
		#	Generate the command
		#
			msg="Begin:"
			case "$mode" in
			screen)		# Done
					msg+=" Capturing"
					tui-status $RET_INFO "Press 'q' to stop recording..."
					[[ -z $DISPLAY ]] && DISPLAY=":0.0"	# Should not happen, setting to default
					SCREEN_SIZE="$(xrandr|grep \*|awk '{print $1}')"
					screen=" -f x11grab -video_size  $SCREEN_SIZE -i $DISPLAY -f alsa -i default -c:v $video_codec -c:a $audio_codec $bits"
					cmd="ffmpeg $verbose $screen $extra $web $F \"${OF}\""
					;;
			webcam)		# TODO
					# Done ?? dont work for me, but seems to for others
					# Maybe because i have disabled the laptop's internal webcam in BIOS
					msg+=" Capturing"
					tui-status $RET_INFO "Press 'q' to stop recording..."
					srcs=($(ls /dev/video*))
					case ${#srcs[@]} in
					1)	echo jup ;;
					esac
					if [[ "$(printf $srcs)" = "$(printf $srcs|awk '{print $1}')" ]]
					then 	input_video="$srcs"
					else	tui-echo "Please select the video source to use:"
						select input_video in $srcs;do break;done
					fi
					
					tui-status $RET_INFO "Standard is said to be working, sea's should - but might not, please report"
					select webcam_mode in standard sea;do
						case $webcam_mode in
						standard)	# Forum users said this line works
								doLog "Overwrite already generated name, for 'example' code.. "
								OF="$(genFilename output.mpg mpg)"
								cmd="ffmpeg $verbose -f v4l2 -s $webcam_res -i /dev/video0 $F \"${OF}\""
								;;
						sea)		# Non working ??
								OF="$SCREEN_OF"
								cmd="ffmpeg $verbose -f v4l2 -r $webcam_fps -s $webcam_res -i $input_video -f alsa -i default -acodec $audio_codec -vcodec $video_codec $extra $F \"${OF}\""
								;;
						esac
						doLog "WebCam: Using $webcam_mode command"
						doLog "Command-Webcam: $cmd"
						break
					done
					;;
			dvd)		msg+=" Encoding"
					# If tempdir exists, good chances files were already copied
					#  cat f0.VOB f1.VOB f2.VOB | ffmpeg -i - out.mp2
					dvd_tmp="$HOME/.cache/$name"
					dvd_reuse=nothing
					errors=0
					
					dvd_base="/run/media/$USER/$name"
					input_vobs=$(find $dvd_base|grep -i vob)
					vobs=""
					vob_list=""
					total=0
					yadif="-vf yadif"
					for v in $input_vobs;do 
						# only use files that are larger than 700 mb
						if [[ $(ls -l $v|awk '{print $5}') -gt 700000000 ]]
						then 	vobs+=" -i ${v##*/}"
							vob_list+=" ${v##*/}"
							((total++))
						fi
					done
					
					# Cop vobs to local or directly from dvd?
					A="Encode directly from DVD"
					B="Copy largest files to local"
					tui-echo "Please select a method:"
					
					select dvd_copy in "$A" "$B";do
					case "$dvd_copy" in
					"$A")	cd "$dvd_base/VIDEO_TS"
						cmd="ffmpeg $verbose $vobs -acodec $audio_codec -vcodec $video_codec $extra $yadif $F \"${OF}\""
						;;
					"$B")	[[ -d "$dvd_tmp" ]] && \
						 	tui-yesno "$dvd_tmp already exists, reuse it?" && \
							dvd_reuse=true || \
							dvd_reuse=false
						# Create tempdir to copy vob files into
						if [[ false = $dvd_reuse ]]
						then 	mkdir -p "$dvd_tmp"
							doLog "DVD: Copy vobs to \"$dvd_tmp\""
							tui-echo "Copy vob files to \"$dvd_tmp\", this may take a while..." "$WORK"
							C=1
							for vob in $vob_list;do
								lbl="${vob##*/}"
								MSG1="Copy $lbl ($C / $total)"
								MSG2="Copied $lbl ($C / $total)"
								printf "cp -n \"$dvd_base/VIDEO_TS/$vob\" \"$dvd_tmp\"" > "$TMP"
								tui-bgjob -f "$dvd_tmp/$vob" "$TMP" "$MSG1" "$MSG2"
								if [[ 0 -eq $? ]] #"Copied $lbl"
								then 	doLog "DVD: ($C/$total) Successfully copied $lbl"
								else 	doLog "DVD: ($C/$total) Failed copy $lbl"
									((errors++))
								fi
								((C++))
							done
						fi
						tui-echo
						[[ $errors -ge 1 ]] && \
							tui-yesno "There were $errors errors, would you rather try to encode straight from the disc?" && \
							cd "$dvd_base/VIDEO_TS" || \
							cd "$dvd_tmp"
						cmd="ffmpeg $verbose $vobs -target film-dvd  -q:a 0  -q:v 0 $web $extra $bits -vcodec $video_codec -acodec $audio_codec $yadif $F \"${OF}\""
						;;
					esac
					break
					done
					doLog "DVD: Using \"$dvd_copy\" command"
					;;
			file)		# Done
					# TODO
					STR1="" ; STR2=""
					case $PASS in
					1)	# Generate the 1-pass command
						[[ -z $audio_maps ]] && audio_maps="-map 0:1"
						#  
						cmd="ffmpeg $verbose -i \"${video}\" $web $extra $bits -dcodec copy -vcodec $video_codec -map 0:0  -acodec $audio_codec $audio_maps -ar 48000 $audio_streams $F \"${OF}\""
						doLog "Command-Simple: $cmd"
						msg+=" Converting"
						tmp_of="$OF"
						STR2="Encoded \"$video\" to \"${OF##*/}\""
						STR1="Encoding \"$video\" to \"${OF##*/}\""
						tmp_of=""
						;;
					2|3)	# Do the final steps
						# Retrieve video stream, encode it $PASS times and finaly
						# generate the X-pass merge command
						# TODO: Fails with "-pass $PASS \" ?
						tmp_of="$video-video"
						if [[ -f "$tmp_of.$container" ]]
						then 	N=0
							while [[ -f "${tmp_of}.$N.$container" ]];do ((N++));done
							tmp_of="${tmp_of}.$N.$container"
						else	tmp_of+=".$container"
						fi
						
						#echo $tmp_of
						#exit
						
						cmd_video="ffmpeg $verbose \
-i \"${video}\" \
-an \
-pass 1 -y \
-vcodec $video_codec \
-b:v ${BIT_VIDEO}K \
-map 0:0  \"${tmp_of}\""
						doLog "Command-Video-Pass1: $cmd_video"
						printf "$cmd_video" > "$TMP"
					
					#
					#	Execute the command - PASS 1
					#
						STR2="* Encoded Videostream (Pass 1) to \"${tmp_of##*/}\""
						STR1="* Encode Videostream (Pass 1) in $PASS passes to \"${tmp_of##*/}\""
						# Acutaly encode the audio stream to the file now
						if tui-bgjob -f "$tmp_of" "$TMP" "$STR1" "$STR2"
						then	#done_files[$done]+="$tmp_of"
							doLog "Video : Stream (Pass 1) saved to $tmp_of"
							# ((done++))
						else	tui-status 1 "Failed to encode $tmp_of (Pass 1)"
							doLog "Video : Stream  (Pass 1) could be not saved"
							tui-yesno "Continue anyway?" || exit 0
						fi
					#
					#	Execute the command - PASS 2
					#
						# As i understand it, the actual file of the first writing is not required???
						#rm "$tmp_of" # seriously?
						sed s,"pass 1","pass 2",g -i "$TMP"
						doLog "Command-Video-Pass2: $(cat $TMP)"
						
						STR2="* Encoded Videostream (Pass 2) to \"${tmp_of##*/}\""
						STR1="* Encode Videostream (Pass 2) in $PASS passes to \"${tmp_of##*/}\""
						# Acutaly encode the audio stream to the file now
						if tui-bgjob -f "$tmp_of" "$TMP" "$STR1" "$STR2"
						then	#done_files[$done]+="$tmp_of"
							doLog "Video : Stream (Pass 2) saved to $tmp_of"
							# ((done++))
						else	tui-status 1 "Failed to encode $tmp_of (Pass 2)"
							doLog "Video : Stream  (Pass 2) could be not saved"
							tui-yesno "Continue anyway?" || exit 0
						fi
					
						# Generate the merging command
						#tui-title "Merge the streams"
						cmd="ffmpeg $verbose $web $extra -i \"$tmp_of\"" # -i \"$video.rm\"" # -map 0:0"
						C=0
						for D in "${done_files[*]}";do
							#echo "$DONE"
							cmd+=" -i \"$D\"" # -map 0:$C"
							((C++))
						done
					
						cmd+=" $F \"${OF}\"" # -dcodec copy -map_metadata 0
						doLog "Command-Merge: $cmd"
						msg+=" Converting"
						STR2="* Merged Audio- & Videostreams into  \"${OF##*/}\""
						STR1="* Merging Audio- & Videostreams into \"${OF##*/}\""
						
						;;
					esac
			esac
			msg+=" from \"$video\" to \"$OF\""
			remover="$(dirname $video)"
			tui-printf "${msg/$remover/}" "$WORK"
			printf "$cmd" > "$TMP"
		#
		#	Execute the command
		#
			if [[ $mode = "file" ]] || [[ $mode = "dvd" ]]
			then 	tui-bgjob -f "$OF" "$TMP" "$STR1" "$STR2"
				RET=$?
			else	sh "$TMP"
				tui-status $? "$STR2"
				RET=$?
			fi
		#
		#	Do some post-encode checks
		#	
			if [[ mkv = $container ]] && [[ $RET -eq 0 ]] && [[ $PASS -ge 2 ]]
			then	# Set default language if mkv encoding was a successfull 2-pass
				# aid = audio id (of stream)
				[[ 0 -eq $aid ]] && aid=1
				msg="* Set first Audiostream as enabled default and labeling it to: $lang"
				tui-printf "$msg" "$WORK"
				doLog "Audio : Set default audio stream $aid($lang)"
				mkvpropedit -q "$OF"	--edit track:a$aid --set flag-default=0 \
							--edit track:a$aid --set flag-enabled=1 \
							--edit track:a$aid --set flag-forced=0 \
							--edit track:a$aid --set language=$lang
				tui-status $? "$msg"
			fi
			#Generate log message
			if [[ 0 -eq $RET ]] 
			then	ret_info="successfully (ret: $RET) \"$OF\""
			else	ret_info="a faulty (ret: $RET) \"$OF\""
			fi
			# Remove tempfiles that were required for 2-pass
			if  [[ $PASS -ge 2 ]] && [[ 0 -eq $RET ]]
			then 	tui-title "Remove Tempfiles"
				for F in "$tmp_of" "${done_files[*]}" ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree ;do
				tui-printf "Removing \"$F\"" "$WORK"
				rm "$F"
				tui-status $? "Removed: \"$F\"" 
				done
			fi
		#
		#	Log if encode was successfull or not
		#
			doLog "End: Encoded $ret_info "
			if [[ ! -z $2 ]] 
			then	doLog "--------------------------------"
				msg="Timeout - $sleep_between seconds between encodings..."
				[[ ! -z $sleep_between ]] && \
					doLog "Script : $msg" && \
					tui-echo && tui-wait $sleep_between "$msg" #&& tui-echo
				# Show empty log entry line as optical divider
				doLog ""
			fi
		else	msg="Skiped: $video"
			doLog "$msg"
			tui-status $RET_SKIP "$msg"
		fi
	done	
	if [[ $show_menu = true ]]
	then 	tui-status $RET_INFO "See '$ME -h' for help"
		tui-status 1 "Menu is not supported yet" || exit $?
		
		# Show menu
		# after 'generating' the basic variables
		tui-echo "Selected input:" "$video"
		# Verify output filename
		outputfile=$(genFilename "$video" "$container")
		tui-echo "What is the outputs name? (leave empty for: $outputfile)"
		newname=$(tui-read "Type the name:")
		[[ -z "$newname" ]] && newname="$outputfile"
		# If user has not passed file container / extension
		printf "$newname"|grep -q $container || newname+=".$container"
	fi
exit 0
