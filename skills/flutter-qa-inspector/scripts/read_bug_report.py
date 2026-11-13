#!/usr/bin/env python3
"""Read the report ZIP emitted by BugReportPage of flutter_qa_inspector."""

import argparse
from collections import Counter
import json
from pathlib import Path
import struct
import sys
import tempfile
from urllib.parse import urlsplit, urlunsplit
import zipfile


REQUIRED_ENTRIES = ("description.txt", "inspector.json")
KNOWN_ENTRIES = (*REQUIRED_ENTRIES, "screenshot.png")
MAX_FILE_BYTES = 64 * 1024 * 1024
# The manifest lists at most this many notable API calls; read the JSON for all.
MAX_NOTABLE_CALLS = 20


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


def warn_capture_errors(field, values, warnings):
    for index, value in enumerate(values):
        if isinstance(value, dict) and value.get("captureErrorType") is not None:
            warnings.append(
                f"inspector.{field}[{index}] has captureErrorType: "
                f"{value['captureErrorType']}"
            )


def url_without_query(url):
    """The URL of a call without its query and fragment, for the manifest."""
    if not isinstance(url, str):
        return None
    try:
        parts = urlsplit(url)
    except ValueError:
        return None
    return urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))


def summarize_network(calls, warnings):
    """Counts the API calls (since 0.10.0) and lists the notable ones."""
    statuses = Counter()
    notable = []
    truncated = 0
    for index, call in enumerate(calls):
        if not isinstance(call, dict):
            warnings.append(f"inspector.network[{index}] is not an object")
            continue
        status = call.get("status")
        statuses[status if isinstance(status, str) else "unknown"] += 1
        response = call.get("response") if isinstance(call.get("response"), dict) else {}
        status_code = response.get("statusCode")
        error = call.get("error") if isinstance(call.get("error"), dict) else {}
        for part in (call.get("request"), response):
            body = part.get("body") if isinstance(part, dict) else None
            if isinstance(body, dict) and body.get("truncated") is True:
                truncated += 1
        failed = status in ("failed", "pending") or (
            isinstance(status_code, int) and status_code >= 400
        )
        if failed and len(notable) < MAX_NOTABLE_CALLS:
            notable.append({
                key: value
                for key, value in (
                    ("index", index),
                    ("id", call.get("id")),
                    ("status", status),
                    ("method", call.get("method")),
                    ("url", url_without_query(call.get("url"))),
                    ("statusCode", status_code),
                    ("errorType", error.get("type")),
                    ("durationMs", call.get("durationMs")),
                )
                if value is not None
            })
    return {
        "by_status": dict(statuses),
        "truncated_bodies": truncated,
        # Failed, pending, or with a status code >= 400; URL without query.
        "notable_calls": notable,
    }


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
    for field in ("blocs", "stateHistory"):
        values = inspector.get(field)
        snapshot_counts[field] = len(values) if isinstance(values, list) else None
        if not isinstance(values, list):
            warnings.append(f"inspector.{field} is missing or not a list")
        elif field == "blocs":
            warn_capture_errors(field, values, warnings)

    # Since 0.9.0: the parameters of the child of the marker, as an object.
    widget_state = inspector.get("widgetState")
    legacy_states = inspector.get("widgetStates")
    if isinstance(widget_state, dict):
        snapshot_counts["widgetState"] = len(widget_state)
    elif "widgetState" in inspector:
        snapshot_counts["widgetState"] = None
        warnings.append("inspector.widgetState is not an object")
    elif isinstance(legacy_states, list):
        snapshot_counts["widgetStates"] = len(legacy_states)
        warnings.append(
            "inspector.widgetStates is the format before 0.9.0: State snapshots "
            "of the subtree and ancestors, not the parameters of the selected child"
        )
        warn_capture_errors("widgetStates", legacy_states, warnings)
    else:
        snapshot_counts["widgetState"] = None
        warnings.append("inspector.widgetState is missing")
    widget_state_error = inspector.get("widgetStateCaptureErrorType")
    if widget_state_error is not None:
        warnings.append(
            f"inspector.widgetStateCaptureErrorType: {widget_state_error}"
        )

    # Since 0.10.0: the API calls of a Dio client recorded by the package.
    network = inspector.get("network")
    network_summary = None
    if isinstance(network, list):
        snapshot_counts["network"] = len(network)
        network_summary = summarize_network(network, warnings)
    elif "network" in inspector:
        snapshot_counts["network"] = None
        warnings.append("inspector.network is not a list")
    else:
        snapshot_counts["network"] = None
        warnings.append(
            "inspector.network is missing: a report before 0.10.0 has no API "
            "calls, which does not mean the app made none"
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
        "network": network_summary,
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
