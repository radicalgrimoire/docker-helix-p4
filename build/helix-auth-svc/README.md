# Building the Helix Authentication Service Image

This directory builds the Perforce Helix Authentication Service (HAS) image from the official Perforce APT package. It does not use the published `perforce/helix-auth-svc` image.

## Package installation

The Dockerfile follows the same Ubuntu Noble and Perforce APT repository setup as the Helix Core image. It installs the latest `helix-auth-svc` package available when the image is built:

```bash
apt-get install helix-auth-svc
```

`.env` defines the local image name only. It contains no SAML, Azure Entra ID, certificate, or other runtime configuration. The package installs HAS and its Node.js runtime under `/opt/perforce/helix-auth-svc`. The image starts the package's `bin/www.js` directly rather than starting a systemd service.

The official "Easy way to install Node.js" instructions apply to manual HAS installations. Do not install Node.js separately in this image: the version-pinned `helix-auth-svc` package includes its compatible Node.js runtime and service dependencies.

## Build

From the repository root:

```bash
bash build/helix-auth-svc/docker-build.sh Dockerfile ./build/helix-auth-svc
```

## Test

After building, verify that HAS is installed and that its bundled Node.js runtime starts:

```bash
bash build/helix-auth-svc/docker-test.sh ./build/helix-auth-svc
```

Runtime configuration and Docker Compose deployment are intentionally not included yet.

## Experimental vulnerability scan

When the [build workflow](../../.github/workflows/build-develop.yml) builds
`helix-auth-svc`, it calls the reusable [scan workflow](../../.github/workflows/scan.yml)
as an independent job after testing. The scan downloads the saved Docker image
artifact and scans the archive with Trivy in parallel with version detection.
Publishing waits for both jobs. For other images, the scan is skipped and
publishing proceeds after version detection. Test-only workflows do not call the
scan workflow.

The Trivy action is pinned to a commit and the scanner to an explicit version.
The scan reports OS and language-package vulnerabilities at all severities,
including those without a fix. Findings do not block publishing during this
trial, but scanner errors do fail the job.

### Scan summary and optional Gemini formatting

AI formatting is disabled by default. The `Summarize scan` step prints exact
Trivy counts and a collapsible findings table to the Actions run Summary and
step log, without calling Gemini or requiring an API key. No report artifact is
uploaded.

The Gemini integration is retained for later use. To enable it, set
`ai_summary: true` in the scan workflow caller's `with` block and register a
repository Actions secret named `GEMINI_API_KEY`. Optionally set the
repository Actions variable `GEMINI_MODEL` (default: `gemini-2.5-flash`) to choose
an available Gemini text model supporting structured JSON output.

Only when AI formatting is enabled, [the Python report script](../../scripts/summarize_trivy.py)
sends only OS family/version, finding counts, detected language-package target
count, and package vulnerability fields (package name, CVE/advisory ID, severity,
installed/fixed versions, title, and package type) to the Google Gemini API.
Source code, image contents, environment variables, file paths, and the complete
Trivy metadata are not sent. Gemini API usage is subject to Google's pricing and
data-use terms.

When enabled, Gemini adds an AI-generated Japanese overview,
grouped issue highlights, and reporting notes. Gemini only reformats the supplied
findings; it is not asked for independent risk assessments or remediation advice.
Counts are per package/vulnerability pair, not unique CVEs. AI summaries require
human review and do not establish exploitability or safety. No report artifact is
uploaded.

When AI formatting is enabled, missing API credentials, API errors, or invalid AI output fail the scan job and
block publishing; the deterministic Trivy summary remains available if AI
generation fails. No Docker Hub credentials or Code scanning upload permissions
are required. Only the summarization step receives `GEMINI_API_KEY`, and only
when AI formatting is enabled. To enable AI formatting when running the script
directly, set `ENABLE_AI_SUMMARY=true` along with `GEMINI_API_KEY`.

The script uses only the Python standard library; no pip installation is needed.
Run its offline tests with:

```bash
python3 -B -m unittest discover -s scripts -p 'test_summarize_trivy.py'
```
