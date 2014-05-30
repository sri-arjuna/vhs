vhs
===

Video Handler by Sea, using ffmpeg

This script requires TUI(https://github.com/sri-arjuna/tui)


Hello everyone

I'd like to present my newest script: VHS
Given the name, its all about videos.

The main purpose why i wrote the script, was and still is, to re-encode already existing video files.
The three targets i wanted to achieve:
1) Make large video files smaller
2) encode them to FOSS (or just easily from 1 container to another)
3) Get rid of unwanted audio streams (as in: only use the audio stream with my langauge)

Quickly i found [URL="http://ffmpeg.org"]ffmpeg[/URL] which is just awesome.
It is that powerfull, and provides options, that i wanted to include some addidtional functions:
* Capture Desktop/Screen
* Capture Webcam
* Encode DVD's

In order for this script to work, please install [URL="https://github.com/sri-arjuna/tui/wiki/Installation"]TUI[/URL]:
[code]
    sudo git clone https://github.com/sri-arjuna/tui.git /tmp/tui.inst
    sudo sh /tmp/tui.inst/install.sh
[/code]

Once done, copy VHS to your $HOME/bin or $HOME/.local/bin, 
if you trust my script, you could copy it to /usr/bin instead.

Upon first call, it'll open the setup dialog.
Please just execute the 'UpdateLists' before changing values, that way you ensure that all lists (but unpluged webcam) are available.
Choose your prefered container (mine's mp4, its the fastest with good quality), language for audio streams, and bitrates.

One configured, the 'regular' calls should look like:
[code]vhs [-B] file file2..	# Encode video files
vhs -s		# Record screen
vhs -W		# Record from webcam
[/code]

[U]Some examples for further options:[/U]
[CODE]vhs [/path/to/]file			# Encodes a specific file
vhs *					# Encodes all files in current directory, using the sources bitrates
vhs -b a128 -b v256 files		# Encode a video with given bitrates in kbytes
vhs -B files				# Encode a video with default bitrates
vhs -c vlibtheora -c alibvorbis files	# Encode a file with given codecs
vhs -e XY files				# Encode a video with container XY rather than favorite
vhs -w files				# Encode a video and move info flags in front (web/streaming)
vhs -v files				# Encode a video and (ffmpeg) be verbose
vhs -C files				# Copy streams - dont encode[/CODE]

[U]Example with devices:[/U]
[CODE]vhs -D					# Encodes a DVD
vhs -s					# Screenrecorder
vhs -W					# Webcam - actualy video log[/CODE]
NOTE: That the webcam doesnt work for me, but i do can chooose its video-res/fps capabilities..
DVD & Webcam provide mutiple options as of now which forces interaction, but they're no 'mass-work' either.

Btw: the part i'm most proud/happy about are these:
I could re-encode a complete series (291 episodes) from 55 GB to 17GB without (visual) quality loss, within less than 7 hours.
Using the "-w" options, i could make some of the mkv (now mp4) multi subbed files playable on the TV (tv used english to play, now there is only german left )
NEW: Copy streams is incredible fast, 2min 30secs for 17 files of ~45min duration (250mb size).

Hope this helps
Enjoy :dance:


[I]EDIT:[/I]
It is 'done', as every function is 'working', but not perfectly tuned. There's still lots to do.

For 'bug reports' please post here the output of the 'verbose' (-v) call, and either attach the log or put the regarding text in [ code ] tags.

For later updates (few months after post date), please refer to: [url]https://github.com/sri-arjuna/vhs[/url]

VIDEOS: (Please watch in HD)
* [URL="http://youtu.be/qNVSfvdNx40"]Backup a DVD[/URL] (how it could look/work)
