"""Write unsigned APK v2 packages for Room of Requirement source rebuilds."""

import gzip
import hashlib
import os
from pathlib import Path
import re
import stat
import tarfile
import tempfile


def _header(name: str, mode: int = 0o644) -> tarfile.TarInfo:
    header = tarfile.TarInfo(name)
    header.mode = mode
    header.uid = header.gid = 0
    header.uname = header.gname = "root"
    header.mtime = 0
    return header


def create_apk(
    name: str, version: str, arch: str, dependencies: list[str], payload: Path, output: Path,
    *, provides: list[str] | None = None,
) -> None:
    """Package a staged filesystem without forging an upstream APK signature.

    Callers stage binaries, supporting files, and source provenance under payload.
    Versions use revision r1000 to distinguish these local builds from upstream.
    The resulting package requires explicit --allow-untrusted installation.
    """
    if not re.fullmatch(r"[a-z0-9][a-z0-9+_.-]*", name):
        raise ValueError("invalid APK package name")
    if not re.fullmatch(r"[0-9][a-zA-Z0-9_.+]*-r1000", version):
        raise ValueError("source-built APK version must use revision -r1000")
    if arch not in {"x86_64", "aarch64"}:
        raise ValueError("supported APK architectures are x86_64 and aarch64")
    if any(not dependency or any(c.isspace() for c in dependency) for dependency in dependencies):
        raise ValueError("APK dependencies must be nonempty single tokens")
    provides = [] if provides is None else provides
    if any(not alias or any(c.isspace() for c in alias) for alias in provides):
        raise ValueError("APK provides must be nonempty single tokens")
    payload = Path(payload).resolve(strict=True)
    output = Path(output).absolute()
    if not payload.is_dir():
        raise ValueError("APK payload must be a directory")
    if output.resolve().is_relative_to(payload):
        raise ValueError("APK output must be outside the payload directory")
    paths = sorted(payload.rglob("*"), key=lambda path: path.relative_to(payload).as_posix())
    if not paths:
        raise ValueError("APK payload must not be empty")
    for path in paths:
        mode = path.lstat().st_mode
        if not (stat.S_ISREG(mode) or stat.S_ISDIR(mode) or stat.S_ISLNK(mode)):
            raise ValueError(f"unsupported APK payload file: {path}")
        if path.relative_to(payload).parts[0].startswith("."):
            raise ValueError("APK payload must not contain top-level control files")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ror-apk-", dir=output.parent) as temporary:
        data_path = Path(temporary) / "data.tar.gz"
        installed_size = 0
        with data_path.open("wb") as compressed:
            with gzip.GzipFile(fileobj=compressed, mode="wb", filename="", mtime=0) as stream:
                with tarfile.open(fileobj=stream, mode="w|", format=tarfile.PAX_FORMAT) as archive:
                    for path in paths:
                        attributes = path.lstat()
                        header = _header(path.relative_to(payload).as_posix(),
                                         stat.S_IMODE(attributes.st_mode))
                        if stat.S_ISDIR(attributes.st_mode):
                            header.type = tarfile.DIRTYPE
                            archive.addfile(header)
                        elif stat.S_ISLNK(attributes.st_mode):
                            header.type = tarfile.SYMTYPE
                            header.linkname = os.readlink(path)
                            link_bytes = os.fsencode(header.linkname)
                            header.pax_headers["APK-TOOLS.checksum.SHA1"] = hashlib.sha1(
                                link_bytes
                            ).hexdigest()
                            installed_size += len(link_bytes)
                            archive.addfile(header)
                        else:
                            header.size = attributes.st_size
                            installed_size += header.size
                            with path.open("rb") as source:
                                header.pax_headers["APK-TOOLS.checksum.SHA1"] = hashlib.file_digest(
                                    source, "sha1"
                                ).hexdigest()
                                source.seek(0)
                                archive.addfile(header, source)

        with data_path.open("rb") as data:
            data_hash = hashlib.file_digest(data, "sha256").hexdigest()
        metadata = [
            "# Locally source-built; unsigned APK",
            f"pkgname = {name}", f"pkgver = {version}", f"arch = {arch}",
            f"size = {installed_size}", f"origin = {name}",
            f"pkgdesc = Source-built {name} for Room of Requirement",
            "maintainer = Room of Requirement", "builddate = 0", "license = Apache-2.0",
            *(f"depend = {dependency}" for dependency in dependencies),
            *(f"provides = {alias}" for alias in provides),
            f"datahash = {data_hash}",
        ]
        metadata_bytes = ("\n".join(metadata) + "\n").encode()
        package_path = Path(temporary) / "package.apk"
        with package_path.open("wb") as package:
            with gzip.GzipFile(fileobj=package, mode="wb", filename="", mtime=0) as stream:
                # APK's control stream must end after its last record, without
                # tar EOF blocks: those would terminate the concatenated archive.
                header = _header(".PKGINFO")
                header.size = len(metadata_bytes)
                stream.write(header.tobuf(format=tarfile.USTAR_FORMAT))
                stream.write(metadata_bytes)
                stream.write(b"\0" * (-len(metadata_bytes) % tarfile.BLOCKSIZE))
            with data_path.open("rb") as data:
                while chunk := data.read(1024 * 1024):
                    package.write(chunk)
        os.replace(package_path, output)
