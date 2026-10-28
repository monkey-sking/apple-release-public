"""Real index/history checks and private-environment loading, without signing."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1",
                        GIT_CONFIG_GLOBAL=os.devnull)
        for name in ("scripts", ".githooks", "lib", "bin", "config"):
            shutil.copytree(ROOT / name, self.repo / name)
        for p in (self.repo / ".githooks").iterdir():
            p.chmod(0o755)
        self.git("init", "-q")
        self.git("config", "user.name", "Publication test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "core.hooksPath", ".githooks")
        self.git("add", ".")
        self.git("commit", "-qm", "Safe baseline")

    def git(self, *args, check=True):
        return subprocess.run(["git", *args], cwd=self.repo, env=self.env,
                              text=True, capture_output=True, check=check)

    def stage(self, name, text):
        p = self.repo / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        self.git("add", "-f", name)
        return p

    def test_private_shared_and_project_files_are_blocked(self):
        for name in ("config/shared.env", "config/projects/myapp.env"):
            with self.subTest(name=name):
                self.stage(name, "export SETTING=value\n")
                result = self.git("commit", "-qm", "Private", check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("private staged path", result.stderr)
                self.git("update-index", "--force-remove", name)

    def test_private_link_is_blocked(self):
        (self.repo / "config/shared.env").symlink_to("/private/shared.env")
        self.git("add", "-f", "config/shared.env")
        self.assertNotEqual(self.git("commit", "-qm", "Link", check=False).returncode, 0)

    def test_staged_key_cannot_be_hidden_by_worktree(self):
        key = "AQ." + "aB7cD9" * 9
        p = self.stage("settings.txt", key)
        p.write_text("safe")
        result = self.git("commit", "-qm", "Hidden key", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(key, result.stderr)

    def test_deleted_historical_config_blocks_push(self):
        self.stage("config/shared.env", "export SETTING=value\n")
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "Unsafe")
        self.git("rm", "config/shared.env")
        self.git("commit", "-qm", "Delete tip")
        sha = self.git("rev-parse", "HEAD").stdout.strip()
        result = subprocess.run(
            ["sh", ".githooks/pre-push", "origin", "unused"],
            input=f"refs/heads/main {sha} refs/heads/main {'0' * 40}\n",
            cwd=self.repo, env=self.env, text=True, capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private historical path", result.stderr)

    def test_private_shared_link_and_project_override_load(self):
        private = self.repo / "fixture-private"
        private.mkdir()
        (private / "shared.env").write_text("export FIXTURE_SHARED=loaded\n")
        (private / "example.env").write_text("export FIXTURE_PROJECT=loaded\n")
        (self.repo / "config/shared.env").symlink_to(private / "shared.env")
        (self.repo / "config/projects/example.env").symlink_to(private / "example.env")
        result = subprocess.run(
            ["bash", "-c", 'source "$APPLE_RELEASE_HOME/lib/common.sh"; '
             'apple_release_load_project_env example >/dev/null; '
             'test "$FIXTURE_SHARED:$FIXTURE_PROJECT" = loaded:loaded'],
            env=dict(self.env, APPLE_RELEASE_HOME=str(self.repo)),
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_fingerprint_fails_before_security_calls(self):
        command = (
            'source "$APPLE_RELEASE_HOME/lib/ios-testflight.sh"; '
            'security() { echo SECURITY_CALLED; }; apple_release_ios_preflight'
        )
        result = subprocess.run(
            ["bash", "-c", command],
            env=dict(self.env, APPLE_RELEASE_HOME=str(self.repo),
                     APPLE_DISTRIBUTION_FINGERPRINT=""),
            text=True, capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Configure APPLE_DISTRIBUTION_FINGERPRINT", result.stderr)
        self.assertNotIn("SECURITY_CALLED", result.stdout)

    def test_bootstrap_escapes_profile_and_rejects_path_traversal(self):
        marker = self.repo / "should-not-exist"
        profile = f'Profile "$(touch {marker})"'
        env = dict(self.env, APPLE_RELEASE_HOME=str(self.repo))
        result = subprocess.run(
            ["bash", str(self.repo / "bin/bootstrap-project-config.sh"),
             "example", "ios-testflight", "com.example.app", profile],
            env=env, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        subprocess.run(["bash", "-c", 'source "$1"', "fixture",
                        str(self.repo / "config/projects/example.env")],
                       check=True, env=env)
        self.assertFalse(marker.exists())
        self.assertEqual((self.repo / "config/projects/example.env").stat().st_mode & 0o777, 0o600)
        result = subprocess.run(
            ["bash", str(self.repo / "bin/bootstrap-project-config.sh"),
             "../escape", "ios-testflight", "com.example.app"],
            env=env, capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.repo / "config/escape.env").exists())


if __name__ == "__main__":
    unittest.main()
