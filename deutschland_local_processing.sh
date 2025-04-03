wget https://github.com/catenarytransit/osm-filter/releases/download/latest/railonly-europe-latest.osm.pbf -O railonly-europe-latest.osm.pbf

wget https://github.com/catenarytransit/osm-filter/releases/download/latest/pfaedle-filtered-germany-latest.osm.pbf -O pfaedle-filtered-germany-latest.osm.pbf

osmconvert railonly-europe-latest.osm.pbf -o=railonly-europe-latest.osm
osmconvert pfaedle-filtered-germany-latest.osm.pbf -o=germany-latest.osm
wget https://github.com/catenarytransit/pfaedled-gtfs-actions/releases/download/latest/fahrplaene_gesamtdeutschland_gtfs_raw.zip -O de_gtfs.zip

rm -rf de_gtfs

unzip de_gtfs.zip -d de_gtfs

./gtfs-de-agency-remover/target/release/gtfs-de-agency-remover de_gtfs

sed -i 's/\"\",\"Europe\/Berlin\"/\"https:\/\/catenarymaps.org\",\"Europe\/Berlin\"/g' de_gtfs/agency.txt

rm -rf de_gtfs_tidy/

gtfstidy --fix --drop-shapes -o de_gtfs_tidy/ de_gtfs/

mv de_gtfs_tidy/* de_gtfs/

pfaedle -x germany-latest.osm de_gtfs -F --inplace --mots bus,trolley-bus,trolleybus,trolley,ferry --write-colors  --drop-shapes true

pfaedle -x railonly-europe-latest.osm de_gtfs -F --inplace --mots rail,metro,subway,tram,streetcar --write-colors --drop-shapes true

gtfstidy --fix -s -o de_gtfs_tidy/ de_gtfs/
./shape-squash/target/release/shape-squash de_gtfs/shapes.txt

rm de_gtfs_pfaedle.zip
zip de_gtfs_pfaedle.zip de_gtfs_tidy/*

gh release upload latest de_gtfs_pfaedle.zip --clobber -R https://github.com/catenarytransit/pfaedled-gtfs-actions/

echo "doing nvbw.de"

wget https://www.nvbw.de/fileadmin/user_upload/service/open_data/fahrplandaten_ohne_liniennetz/bwsbahnubahn.zip -O bwsbahnubahn.zip

echo "unzip nvbw"
rm -r nvbw
unzip bwsbahnubahn.zip -d nvbw

gtfstidy --fix -s -o nvbw_tidy/ de_gtfs/
mv nvbw_tidy/* nvbw/

pfaedle -x germany-latest.osm nvbw -F --inplace --mots bus,trolley-bus,trolleybus,trolley,ferry --write-colors
pfaedle -x railonly-europe-latest.osm nvbw -F --inplace --mots rail,metro,subway,tram,streetcar --write-colors
#gtfstidy --fix -s nvbw/
echo "zipping nvbw result"

zip nvbw_pfaedle.zip nvbw/*

gh release upload latest nvbw_pfaedle.zip --clobber -R https://github.com/catenarytransit/pfaedled-gtfs-actions/
