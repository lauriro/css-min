#!/bin/sh
#
# Tool for merging and minimizing css files
#
# Usage: ./css-min.sh [FILE]... > min.css
#
#
# THE BEER-WARE LICENSE
# =====================
#
# <lauri@rooden.ee> wrote this file. As long as you retain this notice you 
# can do whatever you want with this stuff at your own risk. If we meet some 
# day, and you think this stuff is worth it, you can buy me a beer in return.
# -- Lauri Rooden -- https://github.com/lauriro/web_tools
#
#
# Dependencies
# ============
#
# The following is a list of compile dependencies for this project. These
# dependencies are required to compile and run the application:
#   - Unix tools: expr, sed, tr
#   - base64 tool or openssl
#
#

# Exit the script if any statement returns a non-true return value
#set -e

export LC_ALL=C

unquote(){
	local a="$1"
	a="${a#\"}";a="${a%\"}";a="${a#\'}"
	echo ${a%\'}
}


file_in_url() {
	local a="$1"
	a="${a#*url(}"
	unquote "${a%)*}"
	#expr -- "$1" : ".*url(['\"]*\([^'\")]*\)"
}

clean_dirname() {
	echo "$1" | sed -E -e :a -e 's,([^/]*[^.]/\.\./|\./|[^/]+$),,;ta'
}

css_import() {
	while read s; do
		[[ "$s" = "@import "* ]] && {
				file=$(file_in_url "$s")
				sed -E -e "s,url\(['\"]*,&$(clean_dirname "$file"),g" "$file" | css_import
		} || echo "$s"
	done
}



# A license may be specified with the `-l` option.
test "$1" = '-l' && {
	sed -e 's/^/ * /' -e '1i/**' -e '$a\ *\/' "$2"
	shift;shift
}



# Import CSS files specified in arguments
for a in "$@"; do echo "@import url('$a');"; done | css_import |

# remove non-important comments
sed -E \
    -e '/\/\*([^@!]|$)/ba' -e b  -e :a \
    -e 's,/\*[^@!]([^*]|\*[^/])*\*/,,g;t' \
    -e 'N;ba' |

# replace data-uri's and sprites
{
	POS=($(cat sprite.txt 2>/dev/null))
	UPDATED=()

	while read s; do
		case "$s" in
			*"/*! data-uri */")
				# Remove comment
				s="${s%%/\**}"

				file=$(file_in_url "$s")
				echo "${s%%$file*}data:image/${file##*.};base64,$(base64 -w0 $file)${s##*$file}"
				#data=$(openssl enc -a -in $a | tr -d "\n")
				;;
			*"/*! sprite "*)
				file=$(file_in_url "$s")

				# Extract sprite name from comment
				name="${s##*sprite }";name="${name%% *}.png"

				# Remove comment
				s="${s%%/\**}"

				pos=""
				for item in "${POS[@]}"; do
					[[ "$item" = *":$file:"* ]] && pos=${item%%:*} && break
				done
				if [ -z "$pos" ]; then
					if [[ " ${POS[@]} " = *":$name "* ]]; then
						pos=$(identify -format "%h" "$name")

						# TODO:2012-01-30:lauriro: 1px gap between sprite parts is needed to work around zoom errors (at least in IE).
						convert "$name" "$file" -append PNG8:"$name"
					else
						pos=0
						convert "$file" PNG8:"$name"
					fi

					POS=("${POS[@]}" "$pos:$file:$name")
					[[ " ${UPDATED[@]} " = *" $name "* ]] || UPDATED=("${UPDATED[@]}" "$name")
				fi
				echo "$s" | sed "s:url([^)]*:url($name:;T;s:px 0px:px -${pos}px:;t;s:top:-${pos}px:;t;s:):) 0px -${pos}px:"
				;;
			*)
				echo "$s"
				;;
		esac
	done

	echo "${POS[@]}" > sprite.txt

	for name in "${UPDATED[@]}"; do
		echo "pngcrush: $name" >&2
		pngcrush -rem allb -brute -reduce "$name" _.png >/dev/null && mv -f _.png "$name"
	done

	#pngcrush -rem allb -brute -reduce original.png optimized.png
	#optipng -o7 original.png

} |

tr "'\t\n" '"  ' |

# Remove spaces and put each rule to separated line
sed -E \
    -e 's/ *([,;{}]) */\1/g' \
    -e 's/^ *//' \
    -e 's/;*}/}\
/g' |


# Use CSS shorthands
sed -E \
    -e '/(^|\{\})$/d' \
    -e 's/ and\(/ and (/g;t' \
    -e 's/: */:/g' \
    -e 's/([^0-9])-?0(px|em|%|in|cm|mm|pc|pt|ex)/\10/g' \
    -e 's/:0 0( 0 0)?(;|})/:0\2/g' \
    -e 's,url\("([[:alnum:]/_.-]*)"\),url(\1),g' \
    -e 's/([ :,])0\.([0-9]+)/\1.\2/g'


# Show repeated rules
# sed 's/^[^{]*//' min.css | sort | uniq -cid | sort -r




