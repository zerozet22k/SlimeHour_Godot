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
        # Test the exact production install path used by the in-game updater:
        # a user's EXISTING SlimeHour.exe desktop shortcut. Installing into
        # AppData while leaving that executable alone is a regression.
        local = d / "userprofile"
        local.mkdir()
        env = dict(os.environ, LOCALAPPDATA=str(local))
        for mode, source in [("delta", patch), ("full", d / "new.zip")]:
            game_folder = d / ("original installed game " + mode)
            shutil.copytree(older, game_folder)
            (game_folder / "my-unrelated-save.txt").write_text("keep player files", encoding="utf-8")
            copied = d / ("install_" + mode + ".zip")
            shutil.copyfile(source, copied)
            subprocess.run([pwsh, "-NoProfile", "-File", str(root / "update_and_run.ps1"),
                            "-InstallDownloaded", str(copied),
                            "-InstallVersion", "v1.0.1",
                            "-ExpectedSha256", sha256(copied),
                            "-DownloadKind", mode,
                            "-BaseDirectory", str(game_folder),
                            "-TestNoLaunch"], check=True, timeout=120, env=env)
            for file in FILES:
                if sha256(newer / file) != sha256(game_folder / file):
                    raise RuntimeError(f"In-game {mode} did not update original shortcut path: {file}")
            metadata = json.loads((game_folder / "release_manifest.json").read_text(encoding="utf-8-sig"))
            assert metadata["version"] == "v1.0.1"
            assert (game_folder / "my-unrelated-save.txt").read_text() == "keep player files"
            assert not copied.exists(), "Successful install should delete the downloaded ZIP"
            # The old silent installer wrote an AppData version pointer, leaving
            # the original shortcut pointed at outdated game bytes.
            assert not (local / "SlimeHour" / "last_installed.txt").exists()
            print("PASS:", mode, "update persistently replaced original EXE/PCK/manifest and kept user files")

        # An interrupted/failed replacement must never leave a mixed EXE/PCK
        # pair in the original installation. Inject a failure after the PCK.
        broken = d / "rollback game folder"
        shutil.copytree(older, broken)
        failed_zip = d / "failed_install.zip"
        shutil.copyfile(d / "new.zip", failed_zip)
        failure = subprocess.run([pwsh, "-NoProfile", "-File", str(root / "update_and_run.ps1"),
                                  "-InstallDownloaded", str(failed_zip),
                                  "-InstallVersion", "v1.0.1",
                                  "-ExpectedSha256", sha256(failed_zip),
                                  "-DownloadKind", "full",
                                  "-BaseDirectory", str(broken),
                                  "-TestNoLaunch",
                                  "-TestFailAfterFile", "SlimeHour.pck"],
                                 check=False, timeout=120, env=env, capture_output=True, text=True)
        assert failure.returncode != 0, "Injected replacement failure must exit nonzero"
        for file in FILES:
            if sha256(older / file) != sha256(broken / file):
                raise RuntimeError("Rollback failed to restore original game: " + file)
        metadata = json.loads((broken / "release_manifest.json").read_text(encoding="utf-8-sig"))
        assert metadata["version"] == "v1.0.0"
        assert failed_zip.is_file(), "Failed install must preserve downloaded ZIP for retry"
        assert (local / "SlimeHour" / "update_error.log").is_file()
        print("PASS: failed in-place update rolls back every file and preserves verified download")



if __name__ == "__main__":
    test()
