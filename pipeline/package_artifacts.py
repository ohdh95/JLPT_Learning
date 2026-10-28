"""Package built APKs and portable source; verify embedded DB and ZIP round trips.

Run after copying universal and arm64 build outputs to dist. Signing checks and
device tests are separate; this tool does not claim to perform either.
"""
import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def stream_sha(stream):
    digest = hashlib.sha256()
    for chunk in iter(lambda: stream.read(1024 * 1024), b''):
        digest.update(chunk)
    return digest.hexdigest()


def sha(path):
    with path.open('rb') as f:
        return stream_sha(f)


def source_files(root):
    """Package only explicitly tracked source, never workstation/private files."""
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
    forbidden_names = {'key.properties', 'local.properties', '.env', 'user.db'}
    forbidden_suffixes = {'.jks', '.keystore', '.p12', '.pem', '.apk', '.aab'}
    for name in sorted(filter(None, tracked)):
        rel = Path(name)
        if (rel.name in forbidden_names or rel.suffix in forbidden_suffixes
                or rel.name.startswith('.env.') or rel.name.startswith('user.db-')
                or set(rel.parts) & {'dist', 'downloads', 'build', 'backups'}):
            raise ValueError(f'Private/generated file must not be tracked: {name}')
        path = root / rel
        if not path.is_symlink() and path.is_file():
            yield path, rel


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', action='store_true', help='Package signed release APKs')
    args = parser.parse_args()
    mode = 'release' if args.release else 'debug'
    dist = ROOT / 'dist'
    version = re.search(r'^version: (.+)$', (ROOT / 'pubspec.yaml').read_text(), re.M)[1]
    content_hash = sha(ROOT / 'assets/content.sqlite')
    files = []
    reports = []
    for name, expected in [
        (f'jlpt-study-{mode}.apk', {'arm64-v8a', 'armeabi-v7a', 'x86_64'}),
        (f'jlpt-study-arm64-{mode}.apk', {'arm64-v8a'}),
    ]:
        apk = dist / name
        with zipfile.ZipFile(apk) as archive:
            assert archive.testzip() is None, 'APK CRC failure'
            embedded = archive.read('assets/flutter_assets/assets/content.sqlite')
            assert hashlib.sha256(embedded).hexdigest() == content_hash, 'Stale APK content'
            abis = {p.split('/')[1] for p in archive.namelist() if p.startswith('lib/') and p.endswith('.so')}
            assert abis == expected, (name, abis)
        packed = apk.with_suffix('.apk.zip')
        with zipfile.ZipFile(packed, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            archive.write(apk, apk.name)
        with zipfile.ZipFile(packed) as archive:
            assert archive.testzip() is None
            with archive.open(apk.name) as stream:
                assert stream_sha(stream) == sha(apk)
        reports.append(dict(file=name, version=version, bytes=apk.stat().st_size,
                            sha256=sha(apk), content_db_matches=True,
                            abis=sorted(abis), zip_bytes=packed.stat().st_size,
                            zip_roundtrip_verified=True))
        files += [apk, packed]
    (ROOT / 'reports/artifacts.json').write_text(json.dumps(reports, indent=2) + '\n')
    source = dist / 'jlpt-study-source.zip'
    included = list(source_files(ROOT))
    if not included:
        raise RuntimeError('No tracked source. Stage the public source in Git first.')
    with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path, rel in included:
            archive.write(path, str(Path('jlpt_study') / rel))
    with zipfile.ZipFile(source) as archive:
        assert archive.testzip() is None
    files.append(source)
    (dist / 'SHA256SUMS.txt').write_text(''.join(f'{sha(p)}  {p.name}\n' for p in files))
    print(json.dumps(reports, indent=2))
    print('Source ZIP:', source.stat().st_size, 'bytes; all CRC/hash checks passed.')


if __name__ == '__main__':
    main()
