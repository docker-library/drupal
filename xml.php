<?php

$doc = new SimpleXMLElement(file_get_contents('https://updates.drupal.org/release-history/drupal/current'));
$versions = getSupportedVersions($doc);

$doc7 = new SimpleXMLElement(file_get_contents('https://updates.drupal.org/release-history/drupal/7.x'));
$versions7 = ['7.'];
$informations = array_merge(getVersionInformations($doc7, $versions7), getVersionInformations($doc, $versions));

foreach ($informations as $information) {
    print "$information\n";
}


function getSupportedVersions(SimpleXMLElement $doc)
{
    return explode(',', $doc->supported_branches[0]);
    return array_map(function ($value) {
        return substr($value, 0, -1);
    }, $versions);
}

function getVersionInformations(SimpleXMLElement $doc, $versions) {
    $informations = [];
    foreach($doc->releases[0] as $release)
    {
        $specific_version = (string)$release->version;
        $founded_versions = array_filter($versions, 
        function ($version) use ($specific_version) {
            return strpos($specific_version, $version) === 0;
        });
        if (sizeof($founded_versions) !== 1) {
            continue;
        }
        $founded_version = array_shift($founded_versions);
        if (array_key_exists($founded_version, $informations)) {
            continue;
        }
        $file = [];
        foreach($release->files->file as $archive) {
            if ((string)$archive->archive_type === 'tar.gz') {
                $file['url'] = (string)$archive->url;
                $file['md5'] = (string)$archive->md5;
            }
        }
        if (sizeof($file) === 0) {
            continue;
        }
        $informations[$founded_version] = 
            substr($founded_version, 0, -1) . ' ' .
            $specific_version . ' ' . 
            $file['url'] . ' ' .
            $file['md5'];
    }    
    return $informations;
}
