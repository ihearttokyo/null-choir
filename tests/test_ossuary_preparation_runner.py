"""Strict earned preparation receipts; all subprocess and timing evidence is simulated."""
from pathlib import Path
import contextlib
import importlib.util
import io
import runpy
import subprocess
import sys
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location("ossuary_preparation_runner", TOOLS / "check_ossuary_preparation.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
TEST_TMP = Path(runner.tempfile.gettempdir())

PASS = "PASS bounded earned Ossuary saved checkpoint/original gate preparation; synthetic native input, not finale/app acceptance"
READY = "OSSUARY_PREPARATION_OMITTED_GATE_READY checkpoint_saved=true gate_live=true finale_dormant=true prior_frozen=true"
ERROR = "ERROR: OSSUARY_WITNESS NATIVE RED preparation requires queued rebound E original gate after saved checkpoint"
SECOND = 'OSSUARY_SECOND_EARNED frames=2589 shots=56 prior_frozen=true'
STORY = 'OSSUARY_STORY_EARNED frames=2564 discoveries=[3, 4, 5] prior_frozen=true'
PREPARATION = 'OSSUARY_PREPARATION_EARNED frames=400 resources={} captures=2 saves=1 gate=1 prior_frozen=true'


def transcript(omit=False, fixed=False):
    # Complete synthetic merged streams, never native acceptance evidence.
    return "\n".join([
        "Godot Engine (synthetic fixture)", "PASS inherited earned route", SECOND, STORY,
        *([READY, ERROR] if omit else [PREPARATION.replace("400", "401" if fixed else "400"), PASS]),
        "Godot shutdown complete",
    ]) + "\n"


def result(output=None, code=0):
    return subprocess.CompletedProcess(["godot"], code, transcript() if output is None else output)


class ReceiptBoundary(unittest.TestCase):
    def test_full_normal_and_fixed_positive(self):
        for fixed in (False, True):
            with self.subTest(fixed=fixed):
                self.assertTrue(runner.accepted(result(transcript(fixed=fixed))))

    def test_expected_omission(self):
        self.assertTrue(runner.accepted(result(transcript(omit=True), 1), omit_gate=True))

    def test_expected_omission_keeps_benign_godot_backtrace(self):
        trace = "   at: push_error (core/variant/variant_utility.cpp:1023)\n"
        trace += "   GDScript backtrace (most recent call first):\n"
        trace += "       [0] require (res://tests/ossuary_transport_witness.gd:79)\n"
        self.assertTrue(runner.accepted(result(transcript(True) + trace, 1), omit_gate=True))

    def test_benign_parser_and_assertion_receipts_are_not_diagnostics(self):
        self.assertTrue(runner.accepted(result(transcript() + "PASS parser and assertion coverage\n")))

    def test_shared_positive_core_is_required(self):
        with patch.object(runner, "accepted_clean", return_value=False) as core:
            self.assertFalse(runner.accepted(result()))
        core.assert_called_once()

    def test_missing_or_duplicate_positive_markers(self):
        for marker in (PASS, PREPARATION, STORY, SECOND):
            for output in (transcript().replace(marker + "\n", ""), transcript() + marker + "\n"):
                with self.subTest(marker=marker, output=output):
                    self.assertFalse(runner.accepted(result(output)))

    def test_inexact_positive_markers(self):
        for marker in (PASS, PREPARATION, STORY, SECOND):
            for replacement in (" " + marker, "prefix " + marker, marker.replace(" ", "_", 1)):
                with self.subTest(marker=marker, replacement=replacement):
                    self.assertFalse(runner.accepted(result(transcript().replace(marker, replacement))))
        self.assertFalse(runner.accepted(result(transcript().replace(PASS, PASS + " extra"))))
        self.assertFalse(runner.accepted(result(transcript() + PASS + " extra\n")))
        self.assertFalse(runner.accepted(result(transcript() + "OSSUARY_STORY_EARNED_extra frames=1\n")))
        self.assertFalse(runner.accepted(result(transcript() + "OSSUARY_SECOND_EARNED_extra frames=1\n")))

    def test_malformed_or_mixed_reserved_markers(self):
        for marker in (SECOND, STORY, PREPARATION):
            malformed = (
                marker.replace("frames=", "frames=garbage"),
                marker.replace("frames=", "frames=-"),
                marker.replace("prior_frozen=true", "prior_frozen=false"),
                marker + " extra",
                marker.lower(),
                "prefix " + marker,
            )
            for bad in malformed:
                for output in (transcript().replace(marker, bad), transcript() + bad + "\n"):
                    with self.subTest(marker=marker, bad=bad, output=output):
                        self.assertFalse(runner.accepted(result(output)))
        for omit in (False, True):
            for marker in ("OSSUARY_STORY_OMITTED_READY marker_live=true",
                           "OSSUARY_SECOND_OMITTED_READY prior_frozen=true",
                           READY.lower(), READY + " extra", PASS.lower()):
                with self.subTest(omit=omit, marker=marker):
                    self.assertFalse(runner.accepted(result(transcript(omit) + marker + "\n", 1 if omit else 0), omit_gate=omit))

    def test_payload_values_are_not_claimed_as_numeric_proof(self):
        output = transcript().replace("frames=400", "frames=12345").replace("resources={}", "resources={ synthetic_variable_payload }")
        self.assertTrue(runner.accepted(result(output)))

    def test_only_expected_exit_is_accepted(self):
        for code in (-9, 1, 2):
            with self.subTest(mode="positive", code=code):
                self.assertFalse(runner.accepted(result(code=code)))
        for code in (-9, 0, 2):
            with self.subTest(mode="omitted", code=code):
                self.assertFalse(runner.accepted(result(transcript(True), code), omit_gate=True))

    def test_empty_and_unrelated_pass_are_rejected(self):
        for output in ("", "PASS unrelated\n", transcript().replace(PASS, "PASS unrelated")):
            with self.subTest(output=output):
                self.assertFalse(runner.accepted(result(output)))

    def test_omission_requires_exact_readiness_error_and_completed_prefix(self):
        output = transcript(True)
        for marker in (READY, ERROR, SECOND, STORY):
            for changed in (output.replace(marker + "\n", ""), output + marker + "\n", output.replace(marker, marker + " extra")):
                with self.subTest(marker=marker, output=changed):
                    self.assertFalse(runner.accepted(result(changed, 1), omit_gate=True))
        for bad_ready in (READY.replace("true", "false", 1), " " + READY):
            self.assertFalse(runner.accepted(result(output.replace(READY, bad_ready), 1), omit_gate=True))

    def test_wrong_early_bound_error_is_not_expected_omission(self):
        wrong = "ERROR: OSSUARY_WITNESS Story bounded route exhausted before interaction"
        self.assertFalse(runner.accepted(result(transcript(True).replace(ERROR, wrong), 1), omit_gate=True))
        self.assertFalse(runner.accepted(result(transcript(True) + wrong + "\n", 1), omit_gate=True))
        actual_bound = "ERROR: OSSUARY_WITNESS unchanged map and bounded new Story clock"
        self.assertFalse(runner.accepted(result(transcript(True).replace(ERROR, actual_bound), 1), omit_gate=True))
        self.assertFalse(runner.accepted(result(transcript(True) + actual_bound + "\n", 1), omit_gate=True))

    def test_modes_cannot_claim_each_others_receipts(self):
        for forbidden in (PREPARATION, PASS, PASS + " extra", "OSSUARY_PREPARATION_EARNED_extra frames=1"):
            with self.subTest(forbidden=forbidden):
                self.assertFalse(runner.accepted(result(transcript(True) + forbidden + "\n", 1), omit_gate=True))
        self.assertFalse(runner.accepted(result(transcript() + READY + "\n")))
        self.assertFalse(runner.accepted(result(transcript(True))))
        self.assertFalse(runner.accepted(result(transcript(), 1), omit_gate=True))

    def test_all_unexpected_diagnostics_before_or_after_completion(self):
        diagnostics = (
            "ERROR: unrelated engine failure", "error: shutdown failure",
            "SCRIPT ERROR: Invalid access", "WARNING: startup failed",
            "warning: unrelated shutdown warning", "Parse Error: unexpected token",
            "PARSE_ERROR invalid syntax", "Assertion failed: invariant",
            "ASSERT FAILED: invariant", "assertion failure during shutdown",
            "WARNING: ObjectDB instances leaked at exit", "ObjectDB instances leaked at exit",
            "WARNING: 1 resources still in use at exit", "1 resources still in use at exit",
            "1 resource still in use at exit", "resource-use diagnostic",
        )
        for omit in (False, True):
            for diagnostic in diagnostics:
                for late in (False, True):
                    output = transcript(omit)
                    output = output + diagnostic + "\n" if late else diagnostic + "\n" + output
                    with self.subTest(omit=omit, diagnostic=diagnostic, late=late):
                        self.assertFalse(runner.accepted(result(output, 1 if omit else 0), omit_gate=omit))


class CommandBoundary(unittest.TestCase):
    def run_main(self, argv, output=None, code=0, failure=None, lang="C.UTF-8"):
        homes = []
        command_calls = []

        def completed(command, **kwargs):
            command_calls.append((command, kwargs))
            env = kwargs["env"]
            self.assertEqual(set(env), {
                "PATH", "LANG", "HOME", "TMPDIR", "TMP", "TEMP",
                "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
            })
            self.assertEqual(env["PATH"], "/opt/homebrew/bin:/usr/bin:/bin")
            self.assertEqual(env["LANG"], "en_US.UTF-8" if lang is None else lang)
            home = Path(env["HOME"])
            homes.append(home)
            self.assertTrue(home.is_dir())
            self.assertEqual(home.parent, TEST_TMP)
            for key, folder in (("TMPDIR", "tmp"), ("TMP", "tmp"), ("TEMP", "tmp"),
                                ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                                ("XDG_CACHE_HOME", "cache")):
                self.assertEqual(Path(env[key]), home / folder)
                self.assertTrue(Path(env[key]).is_dir())
            self.assertEqual(kwargs["stdout"], subprocess.PIPE)
            self.assertEqual(kwargs["stderr"], subprocess.STDOUT)
            self.assertIs(kwargs["text"], True)
            if failure is not None:
                raise failure
            return result(output, code)

        parent_env = {
            "PATH": "/unmanaged/bin", "LANG": "C.UTF-8", "HOME": "/user-home",
            "XDG_CACHE_HOME": "/user-cache", "TMPDIR": "/user-tmp",
            "DYLD_INSERT_LIBRARIES": "not-inherited", "LD_PRELOAD": "not-inherited",
            "OPENAI_API_KEY": "not-inherited", "AUTH_TOKEN": "not-inherited",
            "PYTHONPATH": "not-inherited", "PYTHONHOME": "not-inherited",
        }
        if lang is None:
            parent_env.pop("LANG")
        else:
            parent_env["LANG"] = lang
        captured = io.StringIO()
        with patch.dict(runner.os.environ, parent_env, clear=True), \
             patch.object(runner.shutil, "which", return_value="/opt/homebrew/bin/godot") as which, \
             patch.object(runner.subprocess, "run", side_effect=completed) as run, \
             contextlib.redirect_stdout(captured):
            returned = runner.main(argv)
        which.assert_called_once_with("godot", path="/opt/homebrew/bin:/usr/bin:/bin")
        run.assert_called_once()
        self.assertTrue(homes)
        self.assertTrue(all(not home.exists() for home in homes))
        return returned, command_calls[0], captured.getvalue()

    def test_default_normal_timing_and_complete_output(self):
        returned, (command, kwargs), output = self.run_main([])
        self.assertEqual(returned, 0)
        self.assertEqual(command, [
            "/opt/homebrew/bin/godot", "--headless", "--audio-driver", "CoreAudio",
            "--path", str(runner.ROOT / "game"), "--script", "res://tests/test_ossuary_finale_preparation.gd",
        ])
        self.assertEqual(kwargs["timeout"], 1800)
        self.assertIn(transcript(), output)
        self.assertIn("PASS strict Ossuary preparation runner", output)

    def test_only_requested_fixed_and_omission_flags(self):
        for fixed, omit in ((True, False), (False, True), (True, True)):
            with self.subTest(fixed=fixed, omit=omit):
                argv = ["--timeout", "42.5"]
                if fixed:
                    argv.append("--fixed-fps")
                if omit:
                    argv.append("--omit-gate")
                returned, (command, kwargs), _ = self.run_main(
                    argv, transcript(omit, fixed), 1 if omit else 0)
                self.assertEqual(returned, 0)
                self.assertEqual(kwargs["timeout"], 42.5)
                base = ["/opt/homebrew/bin/godot", "--headless", "--audio-driver", "CoreAudio",
                        "--path", str(runner.ROOT / "game"), "--script", "res://tests/test_ossuary_finale_preparation.gd"]
                self.assertEqual(command, base + (["--fixed-fps", "60"] if fixed else [])
                                 + (["--", "--omit-ossuary-preparation-gate"] if omit else []))

    def test_late_shutdown_diagnostic_rejects_and_cleans_profile(self):
        for omit in (False, True):
            with self.subTest(omit=omit):
                late = transcript(omit) + "WARNING: late shutdown diagnostic\n"
                returned, _, output = self.run_main(["--omit-gate"] if omit else [], late, 1 if omit else 0)
                self.assertEqual(returned, 1)
                self.assertIn(late, output)
                self.assertNotIn("PASS strict Ossuary preparation runner", output)

    def test_timeout_even_after_pass_and_launch_failure_clean_profile(self):
        for failure in (
            subprocess.TimeoutExpired(["godot"], 1, output=transcript().encode()),
            subprocess.TimeoutExpired(["godot"], 1, output=transcript()),
            subprocess.TimeoutExpired(["godot"], 1),
            OSError("simulated launch failure"),
        ):
            with self.subTest(failure=type(failure).__name__):
                returned, _, output = self.run_main([], failure=failure)
                self.assertEqual(returned, 1)
                self.assertIn("FAIL Ossuary preparation:", output)
                self.assertNotIn("PASS strict Ossuary preparation runner", output)
                if isinstance(failure, subprocess.TimeoutExpired) and failure.stdout:
                    self.assertIn(transcript(), output)

    def test_wrong_exit_rejects_at_public_boundary(self):
        returned, _, output = self.run_main([], code=1)
        self.assertEqual(returned, 1)
        self.assertNotIn("PASS strict Ossuary preparation runner", output)

    def test_locale_fallback_is_the_only_inherited_environment_option(self):
        for lang in (None, "en_GB.UTF-8"):
            with self.subTest(lang=lang):
                returned, _, _ = self.run_main([], lang=lang)
                self.assertEqual(returned, 0)

    def test_module_entrypoint_returns_failed_lookup_exit(self):
        with patch.object(sys, "argv", [str(TOOLS / "check_ossuary_preparation.py")]), \
             patch.object(runner.shutil, "which", return_value=None), \
             patch.object(runner.subprocess, "run") as run, \
             contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                runpy.run_path(str(TOOLS / "check_ossuary_preparation.py"), run_name="__main__")
        self.assertEqual(error.exception.code, 1)
        run.assert_not_called()

    def test_missing_managed_godot_does_not_launch(self):
        with patch.object(runner.shutil, "which", return_value=None), \
             patch.object(runner.subprocess, "run") as run, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main([]), 1)
        run.assert_not_called()

    def test_invalid_timeouts_and_unrequested_options_fail_before_launch(self):
        cases = [["--timeout=" + value] for value in ("0", "-1", "nan", "NaN", "inf", "-inf", "1e999", "text")]
        cases += [["--engine", "godot"], ["--fixed-fps", "60"], ["--omit-interact"], ["--omit-g"], ["--fixed"], ["other-script.gd"]]
        for argv in cases:
            with self.subTest(argv=argv), \
                 patch.object(runner.shutil, "which") as which, \
                 patch.object(runner.subprocess, "run") as run, \
                 contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    runner.main(argv)
                self.assertEqual(error.exception.code, 2)
                which.assert_not_called()
                run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
