#!/usr/bin/env python3
"""Validate release identity and AppCenter publication metadata."""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_ID = "dev.mysh.valapad"
METAINFO = ROOT / "data" / f"{APP_ID}.metainfo.xml.in"
MANIFEST = ROOT / f"{APP_ID}.yml"
SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def meson_value(pattern: str, text: str, label: str) -> str:
    match = re.search(pattern, text, re.MULTILINE)
    if match is None:
        fail(f"could not read {label} from meson.build")
    return match.group(1)


def public_url_exists(url: str) -> bool:
    request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "ValaPad-CI"})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return 200 <= response.status < 400
    except urllib.error.HTTPError as error:
        if error.code != 405:
            return False
    except urllib.error.URLError:
        return False

    request = urllib.request.Request(url, headers={"User-Agent": "ValaPad-CI"})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return 200 <= response.status < 400
    except (urllib.error.HTTPError, urllib.error.URLError):
        return False


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", help="Git tag expected to match the project version")
    parser.add_argument(
        "--appcenter",
        action="store_true",
        help="also require publicly accessible AppCenter screenshots",
    )
    args = parser.parse_args()

    meson = (ROOT / "meson.build").read_text(encoding="utf-8")
    project_id = meson_value(r"project\(\s*\n\s*'([^']+)'", meson, "project ID")
    version = meson_value(r"^\s*version:\s*'([^']+)'", meson, "project version")
    if project_id != APP_ID:
        fail(f"Meson project ID is {project_id!r}, expected {APP_ID!r}")
    if SEMVER.fullmatch(version) is None:
        fail(f"project version {version!r} is not a SemVer release (X.Y.Z)")

    manifest = MANIFEST.read_text(encoding="utf-8")
    for field in ("id", "command"):
        if re.search(rf"^{field}:\s*{re.escape(APP_ID)}\s*$", manifest, re.MULTILINE) is None:
            fail(f"Flatpak manifest {field!r} does not match {APP_ID}")
    if not re.search(r"^runtime-version:\s*['\"]?8['\"]?\s*$", manifest, re.MULTILINE):
        fail("Flatpak manifest must target elementary runtime 8")

    root = ET.parse(METAINFO).getroot()
    component_id = root.findtext("id")
    if component_id != APP_ID:
        fail(f"MetaInfo ID is {component_id!r}, expected {APP_ID!r}")
    launchable = root.findtext("launchable")
    if launchable != f"{APP_ID}.desktop":
        fail("MetaInfo launchable does not match the application ID")

    releases = root.findall("./releases/release")
    matching = [release for release in releases if release.get("version") == version]
    if not matching:
        fail(f"MetaInfo has no release entry for version {version}")
    try:
        release_date = dt.date.fromisoformat(matching[0].attrib["date"])
    except (KeyError, ValueError):
        fail(f"MetaInfo release {version} has no valid ISO date")
    if release_date > dt.date.today():
        fail(f"MetaInfo release date {release_date} is in the future")

    if args.tag is not None and args.tag != version:
        fail(f"tag {args.tag!r} must exactly match project version {version!r}")

    if args.appcenter:
        screenshots = root.findall("./screenshots/screenshot")
        if not screenshots:
            fail("AppCenter publication requires at least one clean full-window screenshot")
        if not any(screenshot.get("type") == "default" for screenshot in screenshots):
            fail("one AppCenter screenshot must have type=\"default\"")
        for screenshot in screenshots:
            image = screenshot.findtext("image")
            caption = screenshot.findtext("caption")
            if not image or not image.startswith("https://"):
                fail("every AppCenter screenshot must use an HTTPS image URL")
            if not caption:
                fail("every AppCenter screenshot must have a caption")
            if not public_url_exists(image):
                fail(f"screenshot is not publicly accessible: {image}")

    print(f"Validated {APP_ID} {version}")


if __name__ == "__main__":
    main()
