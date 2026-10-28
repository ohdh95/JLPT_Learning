import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from package_artifacts import source_files


class SourcePackagingTest(unittest.TestCase):
    def test_only_tracked_public_files_are_packaged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'README.md').write_text('public')
            (root / 'key.properties').write_text('private')
            (root / 'user.db').write_text('private')
            subprocess.run(['git', 'add', 'README.md'], cwd=root, check=True)
            self.assertEqual([str(rel) for _, rel in source_files(root)], ['README.md'])

    def test_accidentally_tracked_secrets_block_packaging(self):
        for name in ['key.properties', 'release.jks', 'user.db', '.env.production']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                subprocess.run(['git', 'init', '-q', str(root)], check=True)
                (root / name).write_text('private')
                subprocess.run(['git', 'add', name], cwd=root, check=True)
                with self.assertRaises(ValueError):
                    list(source_files(root))


if __name__ == '__main__':
    unittest.main()
