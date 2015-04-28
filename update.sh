#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

curl -fSL 'http://ftp.drupal.org/files/projects/' -o ftp
curl -fSL 'https://www.drupal.org/node/3060/release' -o release

for version in "${versions[@]}"; do
	fullVersion="$(awk -F '[<> ="]+' '$2 == "a" && $3 == "href" && $4 ~ /^drupal-'"$version"'\..*\.tar\.gz$/ { gsub(/^drupal-|\.tar\.gz$/, "", $4); print $4 }' ftp | grep -vE -- '-dev$' | sort -V | tail -1)"
	md5="$(grep -A6 -m1 '>drupal-'"$fullVersion"'.tar.gz<' release | grep -A1 -m1 '"md5 hash"' | tail -1 | awk '{ print $1 }')"
	
	(
		set -x
		sed -ri '
			s/^(ENV DRUPAL_VERSION) .*/\1 '"$fullVersion"'/;
			s/^(ENV DRUPAL_MD5) .*/\1 '"$md5"'/;
		' "$version/Dockerfile"
	)
done

rm -f ftp release
