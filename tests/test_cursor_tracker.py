import importlib.util
import socket
import tempfile
import threading
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "cursor-tracker.py"
SPEC = importlib.util.spec_from_file_location("cursor_tracker", MODULE_PATH)
cursor_tracker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cursor_tracker)


class CursorTrackerTests(unittest.TestCase):
    def test_parse_interval_accepts_positive_number(self):
        self.assertEqual(cursor_tracker.parse_interval("0.25"), 0.25)

    def test_parse_interval_rejects_invalid_values(self):
        for value in ("0", "-1", "nan", "inf", "nope"):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    cursor_tracker.parse_interval(value)

    def test_poll_reads_cursor_position(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "hypr.sock")
            ready = threading.Event()

            def serve():
                with socket.socket(socket.AF_UNIX) as server:
                    server.bind(path)
                    server.listen(1)
                    ready.set()
                    connection, _ = server.accept()
                    with connection:
                        self.assertEqual(connection.recv(64), b"cursorpos")
                        connection.sendall(b"120, 450\n")

            thread = threading.Thread(target=serve)
            thread.start()
            self.assertTrue(ready.wait(timeout=1))
            self.assertEqual(cursor_tracker.poll(path), "120, 450")
            thread.join(timeout=1)
            self.assertFalse(thread.is_alive())


if __name__ == "__main__":
    unittest.main()
