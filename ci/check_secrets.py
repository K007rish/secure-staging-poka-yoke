# Author: Krish Sutariya

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python ci/check_secrets.py <scan-result-file>")
        return 2

    scan_file = Path(sys.argv[1])

    if not scan_file.exists():
        print(f"FAIL-CLOSED: scan result file does not exist: {scan_file}")
        return 1

    try:
        data = json.loads(scan_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"FAIL-CLOSED: unable to read secret scan result: {error}")
        return 1

    findings = data.get("results", {})

    if findings:
        print("FAIL-CLOSED: potential secrets detected:")

        for filename, results in findings.items():
            for result in results:
                detector = result.get("type", "Unknown detector")
                line_number = result.get("line_number", "Unknown line")
                print(f"- {filename}:{line_number} ({detector})")

        print("Build is quarantined. Remove the detected secret before merging.")
        return 1

    print("PASS: detect-secrets found no potential secrets.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
