# bash completition for Video Handler Script (VHS)
# file: /etc/bash_completion.d/vhs_compl.bash
# 2014.11.29 by sea, based on blkid
# ---------------------------------

_vhs_module()
{
#
#	Variables
#
	local cur prev OPTS DIR
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	OPTS="-2 -a -A -b -B -c -C -d -D -e -f -F -G -i -I -j -K -l -L -p -q -Q -r -R -S -t -T -v -V -x -X -y -z"
	DIR="$HOME/.config/vhs/containers"
	langs="ara bul chi cze dan eng fin fre ger hin hun ice nor pol rum spa srp slo slv swe tur"
#
#	Action
#
	# This completes the custom entries from $DIR
	# But only use this, if 'prev' was one using entries from $DIR
	# This list is dynamicly (automaticly) updated
	case $prev in
	-e)
		case $cur in
		[a-zA-Z]*)	COMPREPLY=( $( compgen -W "$(cd $DIR 2>/dev/null && echo $cur*)" -- "$cur" ) ) 
				return 0
				;;
		esac
		;;
	esac
	
	# This completes the word you are currently writing
	# These need manual maintainance
	case $cur in
		-*)	COMPREPLY=( $(compgen -W "${OPTS[*]}" -- $cur) )
			return 0
			;;
	esac
	
	# This shows a list of words applying to your last argument
	# These need manual maintainance
	case $prev in
		-a|-i|vhs)
			COMPREPLY=( $(compgen -f -- $cur) )
			return 0
			;;
		-b)	COMPREPLY=( $(compgen -W "a v" -- $cur) )
			return 0
			;;
		-c)	COMPREPLY=( $(compgen -W "a s v" -- $cur) )
			return 0
			;;
		-d|-q|-Q)
			COMPREPLY=( $( compgen -W "screen clip vhs dvd hdr fhd uhd" -- "$cur" ) ) 
			return 0
			;;
		-e)	COMPREPLY=( $( compgen -W "$(cd $DIR 2>/dev/null && echo *)" -- "$cur" ) ) 
			return 0
			;;
		-f)	COMPREPLY=( $( compgen -W "23.9 24 25 26 29 29.9 33 48 50 60 75 100" -- "$cur" ) ) 
			return 0
			;;
		-l)	COMPREPLY=( $(compgen -W "$(echo $langs)" -- $cur) )
			return 0
			;;
		-p)	COMPREPLY=( $(compgen -W "bl br bc cl cr cc tl tr tc" -- $cur) )
			return 0
			;;
		-r)	COMPREPLY=( $(compgen -W "41000 44000 96000" -- $cur) )
			return 0
			;;
		-z)	COMPREPLY=( $( compgen -W "0:01-1:23:45.99" -- "$cur" ) ) 
			return 0
			;;
		-h)	return 0
			;;
	esac
}
# Actualy make it available to the shell
complete -F _vhs_module vhs