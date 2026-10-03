#!/bin/bash

# Helix P4D SAML certificate download script.

set -e

# Show usage information.
show_usage() {
  cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -r, --repo REPO        GitHub repository (format: owner/repository)
  -t, --token TOKEN      GitHub token
  -d, --dir DIRECTORY    Download directory (default: ./certs)
  -y, --yes              Skip confirmation
  -h, --help             Show this help message

Environment variables:
  GITHUB_REPO           Repository name
  GITHUB_TOKEN          GitHub token
  CERT_DIR              Download directory

Examples:
  # Interactive mode
  $0

  # Specify values with arguments
  $0 -r owner/repo -t ghp_token -d ./certs

  # Specify values with environment variables
  export GITHUB_REPO="owner/repo"
  export GITHUB_TOKEN="ghp_token"
  $0 -y

EOF
  exit 0
}

# Parse arguments.
REPO=""
TOKEN=""
DOWNLOAD_DIR=""
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--repo)
      REPO="$2"
      shift 2
      ;;
    -t|--token)
      TOKEN="$2"
      shift 2
      ;;
    -d|--dir)
      DOWNLOAD_DIR="$2"
      shift 2
      ;;
    -y|--yes)
      SKIP_CONFIRM=true
      shift
      ;;
    -h|--help)
      show_usage
      ;;
    *)
      echo "Error: unknown option: $1"
      echo "Show help with: $0 --help"
      exit 1
      ;;
  esac
done

echo "==================================="
echo "Helix P4D SAML Certificate Download"
echo "==================================="
echo ""

# Configure the repository with the following precedence: arguments, environment variables, then interactive input.
if [ -z "${REPO}" ]; then
  if [ -n "${GITHUB_REPO}" ]; then
    REPO="${GITHUB_REPO}"
    echo "Repository: ${REPO} (from environment variable)"
  else
    echo "Enter the GitHub repository."
    echo "Format: owner/repository"
    read -p "Repository [radicalgrimoire/pfx-tools]: " input_repo
    REPO="${input_repo:-radicalgrimoire/pfx-tools}"
  fi
else
  echo "Repository: ${REPO} (from argument)"
fi

# Configure the download directory.
if [ -z "${DOWNLOAD_DIR}" ]; then
  if [ -n "${CERT_DIR}" ]; then
    DOWNLOAD_DIR="${CERT_DIR}"
    echo "Download directory: ${DOWNLOAD_DIR} (from environment variable)"
  else
    read -p "Download directory [./certs]: " input_dir
    DOWNLOAD_DIR="${input_dir:-./certs}"
  fi
else
  echo "Download directory: ${DOWNLOAD_DIR} (from argument)"
fi

# Configure the token.
if [ -z "${TOKEN}" ]; then
  if [ -n "${GITHUB_TOKEN}" ]; then
    TOKEN="${GITHUB_TOKEN}"
    echo "Authentication: token configured (from environment variable)"
  else
    echo ""
    echo "Enter the GitHub token. This is required for private repositories."
    echo "Create a token at: https://github.com/settings/tokens"
    echo "Required scope: repo"
    echo ""
    read -sp "GitHub token (input hidden): " input_token
    echo ""
    TOKEN="${input_token}"
    
    if [ -z "${TOKEN}" ]; then
      echo ""
      echo "Warning: no token was provided."
      read -p "Continue without a token? (y/N): " -n 1 -r
      echo ""
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
      fi
    fi
  fi
else
  echo "Authentication: token configured (from argument)"
fi

# Confirm the selected settings.
if [ "${SKIP_CONFIRM}" = false ]; then
  echo ""
  echo "--- Configuration ---"
  echo "Repository: ${REPO}"
  echo "Download directory: ${DOWNLOAD_DIR}"
  echo "Authentication: $([ -n "${TOKEN}" ] && echo "configured" || echo "not configured")"
  echo ""
  read -p "Continue with this configuration? (Y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi
echo ""

# Create the download directory.
mkdir -p "${DOWNLOAD_DIR}"

# Shared curl options.
CURL_OPTS="-L -f -s -S"

