#!/usr/bin/env python3
"""Read the report ZIP emitted by BugReportPage of flutter_qa_inspector."""

import argparse
from collections import Counter
import json
from pathlib import Path
import struct
import sys
import tempfile
import zipfile


REQUIRED_ENTRIES = ("description.txt", "inspector.json")
KNOWN_ENTRIES = (*REQUIRED_ENTRIES, "screenshot.png")
MAX_FILE_BYTES = 64 * 1024 * 1024


def reject_non_finite(value):
    raise ValueError(f"Non-finite JSON number: {value}")


def read_entries(archive):
    """Read only known root entries; never extract paths supplied by the ZIP."""
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        counts = Counter(names)
        missing = [name for name in REQUIRED_ENTRIES if name not in counts]
        if missing:
            raise ValueError(f"Missing required entries: {', '.join(missing)}")
        contents = {}
        for name in KNOWN_ENTRIES:
            if name not in counts:
                continue
            if counts[name] != 1:
                raise ValueError(f"Ambiguous duplicate entry: {name}")
            member = bundle.getinfo(name)
            if member.file_size > MAX_FILE_BYTES:
                raise ValueError(f"Entry exceeds 64 MiB: {name}")
            with bundle.open(member) as stream:
                data = stream.read(MAX_FILE_BYTES + 1)
            if len(data) > MAX_FILE_BYTES:
                raise ValueError(f"Entry exceeds 64 MiB: {name}")
            contents[name] = data
        return contents, [name for name in names if name not in KNOWN_ENTRIES]


def read_report(archive, output_dir=None):
    archive = Path(archive).expanduser().resolve(strict=True)
    contents, ignored = read_entries(archive)
    description = contents["description.txt"].decode("utf-8-sig")
    payload = json.loads(
        contents["inspector.json"].decode("utf-8-sig"),
        parse_constant=reject_non_finite,
    )
    if not isinstance(payload, dict) or not isinstance(payload.get("inspector"), dict):
        raise ValueError("inspector.json must contain a top-level 'inspector' object")
    inspector = payload["inspector"]
    warnings = []
    if not description.strip():
        warnings.append("description.txt is blank; tester supplied no description")
    for field in ("kind", "id", "widgetType", "bounds", "capturedAtUtc"):
        if field not in inspector:
            warnings.append(f"inspector.{field} is missing")
    if inspector.get("kind") not in ("widget", "page"):
        warnings.append("inspector.kind is not widget/page; inspect the raw payload")

    snapshot_counts = {}
    for field in ("blocs", "widgetStates", "stateHistory"):
        values = inspector.get(field)
        snapshot_counts[field] = len(values) if isinstance(values, list) else None
        if not isinstance(values, list):
            warnings.append(f"inspector.{field} is missing or not a list")
        elif field != "stateHistory":
            for index, value in enumerate(values):
                if isinstance(value, dict) and value.get("captureErrorType") is not None:
                    warnings.append(
                        f"inspector.{field}[{index}] has captureErrorType: "
                        f"{value['captureErrorType']}"
                    )

    image = contents.get("screenshot.png")
    image_size = None
    metadata = payload.get("screenshot")
    if image is not None:
        if (
            len(image) < 24
            or image[:8] != b"\x89PNG\r\n\x1a\n"
            or image[12:16] != b"IHDR"
        ):
            raise ValueError("screenshot.png does not have a valid PNG header")
        width, height = struct.unpack(">II", image[16:24])
        if width == 0 or height == 0:
            raise ValueError("screenshot.png has zero width or height")
        image_size = {"width": width, "height": height}
        if not isinstance(metadata, dict):
            warnings.append("PNG is present without a screenshot metadata object")
        elif metadata.get("width") != width or metadata.get("height") != height:
            warnings.append("PNG dimensions differ from screenshot metadata")
    elif metadata is not None:
        warnings.append("screenshot metadata is present but screenshot.png is absent")

    if output_dir is None:
        output = Path(tempfile.mkdtemp(prefix="qa-bug-report-")).resolve()
    else:
        output = Path(output_dir).expanduser().resolve()
        output.mkdir(parents=True, exist_ok=False)
    files = {}
    for name, data in contents.items():
        destination = output / name
        with destination.open("xb") as stream:
            stream.write(data)
        files[name] = str(destination)
    return {
        "archive": str(archive),
        "output_directory": str(output),
        "files": files,
        "selection": {
            field: inspector[field]
            for field in (
                "kind", "id", "label", "widgetType", "source", "route", "capturedAtUtc"
            )
            if field in inspector
        },
        "counts": snapshot_counts,
        "png_dimensions": image_size,
        "ignored_entries": ignored,
        "warnings": warnings,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="Bug report ZIP to read")
    parser.add_argument(
        "--output-dir", type=Path, help="New extraction directory (default: unique temp dir)"
    )
    args = parser.parse_args()
    try:
        result = read_report(args.archive, args.output_dir)
    except (
        OSError, RuntimeError, ValueError, UnicodeError, NotImplementedError, zipfile.BadZipFile
    ) as error:
        print(f"Could not read bug report: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
