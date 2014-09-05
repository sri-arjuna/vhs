#!/bin/bash
checkfiles=( 	"/mnt/windows/Users/Arjuna/Videos/Gantz 2011 BRRip 470MB [Audio-JAP,ENG] x264 AAC - VYTO/Gantz (jap-eng,2011,BRRip.mkv" \
		"/mnt/windows/Users/Arjuna/Videos/Gantz.Perfect.Answer.2011.BluRay.720p.x264.Ganool.mkv" \
		"/mnt/windows/Users/Arjuna/Videos/2_xxx/x_art_scarlet_christine_mrX_fantasy_come_true_540.mov"
		"/home/sea/net/pub/Videos-Series/Stargate/SG Atlantis/Stargate Atlantis - S1/01&02 - Rising.0.mkv"
	)
#for C in "${checkfiles[@]}";do ./vhs-todo.sh -i "$C";./vhs-todo.sh -Vl jpn -Bl fre -d dvd "$C";done
#exit
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
#			Easy mass re-code files as it takes each file's name as replaces its container extension for the output.
#			If that new name exists, it numbers it incremently, so you cannot delete your input file by accident (from the script

#			The script suggestions are based upon personal prefered relation of filesize-and-videoquality,
#			with a slight tendency to prefer small filesizes.
#			Kind:	~Resolution:	Audio:	Video:
#			VHS	 576*360	128k	 256k
#			CLIP	 640*480	128k	 384k
#			DVD	 720*576 	192k	 512k
#			HDR	1280*720	192k	 768k
#			FHD	1920*1080	256k	1280k
#
#			It should encode a DVD with your prefered language only - when called from terminal,
#			but let you choose which languages, when your prefered langauge is not found.
#
#			You may add languages to encode, by passing '-l LNG' multiple times
#			
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
	doExternal=false		# -E
	override_audio_codec=false	# -c a	/ -C
	override_video_codec=false	# -c v	/ -C
	override_container=false	# -e ext
	useRate=false			# -R
	codec_extra=false		# Depends on container /file extension
	file_extra=false		# Depends on container /file extension
	# Values - 
	MODE=video			# -D, -W, -S, -e AUDIO_EXT	audio, dvd, webcam, screen
	cmd_all=""
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
	hwaccel="-hwaccel vdpau"	# -H		Enable hw acceleration
#
#	Help text
#
	help_text="
$ME ($script_version) - ${TITLE^}
Usage: 		$ME [options] [arguments]

Examples:	$ME -s				| Enter the configuration/setup menu
		$ME -b a128 -b v512 filename	| Encode file with audio bitrate of 128k and video bitrate of 512k
		$ME -c aLIBX -c vLIBY filename	| Force given codecs to be used for either audio or video (leading char)
		$ME -DC filename		| Re-encode a DVD and just copy streams
		$ME -[DSW]			| Encodes from DVD or captures video from screen or webcam
		$ME -l ger			| Add this language to be added automaticly if found

Where options are: (only the first letter)
	-h(elp) 			This screen
	-b(itrate)	[av]NUM		Set Bitrate to NUM kilobytes, use either 'a' or 'v' to define audio or video bitrate
	-B(itrates)			Use bitrates (av) from configuration
	-C(opy)				Just copy streams, fake convert
	-c(odec)	[av]NAME	Set codec to NAME for audio or video
	-d(imension)	ID		Set the videos resolution to ID
					Available: dvd screen hdr fhd (hd ready, full hd)
					This is to downsize only, upsize will NOT improve quality
	-D(VD)				Encode from DVD
	-e(xtension)	CONTAINER	Use this container (ogg,webm,avi,mkv,mp4)
	-E(xternal)			Requires '-p 2|3', Saves the audio streams as external files
	-f(aststart)			Moves the videos info to start of file (web compatibility)
	-i(nfo)		VIDEO		Shows a tui-title per video and tui-echo its streams
	-l(anguage)	LNG		Only encode LNG audio stream (3 letter abrevihation, eg: eng,fre,ger,spa)
	-L(OG)				Show the log file
	-O(utputFile)	NAME		Forces to save as NAME, this is internal use for '-Ep 2|3'
(BETA)	-p(ass)		NUM		Encodes the video with 2|3-Pass
	-r(ate)		NUM		Values from 48000 to 96000, or similar
	-R(ate)				Uses the frequency rate from $CONFIG
	-S(creen)			Records the fullscreen desktop
	-s(etup)			Shows the configuration dialog
