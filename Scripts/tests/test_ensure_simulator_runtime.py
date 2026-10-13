import subprocess
import unittest

from Scripts.ensure_simulator_runtime import has_runtime, list_runtimes, RETRY_TIMEOUT_SECONDS


class RuntimeTests(unittest.TestCase):
    def test_accepts_exact_available_runtime(self):
        self.assertTrue(has_runtime({"runtimes": [
            {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-0", "isAvailable": True},
        ]}, "26.0"))

    def test_rejects_newer_or_unavailable_runtime(self):
        self.assertFalse(has_runtime({"runtimes": [
            {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-2", "isAvailable": True},
            {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-0", "isAvailable": False},
        ]}, "26.0"))
