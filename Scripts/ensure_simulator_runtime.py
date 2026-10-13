#!/usr/bin/env python3
"""Require runtime matching pinned Xcode SDK; install Apple's own if absent."""
import json
import subprocess
import sys
from pathlib import Path


def has_runtime(payload: dict, sdk: str) -> bool:
    wanted = f"com.apple.CoreSimulator.SimRuntime.iOS-{sdk.replace('.', '-')}"
    return any(
        item.get("identifier") == wanted and item.get("isAvailable") is True
        for item in payload.get("runtimes", [])
    )


def main() -> int:
    sdk = json.loads(Path("toolchain.json").read_text())["iphoneos_sdk"]
    def check() -> bool:
        output = subprocess.run(
            ["xcrun", "simctl", "list", "runtimes", "--json"],
            check=True, capture_output=True, text=True, timeout=60,
        ).stdout
        return has_runtime(json.loads(output), sdk)

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