(PLAN)	-t(itles)	??		Include this subtitle
	-T(imeout)	TIME		Set the timeout between videos to SECONDS (append either 'm' or 'h' as other units)
	-v(erbose)			Displays encode data from ffmpeg
	-V(erbose)			Show script debuging info.
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
		ffmpeg  -psnr -i "$1" 1> "$TMP" 2> "$TMP"
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
	# Returns true if LANG was found in VIDEO
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[[ -z $2 ]] && \
			cmd="grep -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|grep -i audio|grep -q -i "$1"
		return $?
	}
	hasLangDTS() { # LANG [VIDEO] 
	# Returns true if LANG was found in VIDEO and declares itself as DTS
	# If VIDEO is not passed, it is assumed that $TMP.info contains the current data
		[[ -z $2 ]] && \
			cmd="grep -i stream \"$TMP.info\"" || \
			cmd="StreamInfo \"$2\""
		eval $cmd|grep -i audio|grep -i $1|grep -q DTS
		return $?
	}
	hasSubtitle() { # LANG [VIDEO] 
	# Returns true if LANG was found in VIDEO
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
		
		if [[ ! $ext = $container ]]
		then 	video="${video/$ext/}$container"
			[[ ! -f $video ]] && \
				doLog "Output: \"$video\"" && \
				printf "$video" && return 0
		fi
		
		# new file name would be the same
		name="${video/$ext/}"
		N=0
		while [[ -f "$name.$N.$container" ]] ; do ((N++));done
		outputfile="$name.$N.$container"
		doLog "Output: Has same extension, incrementing to \"$outputfile\""
		
		printf "$outputfile"
	}
	getRes() { # [-l] ID
	# Returns 2 digits (W*H) according to ID
	# use -l to get a list of valid ID's
		LIST=( screen clip dvd hdr fhd)
		[[ "-l" = "$1" ]] && \
			printf "${LIST[*]}" && \
			return 0
		[[ -z $1 ]] && \
			printf "Must provide a valid ID!" && \
			exit 1
		case "$1" in
		"${LIST[0]}")	xrandr|grep \*|awk '{print $1}'	;;
			#xrandr|grep \*|sed s,x,' ',g|awk '{print $1" "$2}'|sed s,x,\ ,g
		"${LIST[1]}")	printf "640x480" ;;
		"${LIST[2]}")	printf "720x576" ;;
		"${LIST[3]}")	printf "1280x720" ;;
		"${LIST[4]}")	printf "1920x1080" ;;
		esac
		return 0
	}
	doExecute() { # SCRIPT [OF STR1 STR2]
	# Executes the script according to script options
	#
		[[ -z $1 ]] && tui-echo "Must provide a script to execute!" && return 1
echo		$SCRIPT
		SCRIPT="$1"
		if $showFFMPEG
		then	case $MODE in
			dvd|video)	msg="Encoded to"	;;
			screen|webcam)	msg="Recorded to"	;;
			esac
			tui-status $RET_TODO "$msg $OF"
			sh "$SCRIPT"
			tui-status $? "$msg $OF"
			RET=$?
		else	tui-bgjob -f "$2" "$SCRIPT" "$3" "$4"
			RET=$?
		fi
		return $RET
	}
	doAudio() { # [VIDEO]
	# Fills the variable/list: audio_ids
	# Its just a list of the audio id's used
		[[ ! -z $1 ]]  && StreamInfo "$1" > "$TMP.info" && \
			tui-echo "Created $TMP.info again, just to be sure"
		
		countAudio=$(countAudio)
		$beVerbose && tui-echo "Found $countAudio audio stream/s in total"
		case $countAudio in
		0)	msg="No audio streams found, aborting!"
			tui-status 1 "$msg"
			doLog "$msg"
			exit $RET_FAIL
			;;
		1)	tui-echo "Using only audio stream found..." "$DONE"
			audio_ids=1
			;;
		*)	count=0
			for l in $lang $lang_alt $langs;do
				((count++))
				# 'this' contains all the ids for the specific langauge...
				this=""
				if hasLang $l
				then 	# Prefered language found, is it dts, downcode it?
					hasLangDTS $l && \
						$channel_downgrade && \
						cmd_run_specific="-ac $channel" && \
						$beVerbose && tui-echo "Downgrading channels from DTS to $channel"
					# Get all stream ids for this language
					found=0
					for i in $(listAudioIDs);do
						if listIDs|grep ^$i |grep  $l
						then	this+=" $i" 
							((found++)) 
							$beVerbose && tui-echo "Found $l on stream $i"
						fi
					done
					
					
			# TODO
			# 	Insert check for default stream
			# TODO
					
					$beVerbose && tui-echo "There are $found audio streams found for $l"
					# found is the amount of indexes per langauge
					case $found in
					1)	# $count represents the order of languages: lang lang_alt 'list of added langs'
						case $count in
						1)	audio_ids="$this"	;;
						2)	# This applies only to $lang_alt
							if [[ -z $audio_ids ]]
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
							if grep Audio "$TMP.info"|grep $l|grep default
							then 	audio_ids+=" $i"
								$beVerbose && \
									tui-echo "Found default entry for language $l" && \
									tui-echo "Current ids to use: $audio_ids"
								break #1
							else	$beVerbose && tui-echo "ID $i is not default"
								tui-echo "Please select the stream id you want to use:"
								select i in $this;do 
									audio_ids+=" $i"
									break
								done
							fi
						done
					esac
					found=0
				else	$beVerbose && tui-echo "Didnt find: $l"
				fi
			done
			# If both (lang & lang_alt) are requested, add up the list
			#$lang_force_both && audio_ids+=" $lang_force_both_store"
			;;
		esac
		#printf "$audio_ids"
	}
	doDVD() { # FILEforCOMMAND
	# Writes the generated command to 'FILEforCommand'
	#
		msg+=" Encoding"
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
		printf "$cmd" > "$TMP.cmd"
	}
	doWebCam() { #
	#
	#
		# TODO
		# Done ?? dont work for me, but seems to for others
		# Maybe because i have disabled the laptop's internal webcam in BIOS
		msg+=" Capturing"
		tui-status $RET_INFO "Press 'q' to stop recording from the $MODE..."
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
					## cmd="ffmpeg $verbose -f v4l2 -s $webcam_res -i /dev/video0 $F \"${OF}\"" ## ORGINAL
					cmd="ffmpeg $verbose -f v4l2 -s $webcam_res -i $input_video $F \"${OF}\""
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
		printf "$cmd" > "$TMP.cmd"
	}
	WriteContainers() { # 
	# Writes several container files and their default / suggested values
	#
		$beVerbose && tui-title "Write Containers"
		header="# $ME ($script_version) - Container definition"
		[[ -d "$CONTAINER" ]] || mkdir -p "$CONTAINER"
		cd "$CONTAINER"
		for entry in avi mp4 mkv ogg webm aac ac3 dts mp3 vorbis clip dvd;do
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
				ba=192 ;	bv=768
				ext=$entry	;;
			mkv)	ca=ac3	;	cv=libx264
				ce=false ;	fe=false
				ba=256 ;	bv=1024
				ext=$entry	;;
			ogg)	ca=libvorbis ;	cv=libtheora
				ce=true	;	fe=true		
				ba=192 ;	bv=768
				ext=$entry	;;
			webm)	ca=libvorbis ;	cv=libvpx	
				ce=true	;	fe=true	
				ba=256 ;	bv=1280
				ext=$entry	;;
		# Audio Codecs
			aac)	ca=aac ;	cv=
				ce=false ;	fe=false
				ba=256 ;	bv=
				ext=$entry	;;
			ac3)	ca=ac3 ;	cv=
				ce=false ;	fe=false
				ba=256 ; 	bv=
				ext=$entry 	;;
			dts)	ca=dts ;	cv=
				ce=false ;	fe=false
				ba=512 ;	bv=
				ext=$entry	;;
			mp3)	ca=mp3 ;	cv=
				ce=false ;	fe=false
				ba=256 ; 	bv=
				ext=$entry	;;
			vorbis)	ca=libvorbis ; 	cv=
				ce=false ; 	fe=false
				ba=256 ; 	bv=
				ext=$entry	;;	
		# Experimental
			clip)	ca=aac ;	cv=libx264
				ce=true	;	fe=true	
				ba=128 ;	bv=384
				ext=mp4		;;
			dvd)	ca=mpeg2video ;	cv=mp3	
				ce= ;		fe=	
				ba=128 ;	bv=512
				ext=mpeg	;;
			webcam)	# TODO
				ca=mpeg2video ;	cv=mp3	
				ce= ;		fe=	
				ba=128 ;	bv=512
				ext=mpeg	;;
			# blob)	ca=
			#	cv=
			#	ce=
			#	fe=
			#	ba=
			#	bv=
			#	ext=$entry
			#	;;
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
			if [[ 0 -eq $? ]] 
			then	tui-printf "Wrote container info ($entry)" "$DONE"
				doLog "Container: Created '$entry' definitions succeeded" 
			else	tui-printf "Wrote container info ($entry)" "$FAIL"
				doLog "Container: Created '$entry' definitions failed"
			fi
			$beVerbose && printf "\n"
		done
	}
	UpdateLists() { #
	# Retrieve values for later use
	# Run again after installing new codecs or drivers
		[[ -f "$LIST_FILE" ]] || touch "$LIST_FILE"
		tui-title "Generating a list file"
		$beVerbose && tui-progress "Retrieve raw data..."
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
			doLog "Lists: Updated $txt_prog"
		done
		
		tui-progress "Saving Codecs-Format"
		ffmpeg $verbose -formats > "$TUI_TEMP_FILE"
		formats_raw=$(grep DE "$TUI_TEMP_FILE"|awk '{print $2}'|sed s,"\n"," ",g)
		formats=""
		for f in $formats_raw;do formats+=" $f";done
		printf "codecs_formats=\"$formats\"\n" >> "$LIST_FILE"
		doLog "Lists: Updated Codecs-Format"

		
		if [[ -e /dev/video0 ]]
		then 	#v4l2-ctl cant handle video1 .. ??
			tui-progress "Saving WebCam-Formats"
			webcam_formats=""
			[[ -z $webcam_fps ]] && webcam_fps=5
			wf="$(v4l2-ctl --list-formats-ext|grep $webcam_fps -B4 |grep Siz|awk '{print $3}'|sort)"
			for w in $wf;do webcam_formats+=" $w";done
			printf "webcam_formats=\"$webcam_formats\"\n" >> "$LIST_FILE"
			doLog "Lists: Updated WebCam-Format"

			tui-progress "Saving WebCam-frames"
			webcam_frames=""
			wf="$( v4l2-ctl --list-formats-ext|grep -A6 Siz|awk '{print $4}')"
			C=0
			for w in $wf;do webcam_frames+=" ${w/(/}";((C++));[[ $C -ge 6 ]] && break;done
			printf "webcam_frames=\"$webcam_frames\"\n"|sed s,"\.000","",g >> "$LIST_FILE"
			doLog "Lists: Updated WebCam-Frames"
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
			doLog "Setup: Write initial configuration file"
			cat > "$CONFIG" << EOF
# $CONFIG, generated by $ME ($script_version)

# Required applications found?
req_inst=false

# Available (yet supported) containers:
# -> (avi) mkv mp4 ogg webm
container=mkv

# Audio bitrate suggested range (values examples): 72 96 128 144 192 256
# Note that these values are ment for mono or stereo, to ensure quality of surround sound, 384 should be your absolute minimum
audio_bit=192

# Video bitrate suggested range (value examples): 128 256 512 768 1024 1280 1536 1920 2048 2560 4096 5120
# Note that he lower the resolution, the lower the visual lossless bitrate
# AFAIK: for full hd (1920*1080) movies 1280kb video bit rate should be almost visualy lossless.
video_bit=768

# See ffmpeg output (vhs -i FILE // ffmpeg -psnr -i FILE) for your language abrevihation
# if 'lang' is not found it will take 'lang_alt' if available
lang=ger
lang_alt=eng
lang_force_both=false

# If DTS is found, to how many channels shall it 'downgrade'?
# Range::  1) Mono, 2) Stereo, [3-5]) unkown, 6) 5.1 Surround
# If you use a surround system, just set channel_downgrade=false
channels=2
channel_downgrade=true

# Suggested audio rates (hz) are around 44000 to 96000
audio_rate=48000
audio_rate_force=false

# Subtitle
subtitle=

# How long to wait by default between encodings if multiple files are queued?
# Note that 's' is optional, and could be as well either: 'm' or 'h'.
sleep_between=45s

# This is a default value that should work on most webcams
# Please use the script's Setup to change the values
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
		VARS=$(tui-value-get -l "$CONFIG"|grep -v req)
		
		# Make a tempfile without empty or commented lines
		# And display both, variable and value to the user
		oIFS="$IFS" ; IFS="="
		touch $TMP.cfg
		printf "$(grep -v "#" $CONFIG)" > $TMP.cfg
		while read var val;do
			[[ ! "#" = "${var:0:1}" ]] && \
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
					subtitle)	tui-echo "Please select the new subtitle codec:"
							select newval in $codecs_subtitle;do break;done
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
	# set -x
	# DEBUG =
	$beVerbose && \
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
		done
