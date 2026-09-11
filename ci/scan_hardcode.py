# Author: Krish Sutariya

import re
import sys
from pathlib import Path

PATTERNS = [
    re.compile(
        r"""(?i)\b(api[_-]?key|secret[_-]?key|access[_-]?token|client[_-]?secret)\b\s*[:=]\s*['"][A-Za-z0-9_\-\/+=]{12,}['"]"""
    ),
    re.compile(r"""(?i)\bAKIA[0-9A-Z]{16}\b"""),
    re.compile(r"""(?i)\bAIza[0-9A-Za-z_\-]{30,}\b"""),
    re.compile(r"""(?i)\bgh[pousr]_[A-Za-z0-9_]{20,}\b"""),
]

ALLOWED_SUFFIXES = {
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".java",
    ".go",
    ".rb",
    ".php",
    ".env",
    ".yaml",
    ".yml",
    ".json",
    ".tf",
    ".tfvars",
    ".ini",
    ".cfg",
    ".conf",
    ".sh",
    ".ps1",
}

EXCLUDE_PARTS = {
    ".git",
    ".venv",
    "node_modules",
    "__pycache__",
    "quarantine",
}

violations = []

for path in Path(".").rglob("*"):
    if not path.is_file():
        continue

    if path.suffix.lower() not in ALLOWED_SUFFIXES:
        continue

    if any(part in EXCLUDE_PARTS for part in path.parts):
        continue

    try:
        text = path.read_text(errors="ignore")
    except OSError:
        continue

    for line_number, line in enumerate(text.splitlines(), 1):
        if any(pattern.search(line) for pattern in PATTERNS):
            violations.append(f"{path}:{line_number}")

if violations:
    print("FAIL-CLOSED: hardcoded credential pattern detected:")
    print("\n".join(violations))
    print(
        "Build is quarantined. Remove the secret and use a secure secret-management mechanism."
    )
    sys.exit(1)

print("PASS: no raw hardcoded credential pattern detected.")
sys.exit(0)