# Fetch the latest release.
echo "Fetching the latest release..."
if [ -n "${TOKEN}" ]; then
  RELEASE_INFO=$(curl ${CURL_OPTS} \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${REPO}/releases/latest" 2>&1)
else
  RELEASE_INFO=$(curl ${CURL_OPTS} \
    "https://api.github.com/repos/${REPO}/releases/latest" 2>&1)
fi

# Check for errors.
if [ $? -ne 0 ]; then
  echo ""
  echo "Error: failed to fetch release information."
  echo ""
  echo "${RELEASE_INFO}"
  echo ""
  echo "Possible causes:"
  echo "  1. No release exists in the repository."
  echo "  2. GITHUB_TOKEN is invalid or lacks the required permissions."
  echo "  3. The repository name is incorrect."
  echo ""
  echo "Create a token at:"
  echo "  https://github.com/settings/tokens"
  echo "  Required scope: repo (for private repositories)"
  exit 1
fi

# Parse the release information with jq if available, otherwise fall back to grep.
if command -v jq &> /dev/null; then
  DOWNLOAD_URL=$(echo "${RELEASE_INFO}" | jq -r '.assets[0].url')
  TAG_NAME=$(echo "${RELEASE_INFO}" | jq -r '.tag_name')
  ASSET_NAME=$(echo "${RELEASE_INFO}" | jq -r '.assets[0].name')
else
  # Extract the asset URL rather than the release page URL.
  DOWNLOAD_URL=$(echo "${RELEASE_INFO}" | grep -o '"url"[[:space:]]*:[[:space:]]*"https://api.github.com/repos/[^"]*releases/assets/[0-9]*"' | head -1 | grep -o 'https://[^"]*')
  TAG_NAME=$(echo "${RELEASE_INFO}" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)
  ASSET_NAME=$(echo "${RELEASE_INFO}" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*\.tar\.gz"' | head -1 | cut -d'"' -f4)
fi

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" == "null" ]; then
  echo ""
  echo "Error: download URL was not found."
  echo ""
  echo "Release information:"
  echo "${RELEASE_INFO}" | head -20
  echo ""
  echo "To download manually:"
  echo "  https://github.com/${REPO}/releases"
  exit 1
fi

echo "Release: ${TAG_NAME}"
echo "File: ${ASSET_NAME}"
echo ""

# Download the archive with GitHub API authentication when a token is available.
echo "Downloading certificates..."
ARCHIVE_FILE="${DOWNLOAD_DIR}/certs.tar.gz"

if [ -n "${TOKEN}" ]; then
  # Private repository: perform a two-step download through the API.
  # 1. Get the redirect URL.
  REDIRECT_URL=$(curl -sI \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/octet-stream" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${DOWNLOAD_URL}" | grep -i "^location:" | awk '{print $2}' | tr -d '\r\n')
  
  if [ -z "${REDIRECT_URL}" ]; then
    echo ""
    echo "Error: failed to retrieve the download URL."
    echo "Debug: DOWNLOAD_URL=${DOWNLOAD_URL}"
    exit 1
  fi
  
  echo "Redirect URL retrieved."
  
  # 2. Download directly from the redirected location.
  HTTP_CODE=$(curl -L -w "%{http_code}" -o "${ARCHIVE_FILE}" "${REDIRECT_URL}")
  
  if [ "${HTTP_CODE}" -ne 200 ]; then
    echo ""
    echo "Error: download failed (HTTP ${HTTP_CODE})."
    rm -f "${ARCHIVE_FILE}"
    exit 1
  fi
else
  # Public repository: download directly from browser_download_url.
  BROWSER_URL=$(echo "${RELEASE_INFO}" | grep -o '"browser_download_url": "[^"]*' | head -1 | cut -d'"' -f4)
  
  HTTP_CODE=$(curl -L -w "%{http_code}" -o "${ARCHIVE_FILE}" "${BROWSER_URL}")
  
  if [ "${HTTP_CODE}" -ne 200 ]; then
    echo ""
    echo "Error: download failed (HTTP ${HTTP_CODE})."
    rm -f "${ARCHIVE_FILE}"
    exit 1
  fi
fi

# Verify that the downloaded file is not empty.
if [ ! -s "${ARCHIVE_FILE}" ]; then
  echo ""
  echo "Error: the downloaded file is empty."
  exit 1
fi

echo "Download completed: $(ls -lh "${ARCHIVE_FILE}" | awk '{print $5}')"


# Extract the archive.
echo "Extracting certificates..."
tar -xzf "${ARCHIVE_FILE}" -C "${DOWNLOAD_DIR}"

if [ $? -ne 0 ]; then
  echo ""
  echo "Error: failed to extract the archive."
  echo "Archive file: ${ARCHIVE_FILE}"
  echo ""
  echo "To inspect it manually:"
  echo "  tar -tzf ${ARCHIVE_FILE}"
  exit 1
fi

# Check the extracted files.
CERT_FILES=$(find "${DOWNLOAD_DIR}" -type f \( -name "*.crt" -o -name "*.key" \) | wc -l)
if [ "${CERT_FILES}" -eq 0 ]; then
  echo ""
  echo "Error: no certificate files were found."
  echo "Please inspect the archive contents: ${ARCHIVE_FILE}"
  echo ""
  echo "Extracted files:"
  ls -la "${DOWNLOAD_DIR}"
  exit 1
fi

# Remove the archive file.
rm -f "${ARCHIVE_FILE}"

echo ""
echo "==================================="
echo "Download completed."
echo "==================================="
echo "Certificate location: $(cd "${DOWNLOAD_DIR}" && pwd)"
echo ""
echo "Files:"
ls -lh "${DOWNLOAD_DIR}" | grep -E "\.(crt|key)$" || ls -lh "${DOWNLOAD_DIR}"
echo ""
echo "Next steps:"
echo "1. Copy ca.crt, client.crt, and server.crt to the appropriate locations."
echo "2. Store ca.key, client.key, and server.key securely."
echo ""
echo "Certificate check:"
echo "  openssl x509 -in ${DOWNLOAD_DIR}/ca.crt -noout -subject -dates"
