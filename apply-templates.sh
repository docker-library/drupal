#!/usr/bin/env bash
set -Eeuo pipefail

[ -f versions.json ] # run "versions.sh" first

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
	# https://github.com/docker-library/bashbrew/blob/master/scripts/jq-template.awk
	wget -qO "$jqt" 'https://github.com/docker-library/bashbrew/raw/9f6a35772ac863a0241f147c820354e4008edf38/scripts/jq-template.awk'
fi

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

for version; do
	export version

	rm -rf "$version/"

	phpVersions="$(jq -r '.[env.version].phpVersions | map(@sh) | join(" ")' versions.json)"
	eval "phpVersions=( $phpVersions )"
	variants="$(jq -r '.[env.version].variants | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	for phpVersion in "${phpVersions[@]}"; do
		export phpVersion

		for variant in "${variants[@]}"; do
			export variant

			# https://github.com/docker-library/php/blob/86b8b13760c7d7c6120fb635f6a1c84b22f33386/versions.sh#L99-L105
			if [ "$phpVersion" = '8.0' ] && [[ "$variant" = *-'bookworm' ]]; then
				continue
			elif [ "$phpVersion" != '8.0' ] &&  [[ "$variant" = *-'buster' ]]; then
				continue
			fi
			# https://github.com/docker-library/php/blob/0a68eaa2d3a269079c687e55abc960c77d3a134e/versions.sh#L94-L101
			if [[ "$variant" = *-'alpine3.16' ]] && [ "$phpVersion" != '8.0' ]; then
				continue
			fi
			if [ "$phpVersion" = '8.0' ] && [[ "$variant" = *-alpine* ]] && [[ "$variant" != *-'alpine3.16' ]]; then
				continue
			fi

			dir="$version/php$phpVersion/$variant"
			mkdir -p "$dir"

			echo "processing $dir ..."

			{
				generated_warning
				gawk -f "$jqt" Dockerfile.template
			} > "$dir/Dockerfile"
		done
	done
done
