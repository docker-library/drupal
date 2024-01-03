#!/bin/bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

yq='./.yq'
# https://github.com/mikefarah/yq/releases
# TODO detect host architecture
yqUrl='https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_amd64'
yqSha256='0d6aaf1cf44a8d18fbc7ed0ef14f735a8df8d2e314c4cc0f0242d35c0a440c95'
if command -v xq-python &> /dev/null; then
	# if we have the Python-based "yq" installed, it also comes with "xq-python" (at least, from Debian), which does meet our needs here
	yq='xq-python'
else
	if command -v yq &> /dev/null && yq --help |& grep -F -- ' --input-format' | grep -qF xml; then
		# if we have a "yq" on the host, make sure it's the Go-based "yq" (not the Python-based one, handled above)
		yq='yq'
	elif [ ! -x "$yq" ] || ! sha256sum <<<"$yqSha256 *$yq" --quiet --strict --check; then
		wget -qO "$yq.new" "$yqUrl"
		sha256sum <<<"$yqSha256 *$yq.new" --quiet --strict --check
		chmod +x "$yq.new"
		"$yq.new" --version
		mv "$yq.new" "$yq"
	fi
	yq+=' --input-format xml'
fi

releases="$(
	wget -qO- 'https://updates.drupal.org/release-history/drupal/current' 'https://updates.drupal.org/release-history/drupal/7.x' \
		| $yq -r '@json' \
		| jq -c '
			# https://stackoverflow.com/a/75770668/433558
			def semver:
				sub("[+].*$"; "")
				| capture("^(?<v>[^-]+)(?:-(?<p>.*))?$") | [.v, .p // empty]
				| map(split(".") | map(tonumber? // .))
				| .[1] |= (. // {})
			;
			[ .project | if type == "array" then .[] else . end ] # normalize to an array, even if we only fetch one URL (not both "current" and "7.x" -- otherwise this can just be ".project" and we can drop the ".[]"s below)
			| (
				[
					.[]
					| .supported_branches? // empty,
						.supported_majors? // empty
					| split(",")
				]
				| flatten
				| map(rtrimstr("."))
			) as $versions
			| reduce (
				.[].releases.release[]
				# skip "dev" releases entirely (download artifacts are too unstable / change too often)
				| select(
					.status == "published"
					and (
						.version
						| endswith("-dev")
						| not
					)
				)
				# add a key for the appropriate "X.Y" or "X.Y-rc" value
				| .folder = (.version | ([ split("[.-]"; "") | if .[0] == "7" then .[0] else .[0,1] end ] | join(".")) + if index("-") then "-rc" else "" end)
				# filter to *just* versions that the upstream file claims are actually supported ("supported_branches")
				| select((.folder | rtrimstr("-rc")) as $ver | $versions | index($ver) | not|not)
			) as $rel ({}; .[$rel.version] = $rel)
			| to_entries
			# put all releases in sorted order
			| sort_by(.value.version | semver)
			| reverse
			# ... so we can remove all but the most recent (pre)?release for each branch / folder
			| unique_by(
				.value.folder
				| rtrimstr("-rc")
				| split("[.-]"; "")
				| map(tonumber? // .)
			)
			| reverse
			| map(.key = .value.folder)
			| from_entries
		'
)"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	# if no versions are specified, assume the "canonical" list of supported versions
	versions="$(jq <<<"$releases" -r '[ .[].folder | @sh ] | join(" ")')"
	eval "versions=( $versions )"
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	export version rcVersion="${version%-rc}"

	doc="$(jq <<<"$releases" -c '.[env.version] // empty')"
	if [ -z "$doc" ]; then
		echo >&2 "warning: skipping/removing '$version' (does not exist or is not supported upstream)"
		json="$(jq <<<"$json" -c '.[env.version] = null')"
		continue
	fi

	doc="$(jq <<<"$doc" -c '
		first(.files.file[] | select(.archive_type == "tar.gz")) as $file
		| {
			version: .version,
			url: $file.url,
			md5: $file.md5,
			date: (.date | tonumber),
			notes: .release_link,

			# TODO adjust this in a way that is easier to manage over time (semi-automatic variant combinations, for example, based on availability/supported status of upstream PHP images)
			phpVersions: (
				# https://www.drupal.org/docs/system-requirements/php-requirements
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
			variants: [
				"bookworm",
				"bullseye",
				"alpine3.19",
				"alpine3.18",
				empty
				| if startswith("alpine") then empty else
						"apache-" + .
					end,
					"fpm-" + .
			],
		}
	')"
	fullVersion="$(jq <<<"$doc" -r '.version')"
	[ -n "$fullVersion" ] # sanity check

	if [ "$rcVersion" != "$version" ] && gaFullVersion="$(jq <<<"$json" -er '.[env.rcVersion] | if . then .version else empty end')"; then
		# Drupal pre-releases appear to be only for .0, so if our pre-release now has a relevant GA, it should go away 👀
		# just in case, we'll also do a version comparison to make sure we don't have a pre-release that's newer than the relevant GA
		latestVersion="$({ echo "$fullVersion"; echo "$gaFullVersion"; } | sort -V | tail -1)"
		if [[ "$fullVersion" == "$gaFullVersion"* ]] || [ "$latestVersion" = "$gaFullVersion" ]; then
			# "x.y.z-rc1" == x.y.z*
			json="$(jq <<<"$json" -c 'del(.[env.version])')"
			continue
		fi
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
	if [ "$rcVersion" != '7' ] && [ -z "$composerVersion" ]; then
		echo >&2 "error: cannot find composer version for '$version' ('$fullVersion')"
		exit 1
	fi
	if [ -n "$composerVersion" ]; then
		export composerVersion
		doc="$(jq <<<"$doc" -c '.composer = { version: env.composerVersion }')"
	fi

	echo "$version: $fullVersion${composerVersion:+ (composer $composerVersion)}"

	json="$(
		jq <<<"$json" -c --argjson doc "$doc" '
			.[env.version] = $doc
		'
	)"

	# make sure pre-release versions have a placeholder for GA
	if [ "$version" != "$rcVersion" ]; then
		json="$(jq <<<"$json" -c '.[env.rcVersion] //= null')"
	fi
done

jq <<<"$json" '
	to_entries
	| sort_by(.key | split("[.-]"; "") | map(tonumber? // .))
	| reverse
	| from_entries
' > versions.json
