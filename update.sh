#!/bin/bash
set -eo pipefail

defaultPhpVersion='7.4'
declare -A phpVersions=(
	# https://www.drupal.org/docs/7/system-requirements/php-requirements#php_required
	#[7]='7.2'
)
docker run -ti -v $PWD/xml.php:/xml.php php:cli php /xml.php > /tmp/versions
IFS=" "
while read version fullVersion url md5
do
	md5=${md5//$'\r'}
	echo "$version: $fullVersion ($md5)"

	for variant in fpm-alpine fpm apache; do
		dist='debian'
		if [[ "$variant" = *alpine ]]; then
			dist='alpine'
		fi

		mkdir -p $version/$variant
		sed -r \
			-e 's/%%PHP_VERSION%%/'"${phpVersions[$version]:-$defaultPhpVersion}"'/' \
			-e 's/%%VARIANT%%/'"$variant"'/' \
			-e 's/%%VERSION%%/'"$fullVersion"'/' \
			-e 's!%%URL%%!'"$url"'!' \
			-e 's/%%MD5%%/'"$md5"'/' \
		"./Dockerfile-$dist.template" > "$version/$variant/Dockerfile"
	done
done < /tmp/versions