#
#	Environment checks
#
	# This is optimized for a one-time setup
	if [[ ! -f "$CONFIG" ]]
	then 	tui-header "$ME ($script_version)" "$(date +'%F %T')"
		tui-bol-dir "$CONFIG_DIR"
		$beVerbose && tui-echo "Entering first time setup." "$SKIP"
		
		doLog "Setup: Writing container and list files"
		WriteContainers
		UpdateLists
		
		# Install missing packages
		tui-progress -ri movies-req -m $(printf ${REQUIRES}|wc|awk '{print $2}') " "
		if [[ false = "$req_inst" ]]
		then 	tui-title "Verify all required packages are installed"
			doLog "Req : Installing missing packages: $REQUIRED"
			tui-install -vl "$LOG" $REQUIRED && \
				FIRST_RET=true || FIRST_RET=false
			tui-status $? "Installed: $REQUIRED" && \
				ret_info="succeeded" || \
				ret_info="failed"
			doLog "Req: Installing $REQUIRED $ret_info"
		fi	
		
		MenuSetup
		tui-value-set "$CONFIG" "req_inst" "$FIRST_RET"
	fi
	source "$CONFIG"
#
#	Catching Arguments
#
	tui-log -e "$LOG" "\r---- New call $$ ----"
	while getopts "aBb:c:Cd:De:Efhi:I:Ll:O:p:Rr:SstT:Q:vVW" opt
	do 	case $opt in
		b)	char="${OPTARG:0:1}"
			case "$char" in
			a)	doLog "Options: Override audio bitrate ($BIT_AUDIO) with ${OPTARG:1}"
				BIT_AUDIO="${OPTARG:1}"
				;;
			v)	doLog "Options: Override video bitrate ($BIT_VIDEO) with ${OPTARG:1}"
				BIT_VIDEO="${OPTARG:1}"
				;;
			*)	tui-status 1 "You did not define whether its audio or video: -$opt a|v$OPTARG"
				exit 1
				;;
			esac
			$beVerbose && tui-echo "Options: Bitrates passed: $char ${OPTARG:1}"
			;;
		B)	doLog "Options: Using bitrates from $CONFIG (A:$BIT_AUDIO V:$BIT_VIDEO )"
			BIT_AUDIO=$audio_bit
			BIT_VIDEO=$video_bit
			$beVerbose && tui-echo "Options: Using default bitrates from $CONFIG"
			;;
		c)	char="${OPTARG:0:1}"
			case "$char" in
			a)	override_audio_codec=true
				doLog "Options: Override audio bitrate ($audio_codec) with ${OPTARG:1}"
				audio_codec_ov="${OPTARG:1}"
				;;
			v)	override_video_codec=true
				doLog "Options: Override video bitrate ($video_codec) with ${OPTARG:1}"
				video_codec_ov="${OPTARG:1}"
				;;
			*)	tui-status 1 "You did not define whether its audio or video: -$opt a|v$OPTARG"
				exit 1
				;;
			esac
			$beVerbose && tui-echo "Options: -'$opt', passed: $char ${OPTARG:1}"
			;;
		C)	override_audio_codec=true
			override_video_codec=true
			video_codec_ov=copy
			audio_codec_ov=copy
			msg="Options: Just copy streams, no encoding"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			;;
		d)	RES=$(getRes $OPTARG )
			msg="Options: Set video dimension (resolution) to: $RES"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			;;
		D)	MODE=dvd
			$beVerbose && tui-echo "Options: Set MODE to DVD"
			doLog "Mode: DVD"
			# RE-Place code !!
			tempdata=( $(ls /run/media/$USER) )
			[[ "${#tempdata[@]}" -ge 2 ]] && \
				tui-echo "Please select which entry is the DVD:" && \
				select name in "${tempdata[@]}";do break;done || \
				name="$(printf $tempdata)"
			OF=$(genFilename "$HOME/dvd-$tempdata.$container" $container )
			override_container=true
			;;
		e)	override_container=true
			doLog "Options: Overwrite \"$container\" with \"$OPTARG\""
			container="$OPTARG"
			$beVerbose && tui-echo "Options: Set container format to: $container"
			;;
		E)	msg="Options: Save audio files on multipass ($PASS) externaly"
			doExternal=true
			$beVerbose && tui-echo "$msg"
			doLog "$msg"
			;;
		f)	doLog "Options: Optimize for web usage."
			web="-movflags faststart"
			$beVerbose && tui-echo "Options: Moved 'faststart' flag to front, stream/web optimized"
			;;
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
			msg="Options: Showed info of $# videos"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			exit $RET_DONE
			;;
		I)	ID_FOCED+="$OPTARG"
			msg="Options: Foced to use this id: $ID_FORCED"
			$beVerbose && tui-echo "$msg"
			doLog "$msg"
			;;
		l)	langs+=" $OPTARG"
			msg="Options: Increased language list to: $langs"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			;;
		L)	doLog "Show Logfile"
			sleep 0.1
			less "$LOG"
			exit $RET_DONE
			;;
		O)	msg="Options: Forced Output File -> $OPTARG"
			OF_FORCED="$OPTARG"
			$beVerbose && tui-echo "$msg"
			doLog "$msg"
			;;
		p)	PASS="$OPTARG"	# TODO Currently fixed to this
			msg="Options: Encode as $PASS-pass"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			;;
		R)	useRate=true
			msg="Options : Force audio_rate to $audio_rate"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			;;
		r)	audio_rate="$OPTARG"
			msg="Options: Force audio_rate to $audio_rate"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			;;
		S)	MODE=screen
			# RE-Place code !!
			OF=$(genFilename "$HOME/screen-out.$container" $container )
			msg="Options: Set MODE to Screen, saving as $OF"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			;;
		s)	tui-header "$ME ($script_version)" "$(date +'%F %T')"
			MenuSetup
			exit 0	;;
		t)	msg="Options: Added these $OPTARG to subtitles"
			# TODO
			;;
		T)	msg="Options: Changed delay between jobs from \"$sleep_between\" to \"$OPTARG\""
			doLog "$msg"
			$beVerbose && \
				tui-echo "$msg" && \
				tui-echo "Note this only jumps in if you encode more than 1 video"
			sleep_between="$OPTARG"
			;;
		v)	msg="Options: Be verbose (ffmpeg)!"
			doLog "$smg"
			$beVerbose && tui-echo "$msg"
			FFMPEG="$ffmpeg_verbose"
			showFFMPEG=true
			;;
		V)	msg="Options: Be verbose!"
			doLog "$msg"
			FFMPEG="$ffmpeg_silent"
			beVerbose=true
			tui-title "Retrieve options"
			tui-echo "$msg"
			;;
		W)	MODE=webcam
			OF=$(genFilename "$HOME/webcam-out.$container" $container )
			override_container=true
			msg="Options: Set MODE to Webcam, saving as $OF"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			;;
		*)	msg="Invalid argument: $opt : $OPTARG"
			doLog "$msg"
			$beVerbose && tui-echo "$msg"
			;;
		esac
	done
	shift $(($OPTIND - 1))
