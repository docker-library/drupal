#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

declare -A phpVersions=(
	[7]='7.0'
	[8.4]='7.1'
	[8.5-rc]='7.2'
)

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


	for variant in fpm-alpine fpm apache; do
		dist='debian'
		if [[ "$variant" = *alpine ]]; then
			dist='alpine'
		fi

		(
			set -x
			sed -r \
				-e 's/%%PHP_VERSION%%/'"${phpVersions[$version]}"'/' \
				-e 's/%%VARIANT%%/'"$variant"'/' \
				-e 's/%%VERSION%%/'"$fullVersion"'/' \
				-e 's/%%MD5%%/'"$md5"'/' \
			"./Dockerfile-$dist.template" > "$version/$variant/Dockerfile"
		)

		travisEnv='\n  - VERSION='"$version"' VARIANT='"$variant$travisEnv"
	done
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
