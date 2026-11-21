#!/usr/bin/env python3
"""Split SNCF train routes with OCECar TER trips before pfaedle.

Only routes with bus trips are copied. All route metadata is preserved except
route_id and route_type; trips are reassigned, never duplicated.
"""
import argparse
import csv
import os
from pathlib import Path
import tempfile


def read_csv(path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path, fields, rows):
    # Write then replace so an interrupted job cannot leave a partial GTFS file.
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def split(feed):
    routes_path, trips_path = feed / "routes.txt", feed / "trips.txt"
    stops_path = feed / "stop_times.txt"
    for p in (routes_path, trips_path, stops_path):
        if not p.is_file():
            raise ValueError(f"Required GTFS file missing: {p}")

    routes = read_csv(routes_path)
    trips = read_csv(trips_path)
    if not routes or not trips:
        raise ValueError("Empty SNCF routes.txt or trips.txt")
    routes_fields = list(routes[0])
    trips_fields = list(trips[0])
    for fields, required in ((routes_fields, ("route_id", "route_type")),
                             (trips_fields, ("trip_id", "route_id"))):
        if any(column not in fields for column in required):
            raise ValueError(f"Missing GTFS columns: {required}")

    known_routes = {r["route_id"]: r for r in routes}
    if len(known_routes) != len(routes):
        raise ValueError("Duplicate route_id in routes.txt")
    trip_to_route = {t["trip_id"]: t["route_id"] for t in trips}
    if len(trip_to_route) != len(trips):
        raise ValueError("Duplicate trip_id in trips.txt")

    # One streaming pass over stop_times; avoid retaining individual stop times.
    # Bit 1 = bus stop, bit 2 = train stop.
    modes = {}
    with stops_path.open("r", encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            trip_id, stop_id = row["trip_id"], row["stop_id"]
            if trip_id not in trip_to_route:
                continue
            if stop_id.startswith("StopPoint:OCECar"):
                modes[trip_id] = modes.get(trip_id, 0) | 1
            elif stop_id.startswith("StopPoint:OCETrain"):
                modes[trip_id] = modes.get(trip_id, 0) | 2

    affected = {}
    mixed = []
    for trip in trips:
        trip_id, route_id = trip["trip_id"], trip["route_id"]
        if route_id not in known_routes:
            raise ValueError(f"Trip {trip_id} references unknown route {route_id}")
        mode = modes.get(trip_id, 0)
        if mode == 3:
            mixed.append(trip_id)
        elif mode == 1 and known_routes[route_id]["route_type"] != "3":
            affected[route_id] = affected.get(route_id, 0) + 1

    if mixed:
        raise ValueError(
            f"{len(mixed)} trips contain both OCECar and OCETrain stops; "
            f"cannot split unambiguously (examples: {mixed[:5]})"
        )

    for route_id in sorted(affected):
        new_id = route_id + "__bus"
        if new_id in known_routes:
            raise ValueError(f"Generated bus route ID already exists: {new_id}")
        original = known_routes[route_id]
        copy = dict(original)
        copy["route_id"] = new_id
        copy["route_type"] = "3"
        routes.append(copy)

    changed = 0
    for trip in trips:
        if trip["route_id"] in affected and modes.get(trip["trip_id"]) == 1:
            trip["route_id"] += "__bus"
            changed += 1

    if affected:
        write_csv(routes_path, routes_fields, routes)
        write_csv(trips_path, trips_fields, trips)
    print(f"SNCF: moved {changed} bus trips into {len(affected)} bus route copies; "
          f"{len(trips)} trips total")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("feed", type=Path, help="Extracted GTFS directory")
    split(parser.parse_args().feed)