#
#	Little preparations before we start showing the interface
#
	$beVerbose && tui-title "Analyse provided options..."
	src="$CONTAINER/$container" ; source "$src"
	# If (not) set...
	[[ -z $video_codec ]] && [[ ! -z $audio_codec ]] && MODE=audio		# If there is no video codec, go audio mode
	[[ -z $video_codec ]] || cmd_video_all+=" -map 0:0"			# Make sure video stream is used always
	[[ -z $FFMPEG ]] && cmd_all="$ffmpeg_silent" || cmd_all="$FFMPEG"	# Initialize the final command
	[[ -z $BIT_AUDIO ]] || cmd_audio_all="-b:a ${BIT_AUDIO}K"		# Set audio bitrate if requested
	[[ -z $BIT_VIDEO ]] || cmd_video_all="-b:v ${BIT_VIDEO}K"		# Set video bitrate if requested
	[[ -z $RES ]] || cmd_video_all+=" -vf scale=$RES"			# Set video resolution
	[[ -z $OF ]] || cmd_output_all="$OF"					# Set output file 
	[[ -z $BIT_VIDEO ]] || buffer=" -minrate $[ 8 * ${BIT_VIDEO} ] -maxrate $[ 8 * ${BIT_VIDEO} ] -bufsize $[ 8 * ${BIT_VIDEO} ]"
	# Bools...
	$file_extra && F="-f $container"					# File extra, toggle by container
	$code_extra && extra+=" -strict -2"					# codec requires strict, toggle by container
	$useRate && cmd_audio_all+=" -ar $audio_rate"				# Use default hertz rate
	$override_audio_codec && \
		cmd_audio_all+=" -c:a $audio_codec_ov" || \
		cmd_audio_all+=" -c:a $audio_codec"				# Set audio codec if provided
	if $override_video_codec						# Set video codec if provided
	then	cmd_video_all+=" -c:v $video_codec_ov"
	else	[[ -z $video_codec ]] || cmd_video_all+=" -c:v $video_codec"				
	fi
	# TODO	cmd_subtitle_all="" # Set subtitle
	

	if $beVerbose
	then	tui-echo "MODE:"	"$MODE"
		tui-echo "FFMPEG:"	"$cmd_all"
		tui-echo "Audio:"	"$cmd_audio_all"
		tui-echo "Video:"	"$cmd_video_all"
		tui-echo "Subtitles:"	"$cmd_subtitle_all"
		[[ -z $langs ]] || tui-echo "Additional Languages:"	"$langs"
		#tui-echo "Dimension:"	"$RES"
		#tui-echo "Outputfile:"	"$OF"
	fi
	
	# Special treatment
	case "$container" in
	"webm")	threads="$(grep proc /proc/cpuinfo|wc -l)" && threads=$[ $threads - 1 ] 
		cmd_audio_all+=" -cpu-used $threads"
		cmd_video_all+=" -threads $threads  -deadline realtime"
		msg="$container: Found $threads hypterthreads, leaving 1 for system"
		doLog "$msg"
		$beVerbose && tui-echo "$msg"
		;;
	esac
