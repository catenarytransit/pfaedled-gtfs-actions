
const fs = require('fs').promises;
const path = require('path');
const { parse } = require('csv-parse/sync');
const { stringify } = require('csv-stringify/sync');

async function readCsv(filePath) {
    try {
        const content = await fs.readFile(filePath);
        return parse(content, {
            columns: true,
            skip_empty_lines: true
        });
    } catch (error) {
        console.error(`Error reading or parsing file: ${filePath}`, error);
        throw error; 
    }
}

async function writeCsv(filePath, data) {
    if (!data || data.length === 0) {
        console.warn(`No data to write for ${path.basename(filePath)}. The file will be empty.`);
        await fs.writeFile(filePath, '');
        return;
    }
    try {
        const header = Object.keys(data[0]);
        const csvString = stringify(data, { header: true, columns: header });
        await fs.writeFile(filePath, csvString);
    } catch (error) {
        console.error(`Error writing to file: ${filePath}`, error);
        throw error;
    }
}


async function filterGtfs() {
   
    const gtfsDir = process.argv[2];

    if (!gtfsDir) {
        console.error("node filter-gtfs.js /path/to/your/gtfs/directory");
        process.exit(1);
    }

    console.log(`Starting GTFS filtering for directory: ${gtfsDir}`);

    const routesPath = path.join(gtfsDir, 'routes.txt');
    const tripsPath = path.join(gtfsDir, 'trips.txt');
    const stopTimesPath = path.join(gtfsDir, 'stop_times.txt');

    try {
        // routes.txt filtering
        console.log("Reading and filtering routes.txt");
        const allRoutes = await readCsv(routesPath);
        const filteredRoutes = allRoutes.filter(route => route.route_type === '1');

        if (filteredRoutes.length === 0) {
            console.warn("No routes with route_type = 1 found. All routes, trips, and stop_times will be removed.");
        } else {
             console.log(`Found ${filteredRoutes.length} routes with route_type = 1.`);
        }
        const keptRouteIds = new Set(filteredRoutes.map(route => route.route_id));


        // trips.txt filtering
        console.log("Reading and filtering trips.txt");
        const allTrips = await readCsv(tripsPath);
        const filteredTrips = allTrips.filter(trip => keptRouteIds.has(trip.route_id));

        if (filteredTrips.length === 0 && allTrips.length > 0) {
            console.warn("No trips correspond to the filtered routes. stop_times.txt will be empty.");
        } else {
            console.log(`Kept ${filteredTrips.length} trips out of ${allTrips.length}.`);
        }
        const keptTripIds = new Set(filteredTrips.map(trip => trip.trip_id));


        // stop_times.txt filter
        console.log("Reading and filtering stop_times.txt");
        const allStopTimes = await readCsv(stopTimesPath);
        const filteredStopTimes = allStopTimes.filter(stopTime => keptTripIds.has(stopTime.trip_id));
        console.log(`Kept ${filteredStopTimes.length} stop times out of ${allStopTimes.length}.`);


        await writeCsv(routesPath, filteredRoutes);

        await writeCsv(tripsPath, filteredTrips);

        await writeCsv(stopTimesPath, filteredStopTimes);

        console.log("\nGTFS filtering completed successfully!");

    } catch (error) {
        console.error("\nAn error occurred during the GTFS filtering process:", error.message);
        process.exit(1);
    }
}

// Execute the main function.
filterGtfs();
