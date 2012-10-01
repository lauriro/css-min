#!/bin/sh
#
#
# Tool for merging and minimizing css files
#
#    @version  pre-0.3
#    @author   Lauri Rooden - https://github.com/lauriro/css-min
#    @license  MIT License  - http://www.opensource.org/licenses/mit-license
#
# Usage: ./css-min.sh [FILE]... > min.css
#



# Exit the script if any statement returns a non-true return value
set -e

export LC_ALL=C


get_url() {
	local a="${1#*url(}";a="${a%)*}"
	a="${a#\'}";a="${a%\'}";a="${a#\"}" # unquote
	printf %s "${a%\"}"
}

normalize_path() {
	printf %s "$1" | sed -E -e :a -e 's,([^/]*[^.]/\.\./|\./|[^/]+$),,;ta'
}

css_import() {
	while read -r s; do
		case "$s" in
			"@import "*)
				file=$(get_url "$s")
				sed -E -e "s,url\(['\"]*,&$(normalize_path "$file"),g" "$file" | css_import
				;;
			*)
				printf %s\\n "$s"
				;;
		esac
	done
}


# A license may be specified with the `-l` option.
test "$1" = '-l' && {
	sed -e 's/^/ * /' -e '1i\
/**' -e '$a\
\ *\/' "$2"
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
	POS=$(cat sprite.txt 2>/dev/null)
	UPDATED=""

	while read -r s; do
		case "$s" in
			*"/*! data-uri */")
				# Remove comment
				s="${s%%/\**}"

				file=$(get_url "$s")
				echo "${s%%$file*}data:image/${file##*.};base64,$(base64 -w0 $file)${s##*$file}"
				# printf "%sdata:image/%s;base64,%s%s" "${s%%$file*}" "${file##*.}" "$(base64 -w0 $file)" "${s##*$file}" 
				#data=$(openssl enc -a -in $a | tr -d "\n")
				;;
			*"/*! sprite "*)
				file=$(get_url "$s")

				# Extract sprite name from comment
				name="${s##*sprite }";name="${name%% *}.png"

				# Remove comment
				s="${s%%/\**}"

				pos=""
				for item in $POS; do
					case "$item" in
						*":$file:"*)
							pos=${item%%:*}
							break
							;;
					esac
				done
				if [ -z "$pos" ]; then
					case "$POS " in
						*":$name "*)
							pos=$(identify -format "%h" "$name")

							# TODO:2012-01-30:lauriro: 1px gap between sprite parts is needed to work around zoom errors (at least in IE).
							convert "$name" "$file" -append PNG8:"$name"
							;;
						*)
							pos=0
							convert "$file" PNG8:"$name"
							;;
					esac
					POS="$pos:$file:$name $POS"

					test " ${UPDATED#* $name } " = " $UPDATED " || UPDATED="$name $UPDATED"
				fi
				echo "$s" | sed "s:url([^)]*:url($name:;T;s:px 0px:px -${pos}px:;t;s:top:-${pos}px:;t;s:):) 0px -${pos}px:"
				;;
			*)
				printf %s\\n "$s"
				;;
		esac
	done

 	echo "$POS" > sprite.txt

 	for name in $UPDATED; do
 		echo "pngcrush: $name" >&2
 		pngcrush -rem allb -brute -reduce "$name" _.png >/dev/null && mv -f _.png "$name"
 	done

} |

tr "'\t\n" '"  ' |

# Remove optional spaces and put each rule to separated line
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




