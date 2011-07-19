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
#   - Unix tools: cat, sed, tr
#
#

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
			@import*)
				file=$(expr -- "$s" : '@import url(['\''"]*\([^'\''"]*\)['\''"]*')
				# remove comments BSD safe
				sed -E -e '/\/\*([^@]|$)/ba' -e b -e :a -e 's,/\*[^@]([^*]|\*[^/])*\*/,,g;t' -e 'N;ba' "$1$file" |
					css_import "$1$(expr -- "$file" : '\(.*/\)')"
				;;
			*) echo "$s" ;;
		esac
	done | 
		tr -s "'\t\n " '" ' |
		sed -E -e 's/ *([,;{}]) */\1/g' \
		       -e 's/([.:]) */\1/g' \
		       -e 's/([^0-9])0(px|em|%|in|cm|mm|pc|pt|ex)/\10/g' \
		       -e 's/:0 0( 0 0)?(;|})/:0\2/g' \
		       -e "s,url\(['\"]*,&$1,g" \
		       -e 's,url\("([0-9a-z\./_-]*)"\),url(\1),g' \
		       -e 's/(:| )0\.([0-9]+)/\1.\2/g' \
		       -e 's/;*}/}\
/g' | 
		sed -e 's/;;*/;/g' -e 's/ and(/ and (/g' -e '/^.*{}$/d' -e 's,^ *,,' -e '/^$/d'
}


for a in "$@"; do
	echo "@import url('$a');" | css_import ""
done

