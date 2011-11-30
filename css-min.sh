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
# <lauri@rooden.ee> wrote this file. As long as you retain this notice
# you can do whatever you want with this stuff. If we meet some day, and
# you think this stuff is worth it, you can buy me a beer in return.
# -- Lauri Rooden
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

export LC_ALL=C

while getopts ':l:' OPT; do
	case $OPT in
		l)  sed -e 's/^/ * /' -e '1i/**' -e '$a\ *\/' $OPTARG;;

		:)  echo "Option -$OPTARG requires an argument." >&2; exit 1;;
		\?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
	esac
done

shift $((OPTIND-1))

css_import() {
	while read s; do
		case "$s" in
			"@import "*)
				file=$(expr -- "$s" : ".*url(['\"]*\([^'\")]*\)")
				path=$(echo "$file" | sed -E -e :a -e 's,([^/]*[^.]/\.\./|\./|[^/]+$),,;ta')
				sed -E -e "s,url\(['\"]*,&$path,g" "$file" | css_import
				;;
			*"/*! data-uri */")
				file=$(expr -- "$s" : ".*url(['\"]*\([^'\")]*\)")
				#data=$(openssl enc -a -in $a | tr -d "\n")
				s=$(echo "$s" | sed "s:$file:%s:;s:/\*.*$::")
				printf "$s" "data:image/${file##*.};base64,$(base64 -w0 $file)"
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


