#!/usr/bin/env python3
"""Verify actual PowerShell incremental applier against Python release builder."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from chunk_release import FILES, build_delta, write_full, sha256


def test():
    pwsh = shutil.which("pwsh")
    if pwsh is None:
        raise RuntimeError("PowerShell 7 is required to verify production patch logic")
    root = Path(__file__).resolve().parent.parent
    with tempfile.TemporaryDirectory() as dir:
        d = Path(dir)
        older, newer, target = d / "old", d / "new", d / "installed"
        older.mkdir()
        newer.mkdir()
        original = os.urandom(3 * 1024 * 1024)
        changed = original[:1_500_000] + b"ADDITIONAL COMBAT FX AND CARD UPDATES" + original[1_500_000:]
        for file in FILES:
            if file.endswith(".pck"):
                (older / file).write_bytes(original)
                (newer / file).write_bytes(changed)
            elif file.endswith(".exe"):
                engine = os.urandom(512 * 1024)
                (older / file).write_bytes(engine)
                (newer / file).write_bytes(engine)
            else:
                (older / file).write_text("unchanged file\n", encoding="utf-8")
                (newer / file).write_text("unchanged file\n", encoding="utf-8")
        write_full(older, "v1.0.0", d / "old.zip")
        write_full(newer, "v1.0.1", d / "new.zip")
        patch = d / "SlimeHour-Delta.zip"
        assert build_delta(older, newer, patch)
        subprocess.run([pwsh, "-NoProfile", "-File", str(root / "update_and_run.ps1"),
                        "-ApplyOnly", str(patch), "-BaseDirectory", str(older),
                        "-TargetDirectory", str(target)], check=True, timeout=120)
        for file in FILES:
            if sha256(newer / file) != sha256(target / file):
                raise RuntimeError("PowerShell patch mismatch: " + file)
        metadata = json.loads((target / "release_manifest.json").read_text(encoding="utf-8-sig"))
        assert metadata["version"] == "v1.0.1"
        assert patch.stat().st_size < (d / "new.zip").stat().st_size
        print("PASS: actual PowerShell updater correctly reused chunks and verified files")
        # Check the hidden, offline install-only route used by the Godot UI.
        # The helper must not download any files or overwrite the base version.
        local = d / "userprofile"
        local.mkdir()
        env = dict(os.environ, LOCALAPPDATA=str(local))
        for mode, source in [("delta", patch), ("full", d / "new.zip")]:
            copied = d / ("install_" + mode + ".zip")
            shutil.copyfile(source, copied)
            subprocess.run([pwsh, "-NoProfile", "-File", str(root / "update_and_run.ps1"),
                            "-InstallDownloaded", str(copied),
                            "-InstallVersion", "v1.0.1",
                            "-ExpectedSha256", sha256(copied),
                            "-DownloadKind", mode,
                            "-BaseDirectory", str(older),
                            "-TestNoLaunch"], check=True, timeout=120, env=env)
            final = local / "SlimeHour" / "versions" / "v1.0.1"
            for file in FILES:
                if sha256(newer / file) != sha256(final / file):
                    raise RuntimeError(f"In-game {mode} installation mismatch: {file}")
            assert (local / "SlimeHour" / "last_installed.txt").read_text().strip() == "v1.0.1"
            assert sha256(older / "SlimeHour.pck") == sha256(d / "old" / "SlimeHour.pck")
            print("PASS: hidden", mode, "installer validated and kept the base files")


if __name__ == "__main__":
    test()
