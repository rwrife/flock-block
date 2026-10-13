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


class ListRuntimesTests(unittest.TestCase):
    def test_timeout_then_retry_recovers(self):
        calls = []

        def runner(command, **kwargs):
            calls.append(kwargs["timeout"])
            if len(calls) == 1:
                raise subprocess.TimeoutExpired(command, kwargs["timeout"])
            return subprocess.CompletedProcess(command, 0, '{"runtimes": []}')

        self.assertEqual(list_runtimes(runner=runner, timeout=300), {"runtimes": []})
        self.assertEqual(calls, [300, RETRY_TIMEOUT_SECONDS])

    def test_repeated_timeout_propagates(self):
        def runner(command, **kwargs):
            raise subprocess.TimeoutExpired(command, kwargs["timeout"])

        with self.assertRaises(subprocess.TimeoutExpired):
            list_runtimes(runner=runner, timeout=300)
