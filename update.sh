#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

curl -fSL 'https://www.drupal.org/node/3060/release' -o release

travisEnv=
for version in "${versions[@]}"; do
	fullVersion="$(grep -E '>drupal-'"$version"'\.[0-9a-z.-]+\.tar\.gz<' release | sed -r 's!.*<a[^>]+>drupal-([^<]+)\.tar\.gz</a>.*!\1!' | head -1)"
	md5="$(grep -A6 -m1 '>drupal-'"$fullVersion"'.tar.gz<' release | grep -A1 -m1 '"md5 hash"' | tail -1 | awk '{ print $1 }')"
	
	(
		set -x
		sed -ri '
			s/^(ENV DRUPAL_VERSION) .*/\1 '"$fullVersion"'/;
			s/^(ENV DRUPAL_MD5) .*/\1 '"$md5"'/;
		' "$version/Dockerfile"
	)
	
	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml

rm -f release
