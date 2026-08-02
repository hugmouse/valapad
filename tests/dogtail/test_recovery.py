#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Iaroslav Angliuster

"""End-to-end recovery tests driven through ValaPad's accessible UI."""

from __future__ import annotations

import configparser
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

from dogtail.config import config

# The test runner creates an isolated accessibility bus, so Dogtail does not
# need to change the desktop-wide accessibility settings
config.checkForA11y = False
config.actionDelay = 0.1
config.defaultDelay = 0.1
config.searchBackoffDuration = 0.1
config.searchCutoffCount = 50

from dogtail.tree import root


APP_ID = "dev.mysh.valapad"
RECOVERY_WINDOW = "Recover Documents"
RECOVERED_TEXT = "The recovered first line\nThe recovered second line"
SNAPSHOT_ID = "dogtail-recovery-snapshot"


class RecoveryTest(unittest.TestCase):
    def setUp(self) -> None:
        binary = os.environ.get("VALAPAD_BINARY")
        if not binary:
            self.fail("VALAPAD_BINARY must point to the built ValaPad executable")

        self.binary = str(Path(binary).resolve())
        self.home = Path(tempfile.mkdtemp(prefix="valapad-dogtail-"))
        self.state_home = self.home / "state"
        self.snapshot_dir = (
            self.state_home / APP_ID / "recovery" / SNAPSHOT_ID
        )
        self._seed_snapshot()

        self.environment = os.environ.copy()
        self.environment.update(
            {
                "GSETTINGS_BACKEND": "memory",
                "LANG": "C.UTF-8",
                "LC_ALL": "C.UTF-8",
                "XDG_CACHE_HOME": str(self.home / "cache"),
                "XDG_CONFIG_HOME": str(self.home / "config"),
                "XDG_DATA_HOME": str(self.home / "data"),
                "XDG_STATE_HOME": str(self.state_home),
            }
        )
        self.process: subprocess.Popen[str] | None = None

    def tearDown(self) -> None:
        if self.process is not None:
            if self.process.poll() is None:
                self.process.kill()
            self.process.communicate(timeout=5)
        shutil.rmtree(self.home, ignore_errors=True)

    def _seed_snapshot(self) -> None:
        self.snapshot_dir.mkdir(parents=True)
        (self.snapshot_dir / "content.txt").write_text(
            RECOVERED_TEXT,
            encoding="utf-8",
        )
        metadata = configparser.ConfigParser()
        metadata.optionxform = str
        metadata["Recovery"] = {
            "version": "1",
            "display-name": "Dogtail Recovery.txt",
            "saved-at": str(int(time.time())),
            "cursor-offset": "12",
            "use-crlf": "false",
            "encoding": "UTF-8",
        }
        with (self.snapshot_dir / "metadata.ini").open(
            "w",
            encoding="utf-8",
        ) as metadata_file:
            metadata.write(metadata_file, space_around_delimiters=False)

    def _launch(self):
        self.process = subprocess.Popen(
            [self.binary],
            env=self.environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return self._wait_for_node(
            self._find_recovery_window,
            "recovery window",
        )

    @staticmethod
    def _find_recovery_window():
        try:
            application = root.application(APP_ID, retry=False)
        except Exception:
            return None

        for window in application.children:
            if window.isChild("Recover Selected", retry=False):
                return window
        return None

    def _wait_for_node(self, finder, description: str, timeout: float = 10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            node = finder()
            if node is not None:
                return node
            if self.process is not None and self.process.poll() is not None:
                stdout, stderr = self.process.communicate()
                self.fail(
                    f"ValaPad exited while waiting for {description}.\n"
                    f"stdout:\n{stdout}\nstderr:\n{stderr}"
                )
            time.sleep(0.1)
        process_output = ""
        if self.process is not None:
            self.process.terminate()
            try:
                stdout, stderr = self.process.communicate(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                stdout, stderr = self.process.communicate(timeout=2)
            process_output = f"\nstdout:\n{stdout}\nstderr:\n{stderr}"
        self.fail(f"Timed out waiting for {description}{process_output}")

    def _editor_window(self):
        def find_editor():
            for application in root.applications():
                for window in application.children:
                    if window.name and window.name.endswith(" - ValaPad"):
                        return window
            return None

        return self._wait_for_node(find_editor, "editor window")

    @staticmethod
    def _activate(node) -> None:
        actions = node.actions
        for action_name in ("click", "press", "activate", "check"):
            if action_name in actions:
                node.doActionNamed(action_name)
                return
        raise AssertionError(
            f"{node.name!r} has no activation action; available: {list(actions)}"
        )

    @staticmethod
    def _text_view(window):
        candidates = window.findChildren(
            lambda node: node.roleName in ("text", "text entry")
        )
        for candidate in candidates:
            if candidate.text is not None:
                return candidate
        raise AssertionError("The editor did not expose its text view through AT-SPI")

    def test_recover_selected_restores_unsaved_text(self) -> None:
        dialog = self._launch()
        self.assertTrue(dialog.isChild("Dogtail Recovery.txt", roleName="label"))

        self._activate(dialog.button("Recover Selected"))
        editor = self._editor_window()

        self.assertEqual(self._text_view(editor).text, RECOVERED_TEXT)
        self.assertTrue(
            self.snapshot_dir.is_dir(),
            "Recovering must keep the snapshot until the document is saved or discarded",
        )

    def test_discard_selected_deletes_snapshot_and_opens_blank_editor(self) -> None:
        dialog = self._launch()
        self._activate(dialog.button("Discard Selected"))
        editor = self._editor_window()

        self._wait_for_node(
            lambda: True if not self.snapshot_dir.exists() else None,
            "discarded snapshot deletion",
        )
        self.assertEqual(self._text_view(editor).text, "")

if __name__ == "__main__":
    unittest.main(verbosity=2)