#
#	Display & Action
#
	tui-header "$ME ($script_version)" "$TITLE" "$(date +'%F %T')"
	# TODO Figure out audio MODE -- container?!
	# 
	$beVerbose && tui-echo "Take action according to MODE ($MODE):"
	case $MODE in
	dvd|screen|webcam) 	# TODO For these 3 i can implement the bitrate suggestions...
				#OF="$HOME/$OF"
				$beVerbose && tui-echo "Set outputfile to $OF"
				msg="Beginn:"
				msgA="Generated command for $MODE-encoding in $TMP.cmd"
				case $MODE in
				webcam) doWebCam	;;
				screen) #doScreen
					msg+=" Capturing"
					[[ -z $DISPLAY ]] && DISPLAY=":0.0"	# Should not happen, setting to default
					cmd_input_all="-f x11grab -video_size  $(getRes screen) -i $DISPLAY -f alsa -i default"
					cmd="$cmd_all $cmd_input_all $cmd_audio_all $cmd_video_all $extra $web $F \"${OF}\""
					printf "$cmd" > "$TMP.cmd"
					$beVerbose && tui-echo "$msgA"
					tui-status $RET_INFO "Press 'q' to stop recording from the $MODE..."
					;;
				dvd)	doDVD		;;
				esac
				doLog "$msgA"
				
				
				#
				# TODO
				#
				# TODO
				#
				# TODO
				#		Execute & exit
				# TODO
				#
				# TODO
				#
				# TODO
				
				cat $TMP.cmd
				sh $TMP.cmd
				exit
			;;
	audio)		$beVerbose && tui-echo "Save as $OF_FORCED, using $ID_FORCED"
			cmd="$FFMPEG -i $1 $cmd_audio_all" 
			
			echo "TODO:: $cmd"
			exit $?
			;;
	# video)		echo just continue	;;
	esac
