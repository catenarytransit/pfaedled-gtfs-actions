#!/bin/bash
set -e

# Download MD5 hash of the raw GTFS file
wget -q -O raw_gtfs.md5 https://github.com/catenarytransit/pfaedled-gtfs-actions/releases/download/latest/fahrplaene_gesamtdeutschland_gtfs_raw.zip.md5
RAW_MD5=$(cat raw_gtfs.md5)

# Download MD5 hash of the previously processed GTFS file, if it exists
if wget -q -O processed_gtfs.md5 https://github.com/catenarytransit/pfaedled-gtfs-actions/releases/download/latest/de_gtfs_pfaedle.zip.md5; then
    PROCESSED_MD5=$(cat processed_gtfs.md5)
else
    PROCESSED_MD5=""
fi

if [ "$RAW_MD5" == "$PROCESSED_MD5" ]; then
    echo "MD5 hashes match. No update needed for Deutschland GTFS."
    exit 0
fi

wget https://github.com/catenarytransit/osm-filter/releases/download/latest/railonly-europe-latest.osm.pbf -O railonly-europe-latest.osm.pbf

wget https://github.com/catenarytransit/osm-filter/releases/download/latest/pfaedle-filtered-germany-latest.osm.pbf -O pfaedle-filtered-germany-latest.osm.pbf

osmconvert railonly-europe-latest.osm.pbf -o=railonly-europe-latest.osm
osmconvert pfaedle-filtered-germany-latest.osm.pbf -o=germany-latest.osm
wget https://github.com/catenarytransit/pfaedled-gtfs-actions/releases/download/latest/fahrplaene_gesamtdeutschland_gtfs_raw.zip -O de_gtfs.zip

# -f flag ensures this doesn't error if the directory doesn't exist
rm -rf de_gtfs

unzip de_gtfs.zip -d de_gtfs

./gtfs-de-agency-remover/target/release/gtfs-de-agency-remover de_gtfs

sed -i 's/\"\",\"Europe\/Berlin\"/\"https:\/\/catenarymaps.org\",\"Europe\/Berlin\"/g' de_gtfs/agency.txt

# -f flag ensures this doesn't error if the directory doesn't exist
rm -rf de_gtfs_tidy/

gtfstidy --fix --drop-shapes -o de_gtfs_tidy/ de_gtfs/

mv de_gtfs_tidy/* de_gtfs/

pfaedle -x germany-latest.osm de_gtfs -F --inplace --mots bus,trolley-bus,trolleybus,trolley,ferry --write-colors  --drop-shapes true

pfaedle -x railonly-europe-latest.osm de_gtfs -F --inplace --mots rail,metro,subway,tram,streetcar --write-colors --drop-shapes true

##gtfstidy --fix -s -o de_gtfs_tidy/ de_gtfs/
##mv de_gtfs_tidy/* de_gtfs/
./shape-squash/target/release/shape-squash de_gtfs/shapes.txt

# Added -f flag here to prevent script exit if file does not exist
rm -f de_gtfs_pfaedle.zip
zip de_gtfs_pfaedle.zip de_gtfs_tidy/*

gh release upload latest de_gtfs_pfaedle.zip --clobber -R https://github.com/catenarytransit/pfaedled-gtfs-actions/

echo "Uploading new MD5 hash for processed file."
mv raw_gtfs.md5 de_gtfs_pfaedle.zip.md5
gh release upload latest de_gtfs_pfaedle.zip.md5 --clobber -R https://github.com/catenarytransit/pfaedled-gtfs-actions/
