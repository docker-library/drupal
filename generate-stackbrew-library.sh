#!/usr/bin/env bash
set -Eeuo pipefail

declare -A aliases=(
	[8.9]='8'
	[9.1]='9 latest'
	[9.2-rc]='rc'
)

defaultDebianSuite='buster'
declare -A debianSuites=(
	#[9.0]='buster'
)
defaultAlpineVersion='3.12'

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )

# sort version numbers with highest first
IFS=$'\n'; versions=( $(echo "${versions[*]}" | sort -rV) ); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						if ($i ~ /^--from=/) {
							next
						}
						print $i
					}
				}
			')
	)
}

gawkParents='
	{ cmd = toupper($1) }
	cmd == "FROM" {
		print $2
		next
	}
	cmd == "COPY" {
		for (i = 2; i < NF; i++) {
			if ($i ~ /^--from=/) {
				gsub(/^--from=/, "", $i)
				print $i
				next
			}
		}
	}
'

getArches() {
	local repo="$1"; shift

	local parentRepoToArchesStr
	parentRepoToArchesStr="$(
		find -name 'Dockerfile' -exec gawk "$gawkParents" '{}' + \
			| sort -u \
			| gawk -v officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/' '
				$1 !~ /^('"$repo"'|scratch|.*\/.*)(:|$)/ {
					printf "%s%s\n", officialImagesUrl, $1
				}
			' \
			| xargs -r bashbrew cat --format '["{{ .RepoName }}:{{ .TagName }}"]="{{ join " " .TagEntry.Architectures }}"'
	)"
	eval "declare -g -A parentRepoToArches=( $parentRepoToArchesStr )"
}
getArches 'drupal'

cat <<-EOH
# this file is generated via https://github.com/docker-library/drupal/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/drupal.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version in "${versions[@]}"; do
	rcVersion="${version%-rc}"
	for variant in {apache,fpm}-buster fpm-alpine3.12; do
		[ -e "$version/$variant/Dockerfile" ] || continue
		commit="$(dirCommit "$version/$variant")"

		fullVersion="$(git show "$commit":"$version/$variant/Dockerfile" | awk '$1 == "ENV" && $2 == "DRUPAL_VERSION" { print $3; exit }')"

		versionAliases=()
		while [ "$fullVersion" != "$rcVersion" -a "${fullVersion%[.]*}" != "$fullVersion" ]; do
			versionAliases+=( $fullVersion )
			fullVersion="${fullVersion%[.]*}"
		done
		versionAliases+=(
			$version
			${aliases[$version]:-}
		)

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		debianSuite="${debianSuites[$version]:-$defaultDebianSuite}"
		case "$variant" in
			*-"$debianSuite") # "-apache-buster", -> "-apache"
				variantAliases+=( "${versionAliases[@]/%/-${variant%-$debianSuite}}" )
				;;
			fpm-"alpine${defaultAlpineVersion}")
				variantAliases+=( "${versionAliases[@]/%/-fpm-alpine}" )
				;;
		esac
		variantAliases=( "${variantAliases[@]//latest-/}" )

		variantParents="$(gawk "$gawkParents" "$version/$variant/Dockerfile")"
		variantArches=
		for variantParent in $variantParents; do
			parentArches="${parentRepoToArches[$variantParent]:-}"
			if [ -z "$parentArches" ]; then
				continue
			elif [ -z "$variantArches" ]; then
				variantArches="$parentArches"
			else
				variantArches="$(
					comm -12 \
						<(xargs -n1 <<<"$variantArches" | sort -u) \
						<(xargs -n1 <<<"$parentArches" | sort -u)
				)"
			fi
		done

		if [[ "$variant" = apache-* ]]; then
			variantAliases+=( "${versionAliases[@]}" )
		fi

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: $(join ', ' $variantArches)
			GitCommit: $commit
			Directory: $version/$variant
		EOE
	done
done
