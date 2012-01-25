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

NAMES=()

while getopts ':l:s' OPT; do
	case $OPT in
		# insert license file
		l)  sed -e 's/^/ * /' -e '1i/**' -e '$a\ *\/' $OPTARG;;

		# reset sprite images
		s)  rm -f sprite.txt;;

		:)  echo "Option -$OPTARG requires an argument." >&2; exit 1;;
		\?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
	esac
done

shift $((OPTIND-1))

file_in_url() {
	expr -- "$1" : ".*url(['\"]*\([^'\")]*\)"
}

clean_dirname() {
	echo "$1" | sed -E -e :a -e 's,([^/]*[^.]/\.\./|\./|[^/]+$),,;ta'
}

css_import() {
	while read s; do
		case "$s" in
			"@import "*)
				file=$(file_in_url "$s")
				sed -E -e "s,url\(['\"]*,&$(clean_dirname "$file"),g" "$file" | css_import
				;;
			*"/*! data-uri */")
				file=$(file_in_url "$s")
				#data=$(openssl enc -a -in $a | tr -d "\n")
				s=$(echo "$s" | sed "s:$file:%s:;s:/\*.*$::")
				printf "$s" "data:image/${file##*.};base64,$(base64 -w0 $file)"
				;;
			*"/*! sprite "*)
				file=$(file_in_url "$s")
				name="$(expr -- "$s" : ".*sprite \([[:alpha:]]*\)").png"
				pos=$(sed -n "/ ${file//\//\\/}/s/ .*//p" sprite.txt 2>/dev/null)
				if [ -z "$pos" ]; then
					if [[ "${NAMES[@]}" = *"$name"* ]]; then
						pos=$(identify -format "%h" "$name")
						convert "$name" "$file" -append PNG8:"$name"
					else
						pos=0
						convert "$file" PNG8:"$name"
						NAMES=("${NAMES[@]}" "$name")
					fi
					echo "$pos $file" >> sprite.txt
				fi
				echo "$s" | sed "s:/\*.*$::;T;s:url([^)]*:url($name:;T;s:px 0px:px ${pos}px:;t;s:top:${pos}px:;t;s:):) 0px ${pos}px:"
				;;
			*)
				echo "$s"
				;;
		esac
	done
}


for a in "$@"; do
	echo "@import url('$a');" | css_import
done |

# remove comments BSD safe
sed -E \
    -e '/\/\*([^@!]|$)/ba' -e b  -e :a \
    -e 's,/\*[^@!]([^*]|\*[^/])*\*/,,g;t' \
    -e 'N;ba' |

tr -s "\t\n " " " | tr "'" '"' |

sed -E \
    -e 's/ *([,;{}]) */\1/g' \
    -e 's/^ *//' \
    -e 's/;*}/}\
/g' |

sed -E \
    -e '/(^|\{\})$/d' \
    -e 's/ and\(/ and (/g;t' \
    -e 's/: */:/g' \
    -e 's/([^0-9])0(px|em|%|in|cm|mm|pc|pt|ex)/\10/g' \
    -e 's/:0 0( 0 0)?(;|})/:0\2/g' \
    -e 's,url\("([[:alnum:]\./_-]*)"\),url(\1),g' \
    -e 's/([ :,])0\.([0-9]+)/\1.\2/g'


# Show repeated rules
# sed 's/^[^{]*//' min.css | sort | uniq -cid | sort -r


for name in "${NAMES[@]}"; do
	pngcrush -rem allb -brute -reduce "$name" _.png >/dev/null && mv -f _.png "$name"
done

#pngcrush -rem allb -brute -reduce original.png optimized.png
#optipng -o7 original.png


