#!/usr/bin/env python3
"""PTY regression tests for Strawberry's protected rm wrapper."""
import os
import pathlib
import pty
import select
import signal
import tempfile
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
WRAPPER = ROOT / 'rootfs/usr/local/bin/rm'


class RmTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.wrapper = pathlib.Path(cls.temp.name) / 'rm'
        source = WRAPPER.read_text()
        assert 'real_rm=/bin/rm\n' in source
        cls.wrapper.write_text(source.replace('real_rm=/bin/rm\n', 'real_rm=/bin/echo\n', 1))
        cls.wrapper.chmod(0o755)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def run_pty(self, args, answers=b'', expected_prompts=0):
        pid, fd = pty.fork()
        if pid == 0:
            os.execv(str(self.wrapper), [str(self.wrapper), *args])
        data = bytearray()
        sent = 0
        status = None
        deadline = time.monotonic() + 8
        try:
            while time.monotonic() < deadline:
                readable, _, _ = select.select([fd], [], [], 0.05)
                if readable:
                    try:
                        chunk = os.read(fd, 65536)
                    except OSError:
                        chunk = b''
                    if chunk:
                        data.extend(chunk)
                count = data.count(b'Type y to continue:')
                while sent < min(count, len(answers)):
                    os.write(fd, answers[sent:sent + 1] + b'\n')
                    sent += 1
                done, result = os.waitpid(pid, os.WNOHANG)
                if done:
                    status = result
                    break
            if status is None:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
                self.fail('rm wrapper timed out')
        finally:
            os.close(fd)
        self.assertEqual(data.count(b'Type y to continue:'), expected_prompts, data.decode(errors='replace'))
        return os.waitstatus_to_exitcode(status), bytes(data)

    def test_protected_paths(self):
        for path in ('/', '/etc', '/usr/../etc/', '/*', '/etc\n'):
            with self.subTest(path=repr(path)):
                code, output = self.run_pty(['--recursive', '--', path], b'yyyyy', 5)
                self.assertEqual(code, 0, output)

    def test_abort_on_no(self):
        code, output = self.run_pty(['-r', '/etc'], b'n', 1)
        self.assertEqual(code, 2, output)

    def test_forbidden_options(self):
        for flag in ('--no-preserve-root', '--unknown', '-Z'):
            with self.subTest(flag=flag):
                code, output = self.run_pty(['-r', flag, '/etc'], b'', 0)
                self.assertEqual(code, 2, output)

    def test_nested_path_without_prompt(self):
        code, output = self.run_pty(['-r', '--', '/some/nested/name'], b'', 0)
        self.assertEqual(code, 0, output)

    def test_nonrecursive_without_prompt(self):
        code, output = self.run_pty(['--', '/etc'], b'', 0)
        self.assertEqual(code, 0, output)


if __name__ == '__main__':
    unittest.main()
