const fs = require('fs').promises;
const path = require('path');
const { parse } = require('csv-parse/sync');
const { stringify } = require('csv-stringify/sync');

/**
 * Asynchronously reads and parses a CSV file.
 * @param {string} filePath - The path to the CSV file.
 * @returns {Promise<Object[]|null>} A promise that resolves to an array of objects, or null if the file does not exist.
 */
async function readCsv(filePath) {
    try {
        const content = await fs.readFile(filePath, 'utf-8');
        return parse(content, {
            columns: true,
            skip_empty_lines: true
        });
    } catch (error) {
        if (error.code === 'ENOENT') {
            console.log(`Optional file not found: ${path.basename(filePath)}. Skipping.`);
            return null; // Return null if file doesn't exist
        }
        console.error(`Error reading or parsing file: ${filePath}`, error);
        throw error; 
    }
}

/**
 * Asynchronously writes data to a CSV file.
 * @param {string} filePath - The path to write the CSV file.
 * @param {Object[]} data - The array of objects to write.
 */
async function writeCsv(filePath, data) {
    if (!data || data.length === 0) {
        console.warn(`No data to write for ${path.basename(filePath)}. The file will be empty or truncated.`);
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

/**
 * Main function to filter GTFS files based on route_type.
 * It keeps routes of type '1' (subway/metro) and their corresponding trips, shapes, and stop times.
 */
async function filterGtfs() {
   
    const gtfsDir = process.argv[2];

    if (!gtfsDir) {
        console.error("Usage: node filter-gtfs.js /path/to/your/gtfs/directory");
        process.exit(1);
    }

    console.log(`Starting GTFS filtering for directory: ${gtfsDir}`);

    const routesPath = path.join(gtfsDir, 'routes.txt');
    const tripsPath = path.join(gtfsDir, 'trips.txt');
    const stopTimesPath = path.join(gtfsDir, 'stop_times.txt');
    const shapesPath = path.join(gtfsDir, 'shapes.txt'); // Path for shapes.txt

    try {
        // 1. Filter routes.txt
        console.log("Reading and filtering routes.txt...");
        const allRoutes = await readCsv(routesPath);
        if (!allRoutes) {
            console.error("routes.txt is required but was not found. Aborting.");
            process.exit(1);
        }
        const filteredRoutes = allRoutes.filter(route => route.route_type === '1');

        if (filteredRoutes.length === 0) {
            console.warn("No routes with route_type = 1 found. All related data will be removed.");
        } else {
             console.log(`Found ${filteredRoutes.length} routes with route_type = 1.`);
        }
        const keptRouteIds = new Set(filteredRoutes.map(route => route.route_id));


        // 2. Filter trips.txt based on kept routes
        console.log("Reading and filtering trips.txt...");
        const allTrips = await readCsv(tripsPath);
        if (!allTrips) {
            console.error("trips.txt is required but was not found. Aborting.");
            process.exit(1);
        }
        const filteredTrips = allTrips.filter(trip => keptRouteIds.has(trip.route_id));

        if (filteredTrips.length === 0 && allTrips.length > 0) {
            console.warn("No trips correspond to the filtered routes. stop_times.txt and shapes.txt will be empty.");
        } else {
            console.log(`Kept ${filteredTrips.length} trips out of ${allTrips.length}.`);
        }
        const keptTripIds = new Set(filteredTrips.map(trip => trip.trip_id));
        const keptShapeIds = new Set(filteredTrips.map(trip => trip.shape_id).filter(Boolean)); // Get shape_ids from kept trips, removing empty values


        // 3. Filter shapes.txt based on kept trips (NEW)
        console.log("Reading and filtering shapes.txt...");
        const allShapes = await readCsv(shapesPath);
        let filteredShapes = [];
        if (allShapes) { // Check if shapes.txt exists and was read
            filteredShapes = allShapes.filter(shape => keptShapeIds.has(shape.shape_id));
            console.log(`Kept ${filteredShapes.length} shape points out of ${allShapes.length}.`);
        }


        // 4. Filter stop_times.txt based on kept trips
        console.log("Reading and filtering stop_times.txt...");
        const allStopTimes = await readCsv(stopTimesPath);
        if (!allStopTimes) {
            console.error("stop_times.txt is required but was not found. Aborting.");
            process.exit(1);
        }
        const filteredStopTimes = allStopTimes.filter(stopTime => keptTripIds.has(stopTime.trip_id));
        console.log(`Kept ${filteredStopTimes.length} stop times out of ${allStopTimes.length}.`);

        
        // 5. Write all filtered files
        console.log("\nWriting filtered files...");
        await writeCsv(routesPath, filteredRoutes);
        await writeCsv(tripsPath, filteredTrips);
        if (allShapes) { // Only write shapes.txt if it was present initially
             await writeCsv(shapesPath, filteredShapes);
        }
        await writeCsv(stopTimesPath, filteredStopTimes);

        console.log("\nGTFS filtering completed successfully!");

    } catch (error) {
        console.error("\nAn error occurred during the GTFS filtering process:", error.message);
        process.exit(1);
    }
}

// Execute the main function.
filterGtfs();