#
#	Show menu or go for the loop of files
#
	
	for video in "${@}";do 
		doLog "----- $video -----"
		$beVerbose && tui-title "Video: $video"
	#
	#	per entry defaults
	#
		OF=$(genFilename "${video}" "$container")		# Output File
		audio_ids=						# Used ids for audio streams
		audio_maps=""						# String generated using the audio maps
		found=0							# Found streams per language
		cmd_input_all="-i \"$video\""				
		cmd_output_all="$F \"$OF\""
		cmd_run_specific=""					# Contains stuff that is generated per video
		cmd_audio_external=""					# 
		$0 -i "$video"						# Calling itself with -info for video
		tui-echo
#
#	Handle Audio
#
		doAudio "$video"					## Fills the list: audio_ids
		# Generate string for the stream ids to map
		msg="Using for audio streams: $audio_ids"
		for i in $audio_ids;do audio_maps+=" -map 0:$i";done
		#$beVerbose && tui-echo "$msg"
		doLog "$msg"
#
#	Handle video pass 1
#
		tmp_of="${OF##*/}\""
		tmp_if="${video##*/}\""
		case $PASS in
		1)	# Command just needs to be generated
			#cmd="ffmpeg $verbose -i \"${video}\" $web $extra $bits -dcodec copy -vcodec $video_codec -map 0:0  -acodec $audio_codec $audio_maps -ar 48000 $audio_streams $F \"${OF}\""
			cmd="$cmd_all $cmd_input_all $web $extra $cmd_video_all $cmd_audio_all $cmd_run_specific $cmd_audio_maps $cmd_output_all"
			doLog "Command-Simple: $cmd"
			msg+=" Converting"
			STR2="Encoded \"$tmp_if\" to \"$tmp_of"
			STR1="Encoding \"$tmp_if\" to \"$tmp_of"
			;;
