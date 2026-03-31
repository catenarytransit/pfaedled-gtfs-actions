package com.catenarytransit.trenitalia;

import org.entur.netex.gtfs.export.DefaultGtfsExporter;
import org.entur.netex.gtfs.export.GtfsExporter;
import org.entur.netex.gtfs.export.stop.DefaultStopAreaRepository;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

public class Main {
    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("Usage: java -jar trenitalia-converter.jar <input-zip> <output-gtfs-zip>");
            System.exit(1);
        }

        String inputFile = args[0];
        String outputFile = args[1];
        String codespace = "Trenitalia";

        System.out.println("Processing NeTEx file: " + inputFile);

        try (InputStream stopsAndQuaysDataset = new FileInputStream(inputFile)) {
            DefaultStopAreaRepository defaultStopAreaRepository = new DefaultStopAreaRepository();
            defaultStopAreaRepository.loadStopAreas(stopsAndQuaysDataset);
            
            System.out.println("Loaded Stop Areas. Converting Timetables...");

            try (InputStream netexTimetableDataset = new FileInputStream(inputFile)) {
                GtfsExporter gtfsExport = new DefaultGtfsExporter(codespace, defaultStopAreaRepository);
                
                try (InputStream exportedGtfs = gtfsExport.convertTimetablesToGtfs(netexTimetableDataset);
                     OutputStream out = new FileOutputStream(outputFile)) {
                    
                    byte[] buffer = new byte[8192];
                    int bytesRead;
                    while ((bytesRead = exportedGtfs.read(buffer)) != -1) {
                        out.write(buffer, 0, bytesRead);
                    }
                    
                    System.out.println("Catenary GTFS exported successfully to " + outputFile);
                }
            }
        }
    }
}
