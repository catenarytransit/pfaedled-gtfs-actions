
rm -rf de_gtfs

unzip de_gtfs.zip -d de_gtfs

./gtfs-de-agency-remover/target/release/gtfs-de-agency-remover de_gtfs

sed -i 's/\"\",\"Europe\/Berlin\"/\"https:\/\/catenarymaps.org\",\"Europe\/Berlin\"/g' de_gtfs/agency.txt

rm -rf de_gtfs_tidy/

gtfstidy --fix -s -o de_gtfs_tidy/ de_gtfs/

mv de_gtfs_tidy/* de_gtfs/

pfaedle -x germany-latest.osm de_gtfs -F --inplace --mots bus,trolley-bus,trolleybus,trolley,ferry --write-colors  --drop-shapes true

pfaedle -x railonly-europe-latest.osm de_gtfs -F --inplace --mots rail,metro,subway,tram,streetcar --write-colors --drop-shapes true

./shape-squash/target/release/shape-squash de_gtfs/shapes.txt
#gtfstidy --fix -s de_gtfs/

rm de_gtfs_pfaedle.zip
zip de_gtfs_pfaedle.zip de_gtfs/*

gh release upload latest de_gtfs_pfaedle.zip --clobber -R https://github.com/catenarytransit/pfaedled-gtfs-actions/
