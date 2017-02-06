#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

curl -fsSL 'https://www.drupal.org/node/3060/release' -o release
trap 'rm -f release' EXIT

travisEnv=
for version in "${versions[@]}"; do
	rcGrepV='-v'
	rcVersion="${version%-rc}"
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi
	fullVersion="$(
		grep -E '>drupal-'"$rcVersion"'\.[0-9a-z.-]+\.tar\.gz<' release \
			| sed -r 's!.*<a[^>]+>drupal-([^<]+)\.tar\.gz</a>.*!\1!' \
			| grep $rcGrepV -E -- '-rc|-beta|-alpha|-dev' \
			| head -1
	)"
	if [ -z "$fullVersion" ]; then
		echo >&2 "error: cannot find release for $version"
		exit 1
	fi
	md5="$(grep -A6 -m1 '>drupal-'"$fullVersion"'.tar.gz<' release | grep -A1 -m1 '"md5 hash"' | tail -1 | awk '{ print $1 }')"
	
	(
		set -x
		sed -ri '
			s/^(ENV DRUPAL_VERSION) .*/\1 '"$fullVersion"'/;
			s/^(ENV DRUPAL_MD5) .*/\1 '"$md5"'/;
		' "$version"/*/Dockerfile
	)
	
	for variant in fpm apache; do
		travisEnv='\n  - VERSION='"$version"' VARIANT='"$variant$travisEnv"
	done
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
