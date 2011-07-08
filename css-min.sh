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
#   - Unix tools: cat, sed
#
#


css_import() {
	while read s; do
		if [ "${s:0:8}" = "@import " ]; then
			s=${s:12:(${#s}-14)}
			s=${s//[\"\']/}
			echo -e "$(cat "$1$s")\n" |
				# remove comments
				sed -e '/\/\*/{:n;/\*\//!{N;b n;};s/\/\*\([^*]\|\*[^/]\)*\*\///g}' |
				sed -e "s/'/\"/g" |
				css_import "$1$([[ $s = */* ]] && echo "${s%/*}/")" |
				tr -d "\n" |
				sed -e 's/\s+/ /g' -e 's/;\+/;/g' \
				    -e 's/\s*\([,;{}]\)\s*/\1/g' \
				    -e 's/\([.:]\)\s*/\1/g' \
						-e 's/\([^0-9]\)0\(px\|em\|%\|in\|cm\|mm\|pc\|pt\|ex\)/\10/g' \
						-e 's/:0 0\( 0 0\)?\(;\|}\)/:0\2/g' \
						-e "s/url(\"\([0-9a-z\.\/_-]*\)\")/url(\1)/ig" \
						-e 's/\(:\| \)0\.\([0-9]\+\)/\1.\2/g' \
						-e 's/;*}/}\n/g' |
				# fix and remove empty rules
				sed -e 's/ and(/ and (/g' -e '/^.*{}$/d'
		elif [ -n "$s" ]; then
			# fix url paths
			if [[ -n "$1" && $s = *url\(* ]]; then
				[[ $s = *url\(\"* ]] && s="${s//url(\"/url(\"$1}" || s="${s//url(/url($1}"
			fi
			echo "$s"
		fi
	done
}


for a in "$@"; do
	css_import "" <<< "@import url('$a');"
done

