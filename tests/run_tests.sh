#!/bin/bash

EXIT=0

cd ${0%/*}

for F in *min.css; do
	DIFF=$(../css-min.sh ${F/min/src} | diff - $F)
	if [ -n "$DIFF" ];then
		EXIT=1
		echo "Test $F fail:" 1>&2 
		echo "$DIFF" 1>&2 
	fi
done

exit $EXIT

