from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

import summarize_trivy as summary


def fixture():
    return {
        "SchemaVersion": 2,
        "Metadata": {"OS": {"Family": "ubuntu", "Name": "24.04"}, "Env": ["SECRET=do-not-send"]},
        "Results": [{
            "Target": "/private/source/path",
            "Class": "os-pkgs",
            "Type": "ubuntu",
            "Vulnerabilities": [{
                "PkgName": "libexample",
                "VulnerabilityID": "CVE-2026-1234",
                "Severity": "HIGH",
                "InstalledVersion": "1.0",
                "FixedVersion": "1.1",
                "Title": "Example issue",
                "Description": "do-not-send-description",
            }],
        }],
    }


def ai_report():
    return {
        "overview": "Test overview",
        "highlights": ["One affected package"],
        "notes": ["Not an exploitability assessment"],
    }


def response(report=None, *, text=None, finish_reason="STOP"):
    if text is None:
        text = json.dumps(ai_report() if report is None else report)
    return io.BytesIO(json.dumps({
        "candidates": [{
            "finishReason": finish_reason,
            "content": {"parts": [{"text": text}]},
        }],
    }).encode("utf-8"))


class ReportTests(unittest.TestCase):
    def test_only_allowlisted_data_is_collected(self):
        data = summary.collect_report(fixture())
        self.assertEqual(data["counts"], {
            "CRITICAL": 0, "HIGH": 1, "MEDIUM": 0, "LOW": 0, "UNKNOWN": 0,
        })
        self.assertEqual(data["language_targets"], 0)
        self.assertEqual(data["findings"][0]["fixed"], "1.1")
        for excluded in ("SECRET", "do-not-send", "/private/source/path", "Description"):
            self.assertNotIn(excluded, json.dumps(data))

    def test_repeated_cves_unfixed_packages_and_language_targets(self):
        report = fixture()
        report["Results"].append({
            "Class": "lang-pkgs", "Type": "npm",
            "Vulnerabilities": [{
                "PkgName": "example", "VulnerabilityID": "CVE-2026-1234",
                "Severity": "HIGH", "InstalledVersion": "2",
            }],
        })
        data = summary.collect_report(report)
        self.assertEqual(data["counts"]["HIGH"], 2)
        self.assertEqual(data["language_targets"], 1)
        self.assertEqual(data["findings"][1]["fixed"], "")
        self.assertIn("Not listed", summary.render_facts(data))

    def test_clean_report(self):
        data = summary.collect_report({"SchemaVersion": 2, "Results": []})
        self.assertEqual(data["findings"], [])
        self.assertEqual(sum(data["counts"].values()), 0)
        self.assertIn("Zero targets does not mean", summary.render_facts(data))

    def test_invalid_trivy_report(self):
        with self.assertRaisesRegex(ValueError, "schema v2"):
            summary.collect_report({})
        report = fixture()
        report["Results"][0]["Vulnerabilities"][0]["Severity"] = "INVALID"
        with self.assertRaisesRegex(ValueError, "severity"):
            summary.collect_report(report)

    def test_api_request_uses_header_and_only_filtered_data(self):
        data = summary.collect_report(fixture())
        with patch.object(summary, "urlopen", return_value=response()) as mock:
            result = summary.request_report(data, "test-key")
        request = mock.call_args.args[0]
        self.assertTrue(request.full_url.endswith("/gemini-2.5-flash:generateContent"))
        self.assertEqual(request.get_header("X-goog-api-key"), "test-key")
        self.assertNotIn("test-key", request.full_url)
        self.assertNotIn(b"test-key", request.data)
        body = json.loads(request.data)
        self.assertEqual(body["generationConfig"]["responseMimeType"], "application/json")
        self.assertEqual(json.loads(body["contents"][0]["parts"][0]["text"]), data)
        self.assertEqual(mock.call_args.kwargs["timeout"], 120)
        self.assertEqual(result, ai_report())

    def test_missing_credentials_and_invalid_model_do_not_call_api(self):
        with patch.object(summary, "urlopen") as mock:
            with self.assertRaisesRegex(ValueError, "GEMINI_API_KEY"):
                summary.request_report({}, "")
            with self.assertRaisesRegex(ValueError, "GEMINI_MODEL"):
                summary.request_report({}, "test-key", "../invalid")
        mock.assert_not_called()

    def test_http_error_does_not_expose_response_contents(self):
        error = HTTPError("https://example.invalid", 429, "secret-response", {}, None)
        with patch.object(summary, "urlopen", side_effect=error):
            with self.assertRaisesRegex(RuntimeError, "^Gemini API returned HTTP 429.$"):
                summary.request_report({}, "test-key")

    def test_network_failure_and_timeout(self):
        for error in (URLError("secret-response"), TimeoutError()):
            with self.subTest(error=error), patch.object(summary, "urlopen", side_effect=error):
                with self.assertRaisesRegex(RuntimeError, "failed or timed out"):
                    summary.request_report({}, "test-key")

    def test_blocked_or_truncated_response(self):
        for reason in ("SAFETY", "MAX_TOKENS"):
            with self.subTest(reason=reason):
                with patch.object(summary, "urlopen", return_value=response(finish_reason=reason)):
                    with self.assertRaisesRegex(RuntimeError, "blocked or truncated"):
                        summary.request_report({}, "test-key")

    def test_invalid_report_structure(self):
        for report in ([], {"overview": "Test", "highlights": "invalid"}):
            with self.subTest(report=report):
                with patch.object(summary, "urlopen", return_value=response(report)):
                    with self.assertRaisesRegex(RuntimeError, "invalid report structure"):
                        summary.request_report({}, "test-key")

    def test_empty_or_invalid_json_response(self):
        for text, message in (("", "empty report"), ("not JSON", "invalid report JSON")):
            with self.subTest(text=text), patch.object(summary, "urlopen", return_value=response(text=text)):
                with self.assertRaisesRegex(RuntimeError, message):
                    summary.request_report({}, "test-key")
        with patch.object(summary, "urlopen", return_value=io.BytesIO(b"not JSON")):
            with self.assertRaisesRegex(RuntimeError, "API returned invalid JSON"):
                summary.request_report({}, "test-key")

    def test_untrusted_markdown_is_escaped(self):
        report = ai_report()
        report["overview"] = "<script>![image](https://example.com)</script>"
        report["highlights"] = ["a|b\nnew line"]
        rendered = summary.render_report(report)
        self.assertNotIn("<script>", rendered)
        self.assertNotIn("![image]", rendered)
        self.assertIn(r"a\|b new line", rendered)

    def test_main_writes_facts_and_summary_to_logs_and_actions_summary(self):
        with tempfile.TemporaryDirectory(prefix="trivy-summary-test-") as directory:
            input_path = Path(directory) / "report.json"
            summary_path = Path(directory) / "summary.md"
            input_path.write_text(json.dumps(fixture()), encoding="utf-8")
            output = io.StringIO()
            env = {
                "GEMINI_API_KEY": "test-key", "GEMINI_MODEL": summary.DEFAULT_MODEL,
                "GITHUB_STEP_SUMMARY": str(summary_path),
            }
            with patch.dict(os.environ, env), redirect_stdout(output):
                with patch.object(summary, "urlopen", return_value=response()):
                    summary.main([str(input_path)])
            markdown = summary_path.read_text(encoding="utf-8")
            self.assertEqual(markdown, output.getvalue())
            self.assertIn("| 0 | 1 | 0 | 0 | 0 |", markdown)
            self.assertIn("Test overview", markdown)
            self.assertIn("CVE-2026-1234", markdown)
            self.assertNotIn("test-key", markdown)

    def test_failed_generation_preserves_facts(self):
        with tempfile.TemporaryDirectory(prefix="trivy-summary-test-") as directory:
            input_path = Path(directory) / "report.json"
            summary_path = Path(directory) / "summary.md"
            input_path.write_text(json.dumps(fixture()), encoding="utf-8")
            env = {"GEMINI_API_KEY": "", "GITHUB_STEP_SUMMARY": str(summary_path)}
            with patch.dict(os.environ, env), redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(ValueError, "GEMINI_API_KEY"):
                    summary.main([str(input_path)])
            markdown = summary_path.read_text(encoding="utf-8")
            self.assertIn("CVE-2026-1234", markdown)
            self.assertIn("Gemini summary failed", markdown)


if __name__ == "__main__":
    unittest.main()
