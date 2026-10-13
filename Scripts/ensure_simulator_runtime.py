#!/usr/bin/env python3
"""Require runtime matching pinned Xcode SDK; install Apple's own if absent."""
import json
import subprocess
import sys
from pathlib import Path

# First simctl call on a fresh runner warms CoreSimulator; observed to blow
# past 60s. Keep a generous first bound plus one bounded retry.
FIRST_CHECK_TIMEOUT_SECONDS = 300
RETRY_TIMEOUT_SECONDS = 120


def has_runtime(payload: dict, sdk: str) -> bool:
    wanted = f"com.apple.CoreSimulator.SimRuntime.iOS-{sdk.replace('.', '-')}"
    return any(
        item.get("identifier") == wanted and item.get("isAvailable") is True
        for item in payload.get("runtimes", [])
    )


def list_runtimes(*, runner=subprocess.run, timeout: int) -> dict:
    command = ["xcrun", "simctl", "list", "runtimes", "--json"]
    try:
        output = runner(command, check=True, capture_output=True,
                        text=True, timeout=timeout).stdout
    except subprocess.TimeoutExpired:
        print(f"simctl list runtimes timed out after {timeout}s; retrying once",
              file=sys.stderr)
        output = runner(command, check=True, capture_output=True,
                        text=True, timeout=RETRY_TIMEOUT_SECONDS).stdout
    return json.loads(output)


def main() -> int:
    sdk = json.loads(Path("toolchain.json").read_text())["iphoneos_sdk"]

    def check() -> bool:
        return has_runtime(list_runtimes(timeout=FIRST_CHECK_TIMEOUT_SECONDS), sdk)

    if not check():
        print(f"Required iOS {sdk} simulator runtime missing; installing pinned Xcode platform", flush=True)
        subprocess.run(
            ["xcodebuild", "-downloadPlatform", "iOS", "-architectureVariant", "universal"],
            check=True, timeout=1200,
        )
    if not check():
        print(f"ACCEPTANCE BLOCKER: iOS {sdk} runtime unavailable after platform download", file=sys.stderr)
        return 1
    print(f"Exact iOS {sdk} simulator runtime: available")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