#
#	Handle video passes 2/3
#
		*)	# How to encode audio, external or internal
			files_used=""
			if $doExternal
			then	# Save one file per audio id
				tui-title "Saving audio streams..."
				for i in $audio_ids;do
					tui-echo "Stream ID: $i"
					this="$video-$l.$audio_codec"
					
					
					# TODO
					#	external audio
					# TODO
					
					
					
					tui-title "This is in plan.. hold on"
					$0 -O "$this" -I $i -e $audio_codec "$video"
					
					
					
					if [[ $RET -eq 0 ]]
					then	#tui-title "TODO"
						tui-echo "* Optimize Audio (optionaly placeholder, todo)" "$TODO"
					fi
					# Add filename as input, per langauge
					cmd_run_specific+=" -i \"$this\""
				done
			else	# Just use the pre-generated $audio_maps
				cmd_run_specific+=" $audio_maps"
			fi
			
			# Do encode passes 1&2 and generate command for p3, or -1
			pre="$FFMPEG $cmd_input_all -an -pass "
			cmd_video1="$pre 1 $cmd_video_all"
			cmd_video2="$pre 2 $cmd_video_all"
			cmd_video3="$pre 3 $cmd_video_all"
			
			# PASS 1
			dummy="$(dirname $OF)/ffmpeg-?????.log"	# for x pass only, not final
			# TODO ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree
			
			
			STR1="Encoding '$tmp_if' - Pass"
			STR2="Encoded '$tmp_if' - Pass"
			doExecute "$cmd_video1" "$dummy" "$STR1 1/$PASS" "$STR2 1/$PASS"
			# doExecute() { # SCRIPT [OF STR1 STR2]
			
			# If pass is set to 2, this is generated, if its 3, 2 will be executed
			if [[ $PASS -eq 2 ]]
			then	# Generate cmd
				cmd="$cmd_video2 $cmd_audio_all $cmd_run_specific $cmd_output_all"
				$beVerbose && tui-echo "Generated command for final pass ($PASS)"
				STR1="${STR2} 2/$PASS"
				STR2="${STR2} 2/$PASS"
			else	# Execute pass 2
				$beVerbose && tui-echo "Executing command for pass 2/$PASS"
				doExecute "$cmd_video2" "$dummy" "$STR1 2/$PASS" "$STR2 2/$PASS"
				# Generate pass 3
				$beVerbose && tui-echo "Generated command for final pass ($PASS)"
				cmd="$cmd_video3 $cmd_audio_all $cmd_run_specific $cmd_output_all"
				STR1="${STR2} 3/$PASS"
				STR2="${STR2} 3/$PASS"
			fi
			;;
		esac
# Verify file does not already exists
# TODO should no longer be required, atm just failsafe
		skip=false
		if [[ -f "$OF" ]]
		then 	if tui-yesno "Outputfile ($OF) exists, overwrite it?"
			then 	rm -f "$OF"
			else	skip=true
			fi
		fi
# Skip if it was not removed
		if [[ false = $skip ]] 
		then
		#
		#	Execute the command
		#
			echo doExecute "$TMP" # OPTS

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
