#!/usr/bin/env python3
"""Package an already compiled ARM64 iOS .app. This never substitutes for a build."""
import os
from pathlib import Path
import plistlib
import stat
import struct
import sys
import zipfile

app = Path(sys.argv[1]).resolve()
destination = Path(sys.argv[2]).resolve()
if not app.is_dir() or app.suffix != '.app':
    raise SystemExit('Expected an actual compiled iOS .app directory')
with (app / 'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
binary = app / info['CFBundleExecutable']
with binary.open('rb') as stream:
    magic, cpu = struct.unpack('<II', stream.read(8))
if magic != 0xFEEDFACF or cpu != 0x0100000C:
    raise SystemExit('The app must contain a compiled 64-bit ARM device executable')
if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
    raise SystemExit('Refusing to package a simulator build as an iPhone IPA')
if not (app / 'Assets.car').is_file():
    raise SystemExit('Compiled asset catalog, including app icon, is missing')
destination.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(app.rglob('*')):
        relative = Path('Payload') / app.name / file.relative_to(app)
        if file.is_symlink():
            entry = zipfile.ZipInfo(relative.as_posix())
            entry.create_system = 3
            entry.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(entry, os.readlink(file))
        elif file.is_file():
            archive.write(file, relative.as_posix())
with zipfile.ZipFile(destination) as archive:
    if archive.testzip() is not None:
        raise SystemExit('IPA failed archive integrity validation')
print(f'Created unsigned device IPA: {destination.name} ({destination.stat().st_size:,} bytes)')
print('A valid Apple signing identity and installation method are required before use on an iPhone.')
