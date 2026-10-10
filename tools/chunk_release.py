#!/usr/bin/env python3
"""Build content-addressed Windows release ZIPs and incremental PCK/EXE patches.

No third-party Python dependencies. SHA256 verifies every reconstructed output.
Chunks have content-derived boundaries; unchanged ranges are copied from the
previous installed release, so updates can be much smaller than the full game.
"""
import argparse
import hashlib
import json
import mmap
import os
import shutil
import tempfile
import zipfile
import zlib
from pathlib import Path

FILES = ("SlimeHour.exe", "SlimeHour.pck", "update_and_run.ps1",
         "updater_config.json", "Start_Slime_Hour.bat")
CHUNK_MIN = 128 * 1024
CHUNK_MAX = 1024 * 1024
SCAN_STEP = 64
MASK = (1 << 12) - 1  # Typical ~256 KiB chunks.


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as stream:
        for buf in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(buf)
    return h.hexdigest()


def chunks(path):
    """Content-defined boundaries sampled on stable absolute 64-byte offsets."""
    result = []
    with open(path, "rb") as f:
        size = os.fstat(f.fileno()).st_size
        if not size:
            return result
        with mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
            at = 0
            while at < size:
                stop = min(size, at + CHUNK_MAX)
                boundary = stop
                scan = ((at + CHUNK_MIN + SCAN_STEP - 1) // SCAN_STEP) * SCAN_STEP
                while scan < stop:
                    if (zlib.crc32(mm[scan: min(size, scan + 64)]) & MASK) == 0:
                        boundary = scan
                        break
                    scan += SCAN_STEP
                block = mm[at:boundary]
                result.append({"sha256": hashlib.sha256(block).hexdigest(),
                               "offset": at, "size": len(block)})
                at = boundary
    return result


def manifest(root, version):
    root = Path(root)
    files = []
    for filename in FILES:
        file = root / filename
        if not file.is_file():
            raise RuntimeError(f"Missing game file {file}")
        files.append({"name": filename, "size": file.stat().st_size,
                      "sha256": sha256(file), "chunks": chunks(file)})
    return {"format": 1, "version": version, "files": files}


def write_full(root, version, output):
    root, output = Path(root), Path(output)
    info = manifest(root, version)
    with open(root / "release_manifest.json", "w", encoding="utf-8") as f:
        json.dump(info, f, separators=(",", ":"), sort_keys=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in FILES + ("release_manifest.json",):
            archive.write(root / name, name)
    with zipfile.ZipFile(output) as test:
        if test.testzip() is not None:
            raise RuntimeError("Bad Windows ZIP checksum")
    checksum(output)
    print(f"Full release {version}: {output.stat().st_size:,} bytes")
    return info


def checksum(path):
    path = Path(path)
    (path.parent / (path.name + ".sha256")).write_text(
        sha256(path) + "  " + path.name + "\n", encoding="ascii")


def build_delta(old_root, new_root, output):
    old_root, new_root, output = map(Path, (old_root, new_root, output))
    old_manifest_path = old_root / "release_manifest.json"
    new_manifest_path = new_root / "release_manifest.json"
    if not old_manifest_path.exists() or not new_manifest_path.exists():
        print("Previous release lacks external-PCK manifest: full download required.")
        return False
    old = json.loads(old_manifest_path.read_text(encoding="utf-8"))
    new = json.loads(new_manifest_path.read_text(encoding="utf-8"))
    if old.get("format") != 1 or new.get("format") != 1:
        print("Incompatible manifest format: full download required.")
        return False
    have = {c["sha256"] for f in old["files"] for c in f["chunks"]}
    added = {}
    for f in new["files"]:
        for chunk in f["chunks"]:
            digest = chunk["sha256"]
            if digest not in have and digest not in added:
                added[digest] = (f["name"], chunk["offset"], chunk["size"])
    patch = {"format": 1, "base_version": old["version"],
             "target_version": new["version"], "manifest": new}
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        z.writestr("patch.json", json.dumps(patch, separators=(",", ":"), sort_keys=True))
        handles = {}
        try:
            for digest, (filename, offset, size) in added.items():
                if filename not in handles:
                    handles[filename] = open(new_root / filename, "rb")
                stream = handles[filename]
                stream.seek(offset)
                buf = stream.read(size)
                if hashlib.sha256(buf).hexdigest() != digest:
                    raise RuntimeError("Source chunk mismatch")
                z.writestr("chunks/" + digest, buf)
        finally:
            for stream in handles.values():
                stream.close()
    full_zip = output.parent / "SlimeHour-Windows.zip"
    if full_zip.is_file() and output.stat().st_size >= full_zip.stat().st_size * 0.85:
        print("Patch is too large; publishing full ZIP only.")
        output.unlink()
        return False
    checksum(output)
    (output.parent / "SlimeHour-Delta.json").write_text(
        json.dumps({"base_version": old["version"], "target_version": new["version"]},
                   separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Delta {old['version']} -> {new['version']}: "
          f"{output.stat().st_size:,} bytes, {len(added)} changed chunks.")
    return True


def apply_delta(old_root, patch_zip, target_dir):
    """Reference implementation for regression tests of the Windows PowerShell applier."""
    old_root, patch_zip, target_dir = map(Path, (old_root, patch_zip, target_dir))
    old = json.loads((old_root / "release_manifest.json").read_text(encoding="utf-8"))
    with zipfile.ZipFile(patch_zip) as z:
        patch = json.loads(z.read("patch.json"))
        if patch["base_version"] != old["version"]:
            raise RuntimeError("Wrong base version")
        old_chunks = {c["sha256"]: (old_root / f["name"], c["offset"], c["size"])
                      for f in old["files"] for c in f["chunks"]}
        target_dir.mkdir(parents=True, exist_ok=True)
        for f in patch["manifest"]["files"]:
            dest = target_dir / f["name"]
            with open(dest, "wb") as out:
                for chunk in f["chunks"]:
                    key = chunk["sha256"]
                    if key in old_chunks:
                        src, offset, size = old_chunks[key]
                        with open(src, "rb") as base:
                            base.seek(offset)
                            data = base.read(size)
                    else:
                        data = z.read("chunks/" + key)
                    if len(data) != chunk["size"] or hashlib.sha256(data).hexdigest() != key:
                        raise RuntimeError("Patch chunk mismatch")
                    out.write(data)
            if dest.stat().st_size != f["size"] or sha256(dest) != f["sha256"]:
                raise RuntimeError("Patch output file mismatch: " + f["name"])
        (target_dir / "release_manifest.json").write_text(
            json.dumps(patch["manifest"], separators=(",", ":"), sort_keys=True),
            encoding="utf-8")


def selftest():
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        a, b, rebuilt = (root / "a", root / "b", root / "rebuilt")
        a.mkdir()
        b.mkdir()
        random_blob = os.urandom(3 * 1024 * 1024)
        for name in FILES:
            if name.endswith(".pck"):
                (a / name).write_bytes(random_blob)
                (b / name).write_bytes(random_blob[:1200000] + b"gameplay change" +
                                       random_blob[1200000:])
            elif name.endswith(".exe"):
                (a / name).write_bytes(os.urandom(1024 * 1024))
                shutil.copyfile(a / name, b / name)
            else:
                (a / name).write_text("test launcher\n", encoding="utf-8")
                (b / name).write_text("test launcher\n", encoding="utf-8")
        write_full(a, "v1.0.0", root / "old.zip")
        write_full(b, "v1.0.1", root / "new.zip")
        assert build_delta(a, b, root / "SlimeHour-Delta.zip")
        apply_delta(a, root / "SlimeHour-Delta.zip", rebuilt)
        for name in FILES:
            assert sha256(b / name) == sha256(rebuilt / name), name
        assert (root / "SlimeHour-Delta.zip").stat().st_size < (
            root / "new.zip").stat().st_size
        print("PASS: incremental patch reuses unchanged chunks and reconstructs exact files.")


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("selftest")
    full = sub.add_parser("full")
    full.add_argument("directory")
    full.add_argument("version")
    full.add_argument("zip")
    delta = sub.add_parser("delta")
    delta.add_argument("old_directory")
    delta.add_argument("new_directory")
    delta.add_argument("zip")
    args = p.parse_args()
    if args.command == "selftest":
        selftest()
    elif args.command == "full":
        write_full(args.directory, args.version, args.zip)
    else:
        build_delta(args.old_directory, args.new_directory, args.zip)


if __name__ == "__main__":
    main()
