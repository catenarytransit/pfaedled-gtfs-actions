#sudo apt install osmium-tool osmctools unzip zip -y
wget https://github.com/catenarytransit/osm-filter/releases/download/latest/railonly-europe-latest.osm.pbf -O railonly-europe-latest.osm.pbf

wget https://github.com/catenarytransit/osm-filter/releases/download/latest/pfaedle-filtered-germany-latest.osm.pbf -O pfaedle-filtered-germany-latest.osm.pbf

osmconvert railonly-europe-latest.osm.pbf -o=railonly-europe-latest.osm
osmconvert pfaedle-filtered-germany-latest.osm.pbf -o=germany-latest.osm
wget https://github.com/catenarytransit/gtfs-delfi-copy/releases/download/latest/fahrplaene_gesamtdeutschland_gtfs.zip -O de_gtfs.zip

rm -rf de_gtfs

unzip de_gtfs.zip -d de_gtfs

./gtfs-de-agency-remover/target/release/gtfs-de-agency-remover de_gtfs
      
sed -i 's/\"\",\"Europe\/Berlin\"/\"https:\/\/catenarymaps.org\",\"Europe\/Berlin\"/g' de_gtfs/agency.txt
        
pfaedle -x germany-latest.osm de_gtfs -F --inplace --mots bus,trolley-bus,trolleybus,trolley,ferry --write-colors --drop-shapes true

pfaedle -x railonly-europe-latest.osm de_gtfs -F --inplace --mots rail,metro,subway,tram,streetcar --write-colors --drop-shapes true

zip -r de_gtfs_pfaedle.zip de_gtfs

gh release upload latest de_gtfs_pfaedle.zip --clobber -R https://github.com/catenarytransit/pfaedled-gtfs-actions/
