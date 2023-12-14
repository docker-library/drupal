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
		7)
			# e.g. 7.x
			drupalRelease="${rcVersion%%.*}.x"
			;;
		*)
			# there is no https://updates.drupal.org/release-history/drupal/10.x
			# (12/2023) current can be used for 10.x: "<supported_branches>10.0.,10.1.,10.2.</supported_branches>"
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
				| split(".")[0:1] | join(".")
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
			.[env.version] = (
				{
					version: env.fullVersion,
					phpVersions: (
						[
							# https://www.drupal.org/project/drupal/releases/10.2.0-rc1#php-deps
							# Drupal now supports PHP 8.3 and recommends at least PHP 8.2.
							if [ "7", "10.0", "10.1" ] | index(env.version) then empty else "8.3" end,
							"8.2",
							if [ "7", "10.0", "10.1" ] | index(env.version) then "8.1" else empty end,
							# https://www.drupal.org/docs/system-requirements/php-requirements
							# https://www.drupal.org/docs/7/system-requirements/php-requirements
							empty
						]
					),
				} + $doc
				| .variants = [
					"bookworm",
					"bullseye",
					"alpine3.19",
					"alpine3.18",
					empty
					| if startswith("alpine") then empty else "apache-" + . end,
						"fpm-" + .
				]
			)
		'
	)"
done

jq <<<"$json" -S . > versions.json
