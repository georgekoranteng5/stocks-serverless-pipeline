#!/usr/bin/env python3
"""Build the ingestion Lambda zip and emit JSON for Terraform external data source."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


def main() -> int:
    module_dir = Path(__file__).resolve().parent
    repo_root = module_dir.parents[2]
    source_dir = repo_root / "lambdas" / "ingestion"
    build_dir = module_dir / "build"
    zip_path = module_dir / "ingestion.zip"

    if build_dir.exists():
        shutil.rmtree(build_dir)
    build_dir.mkdir(parents=True)

    shutil.copy2(source_dir / "handler.py", build_dir / "handler.py")

    subprocess.run(
        [
            sys.executable,
            "-m",
            "pip",
            "install",
            "-r",
            str(source_dir / "requirements.txt"),
            "-t",
            str(build_dir),
            "--quiet",
            "--disable-pip-version-check",
        ],
        check=True,
    )

    if zip_path.exists():
        zip_path.unlink()

    # Fixed timestamps so source_code_hash is stable across plans.
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(build_dir.rglob("*")):
            if not path.is_file():
                continue
            # Skip bytecode noise if present
            if path.suffix in {".pyc"} or "__pycache__" in path.parts:
                continue
            rel = path.relative_to(build_dir).as_posix()
            info = zipfile.ZipInfo(rel, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            zf.writestr(info, path.read_bytes())

    digest = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    print(json.dumps({"zip_path": str(zip_path), "sha256": digest}))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        raise SystemExit(1) from exc
