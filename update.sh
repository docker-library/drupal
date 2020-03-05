#!/bin/bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

# https://www.drupal.org/docs/8/system-requirements/php-requirements#php_required
defaultPhpVersion='7.4'
declare -A phpVersions=(
	# https://www.drupal.org/docs/7/system-requirements/php-requirements#php_required
	#[7]='7.2'
)

for version in "${versions[@]}"; do
	rcGrepV='-v'
	rcVersion="${version%-rc}"
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi

	case "$rcVersion" in
		7|8.*)
			# e.g. 7.x or 8.x
			drupalRelease="${rcVersion%%.*}.x"
			;;
		9.*)
			# there is no "9.x" or `9.0.x` endpoint
			# (07/2020) current could also be used for 8.7, 8.8, 8.9, 9.0, 9.1
			drupalRelease='current'
			;;
	esac

	fullVersion=
	fullVersion="$(
		wget -qO- "https://updates.drupal.org/release-history/drupal/$drupalRelease" \
			| awk -v RS='[<>]' '
					$1 == "release" { release = 1; version = ""; mdhash = ""; tag = ""; file = ""; next }
					release && $1 ~ /^version|mdhash$/ { tag = $1; next }
					release && tag == "version" { version = $1 }
					release && tag == "mdhash" { mdhash = $1 }
					release && !mdhash && $1 ~ /^file$/ { file = 1; isTar = ""; next }
					release && file && $1 ~ /^url|md5$/ { tag = $1; next }
					release && file && tag == "url" && $1 ~ /tar.gz$/ { isTar = 1; next }
					release && file && isTar && tag == "md5" { mdhash = $1 }
					release && file && $1 == "/file" { file = ""; isTar = "" }
					release { tag = "" }
					release && $1 == "/release" { release = 0; print version, mdhash }
				' \
			| grep -E "^${rcVersion}[. -]" \
			| grep $rcGrepV -E -- '-rc|-beta|-alpha|-dev' \
			| head -1
	)"
	if [ -z "$fullVersion" ]; then
		echo >&2 "error: cannot find release for $version"
		exit 1
	fi
	md5="${fullVersion##* }"
	fullVersion="${fullVersion% $md5}"

	echo "$version: $fullVersion ($md5)"

	for variant in fpm-alpine fpm apache; do
		dist='debian'
		if [[ "$variant" = *alpine ]]; then
			dist='alpine'
		fi

		sed -r \
			-e 's/%%PHP_VERSION%%/'"${phpVersions[$version]:-$defaultPhpVersion}"'/' \
			-e 's/%%VARIANT%%/'"$variant"'/' \
			-e 's/%%VERSION%%/'"$fullVersion"'/' \
			-e 's/%%MD5%%/'"$md5"'/' \
		"./Dockerfile-$dist.template" > "$version/$variant/Dockerfile"
	done
done
