#!/bin/bash

set -eu

p=s3://dandiarchive/zarr
#echo _ 383b7eb7-d589-40a5-86a9-1ade0b04922c/ \
aws --no-sign-request s3 ls $p/ \
	| while read _ zarr; do
	z=${zarr%*/}
	# DEBUG since we crashed
	#echo "$zarr: "
	m=$(curl --silent "https://api.dandiarchive.org/api/zarr/$z/")
	if echo "$m" | grep -q '"Not found."'; then
		echo "$zarr: not found on API server"
		continue
	fi
	name=$(echo $m | jq -r .name)
	dandiset=$(echo $m | jq -r .dandiset)

	r=$(curl --silent "https://api.dandiarchive.org/api/dandisets/$dandiset/versions/draft/assets/?path=$name&metadata=false")
	count=$(echo $r | jq -r .count)

	if [ "$count" = 0 ]; then
		echo "$zarr: has name='$name' but there is no asset at that path in $dandiset"
		continue
	elif [ "$count" != 1 ]; then
		echo "$zarr: has multiple ($count) hits among assets for name='$name' in $dandiset"
		exit 1  # must not happen
	fi

	path=$(echo $r | jq -r .results[0].path)
	asset_zarr=$(echo $r | jq -r .results[0].zarr)

       	if [ "$name" != "$path" ]; then
		echo "$zarr: has name='$name' but asset for that has path '$path' in $dandiset"
		echo $r | jq .
		break
	fi
       	
	if [ "$z" != "$asset_zarr" ]; then
		echo "$zarr: asset for the name='$name' has asset zarr '$asset_zarr' in $dandiset"
	fi
done
