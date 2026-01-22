import csv
import os
import sys

# Allow the directory to be passed as an argument, default to 'gold_runner_gtfs'
gtfs_dir = sys.argv[1] if len(sys.argv) > 1 else 'gold_runner_gtfs'
file_path = os.path.join(gtfs_dir, 'trips.txt')
temp_path = os.path.join(gtfs_dir, 'trips_temp.txt')

try:
    with open(file_path, 'r', encoding='utf-8-sig') as infile:
        reader = csv.DictReader(infile)
        fieldnames = reader.fieldnames
        
        if 'shape_id' in fieldnames:
            new_fieldnames = [f for f in fieldnames if f != 'shape_id']
            
            with open(temp_path, 'w', encoding='utf-8', newline='') as outfile:
                writer = csv.DictWriter(outfile, fieldnames=new_fieldnames)
                writer.writeheader()
                for row in reader:
                    if 'shape_id' in row:
                        del row['shape_id']
                    writer.writerow(row)
            
            os.replace(temp_path, file_path)
            print(f'Removed shape_id from {file_path}')
        else:
            print(f'shape_id column not found in {file_path}')
except FileNotFoundError:
    print(f'{file_path} not found')
    # Use exit code 0 to not break if file is missing? 
    # The original script just printed 'trips.txt not found' and continued (implicitly exit 0).
    # But later had catch-all Exception exit(1).
    # Being safe and explicit:
    exit(1) 
except Exception as e:
    print(f'Error processing {file_path}: {e}')
    exit(1)
