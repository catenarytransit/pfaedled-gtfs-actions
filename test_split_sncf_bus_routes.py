import csv
from pathlib import Path
import tempfile
import unittest

from split_sncf_bus_routes import split


def write(path, rows):
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def read(path):
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


class SplitSncfTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.feed = Path(self.tmp.name)
        write(self.feed / "routes.txt", [
            {"route_id": "P37", "route_type": "2", "route_short_name": "P37",
             "route_color": "00BB22", "agency_id": "SNCF"},
            {"route_id": "BUS", "route_type": "3", "route_short_name": "B",
             "route_color": "123456", "agency_id": "SNCF"},
        ])
        write(self.feed / "trips.txt", [
            {"route_id": "P37", "trip_id": "rail", "service_id": "weekdays"},
            {"route_id": "P37", "trip_id": "coach", "service_id": "weekdays"},
            {"route_id": "BUS", "trip_id": "existing_bus", "service_id": "weekdays"},
        ])
        write(self.feed / "stop_times.txt", [
            {"trip_id": "rail", "stop_id": "StopPoint:OCETrain TER-123", "stop_sequence": "1"},
            {"trip_id": "rail", "stop_id": "StopPoint:OCETrain TER-456", "stop_sequence": "2"},
            {"trip_id": "coach", "stop_id": "StopPoint:OCECar TER-87734681", "stop_sequence": "1"},
            {"trip_id": "coach", "stop_id": "StopPoint:OCECar TER-87734269", "stop_sequence": "2"},
            {"trip_id": "existing_bus", "stop_id": "bus-stop", "stop_sequence": "1"},
        ])

    def test_split_and_idempotence(self):
        split(self.feed)
        routes = read(self.feed / "routes.txt")
        trips = {t["trip_id"]: t for t in read(self.feed / "trips.txt")}
        self.assertEqual(len(routes), 3)
        original = routes[0]
        coach = routes[-1]
        self.assertEqual(coach, {**original, "route_id": "P37__bus", "route_type": "3"})
        self.assertEqual(trips["coach"]["route_id"], "P37__bus")
        self.assertEqual(trips["rail"]["route_id"], "P37")
        self.assertEqual(trips["existing_bus"]["route_id"], "BUS")
        split(self.feed)
        self.assertEqual(len(read(self.feed / "routes.txt")), 3)

    def test_mixed_mode_trip_fails_without_writing(self):
        with (self.feed / "stop_times.txt").open("a", encoding="utf-8") as f:
            f.write("coach,StopPoint:OCETrain TER-987,3\n")
        with self.assertRaisesRegex(ValueError, "both OCECar and OCETrain"):
            split(self.feed)
        self.assertEqual(len(read(self.feed / "routes.txt")), 2)
        self.assertEqual(read(self.feed / "trips.txt")[1]["route_id"], "P37")


if __name__ == "__main__":
    unittest.main()
