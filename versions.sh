#!/bin/bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	export version

	doc='{}'

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
			# there is no https://updates.drupal.org/release-history/drupal/9.x (or 9.0.x)
			# (07/2020) current could also be used for 8.9, 9.0, 9.1
			drupalRelease='current'
			;;
	esac

	fullVersion="$(
		wget -qO- "https://updates.drupal.org/release-history/drupal/$drupalRelease" \
			| awk -v RS='[<>]' '
					$1 == "release" { release = 1; version = ""; mdhash = ""; tag = ""; next }
					release && $1 ~ /^version|mdhash$/ { tag = $1; next }
					release && tag == "version" { version = $1 }
					release && tag == "mdhash" { mdhash = $1 }
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
	if [ -n "$md5" ]; then
		export md5
		doc="$(jq <<<"$doc" -c '.md5 = env.md5')"
	fi

	composerVersion="$(
		wget -qO- "https://github.com/drupal/drupal/raw/$fullVersion/composer.lock" \
			| jq -r '
				(.packages, ."packages-dev")[]
				| select(.name == "composer/composer")
				| .version
				| split(".")[0:2] | join(".")
			' \
			|| :
	)"
	if [ "$version" != '7' ] && [ -z "$composerVersion" ]; then
		echo >&2 "error: cannot find composer version for '$version' ('$fullVersion')"
		exit 1
	fi
	if [ -n "$composerVersion" ]; then
		export composerVersion
		doc="$(jq <<<"$doc" -c '.composer = { version: env.composerVersion }')"
	fi

	echo "$version: $fullVersion${composerVersion:+ (composer $composerVersion)}"

	export fullVersion
	json="$(
		jq <<<"$json" -c --argjson doc "$doc" '
			.[env.version] = {
				version: env.fullVersion,
				variants: [ "apache-buster", "fpm-buster", "fpm-alpine3.12" ],
				phpVersions: (
					if [ "7", "8.9", "9.0"] | index(env.version) then
						[ "7.4" ]
					else
						[ "8.0", "7.4" ]
					end
				),
			} + $doc
		'
	)"
done

jq <<<"$json" -S . > versions.json
