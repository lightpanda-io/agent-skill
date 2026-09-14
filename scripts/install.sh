#!/bin/bash
# Lightpanda Setup Script
# Run to install or update Lightpanda. macOS arm64 → Homebrew tap;
# macOS x86_64 + Linux → GitHub Release download + atomic install.

# pipefail catches a failing curl in `curl | jq` that jq would otherwise swallow.
set -euo pipefail

BINARY_NAME="lightpanda"

echo "=== Lightpanda Setup ==="

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux)
        case "$ARCH" in
            x86_64)
                DOWNLOAD_URL="https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-x86_64-linux"
                ;;
            aarch64|arm64)
                DOWNLOAD_URL="https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-aarch64-linux"
                ;;
            *)
                echo "ERROR: Unsupported architecture: $ARCH"
                exit 1
                ;;
        esac
        ;;
    Darwin)
        case "$ARCH" in
            x86_64)
                # Intel Macs: the Mach-O release asset runs fine, so
                # use the same download/verify/atomic-mv path as Linux.
                DOWNLOAD_URL="https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-x86_64-macos"
                ;;
            arm64|aarch64)
                # Apple Silicon: AMFI rejects the release Mach-O's linker-signed signature
                # (no CMS blob) when it's executed from arbitrary user paths like /tmp or
                # ~/.local/bin — the binary gets SIGKILLed at exec with kernel log
                # "AMFI: ... Unrecoverable CT signature issue, bailing out.". The brew tap's
                # bin.install puts the same byte-identical binary at /opt/homebrew/Cellar/...,
                # which AMFI exempts from the strict ad-hoc signature check, so it runs.
                # (Re-signing locally with `codesign -s -` doesn't help — AMFI then rejects
                # with error -423 "adhoc signed or signed by an unknown certificate chain".)
                if ! command -v brew &> /dev/null; then
                    echo "ERROR: Apple Silicon install requires Homebrew (https://brew.sh)."
                    echo "Install Homebrew, then re-run. Or: brew install lightpanda-io/browser/lightpanda"
                    exit 1
                fi
                if [ -n "${LIGHTPANDA_DIR:-}" ]; then
                    echo "Note: LIGHTPANDA_DIR is ignored on Apple Silicon — brew owns the install path."
                fi
                echo "Detected: $OS $ARCH — installing via Homebrew tap."
                # `install` is a no-op when current; `upgrade` keeps reruns fresh. Both exit 0 in the
                # up-to-date case and non-zero on real errors, so `set -e` propagates genuine failures.
                brew install lightpanda-io/browser/lightpanda
                brew upgrade lightpanda-io/browser/lightpanda
                # Anchor on `brew --prefix` (general, not keg-specific) so a stale ~/.local/bin/lightpanda
                # from a pre-this-PR run can't shadow the brew binary undetected.
                BREW_PREFIX="$(brew --prefix)"
                BIN_PATH="$BREW_PREFIX/bin/$BINARY_NAME"
                [ -x "$BIN_PATH" ] || { echo "ERROR: brew install completed but $BIN_PATH is missing. Try: brew link --overwrite lightpanda"; exit 1; }
                # Hard-fail smoke test — brew can ship a binary that crashes at exec; surface stderr.
                DARWIN_SMOKE_STDERR=$(mktemp)
                trap 'rm -f "$DARWIN_SMOKE_STDERR"' EXIT
                if ! VERSION_OUT=$("$BIN_PATH" version 2>"$DARWIN_SMOKE_STDERR") || [ -z "$VERSION_OUT" ]; then
                    echo "ERROR: Homebrew-installed lightpanda failed its version smoke test."
                    [ -s "$DARWIN_SMOKE_STDERR" ] && { echo "  Binary stderr:"; sed 's/^/    /' "$DARWIN_SMOKE_STDERR"; }
                    echo "  Try: brew reinstall lightpanda-io/browser/lightpanda"
                    exit 1
                fi
                echo ""
                echo "Lightpanda installed via Homebrew: $VERSION_OUT"
                echo "Binary location: $BIN_PATH"
                # Warn about PATH-shadow: a pre-this-PR run left the SIGKILL Mach-O at ~/.local/bin/lightpanda;
                # without this check the user still runs the broken one despite brew installing a working binary.
                PATH_RESOLVED="$(command -v lightpanda 2>/dev/null || true)"
                if [ -n "$PATH_RESOLVED" ] && [ "$PATH_RESOLVED" != "$BIN_PATH" ]; then
                    echo ""
                    echo "WARNING: another 'lightpanda' is earlier in your PATH: $PATH_RESOLVED"
                    echo "Remove it or reorder PATH so $BREW_PREFIX/bin takes precedence."
                fi
                echo "Run with: lightpanda serve --host 127.0.0.1 --port 9222"
                exit 0
                ;;
            *)
                echo "ERROR: Unsupported architecture: $ARCH"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "ERROR: Unsupported OS: $OS"
        echo "For Windows, use WSL2 with Ubuntu and run the Linux version."
        exit 1
        ;;
esac

# --- Shared download flow (Linux + Intel macOS) ---
INSTALL_DIR="${LIGHTPANDA_DIR:-$HOME/.local/bin}"
echo "Detected: $OS $ARCH"
echo "Install directory: $INSTALL_DIR"
echo "Download URL: $DOWNLOAD_URL"

# Check for required tools
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl not found. Please install curl."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "ERROR: jq not found. Please install jq (needed for checksum verification)."
    exit 1
fi

if ! command -v sha256sum &> /dev/null && ! command -v shasum &> /dev/null; then
    echo "ERROR: sha256sum or shasum not found."
    exit 1
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Determine asset name from URL
ASSET_NAME="${DOWNLOAD_URL##*/}"

# Fetch expected SHA256 digest from GitHub release API. -f makes curl
# exit non-zero on HTTP errors (4xx/5xx) so set -e + pipefail catch
# them; without it curl exits 0 on 503 and jq fails on the error body
# with a misleading "could not retrieve checksum" message.
echo "Fetching expected checksum from GitHub API..."
EXPECTED_DIGEST=$(curl -fSL "https://api.github.com/repos/lightpanda-io/browser/releases/tags/nightly" \
    | jq -r --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .digest')

if [ -z "$EXPECTED_DIGEST" ] || [ "$EXPECTED_DIGEST" = "null" ]; then
    echo "ERROR: Could not retrieve checksum for $ASSET_NAME from GitHub API."
    exit 1
fi

# Strip the "sha256:" prefix
EXPECTED_SHA256="${EXPECTED_DIGEST#sha256:}"
echo "Expected SHA256: $EXPECTED_SHA256"

# Download to a temp file in the same directory, verify, smoke-test,
# THEN atomically `mv` into place. SKILL.md documents reruns as the
# update path, so a failed download must not destroy a working binary.
TMP_BINARY=$(mktemp "$INSTALL_DIR/.${BINARY_NAME}.XXXXXX")
SMOKE_STDERR=$(mktemp)
trap 'rm -f "$TMP_BINARY" "$SMOKE_STDERR"' EXIT

echo "Downloading Lightpanda to $TMP_BINARY..."
curl -fSL -o "$TMP_BINARY" "$DOWNLOAD_URL"

# Verify checksum
echo "Verifying checksum..."
if command -v sha256sum &> /dev/null; then
    ACTUAL_SHA256=$(sha256sum "$TMP_BINARY" | awk '{print $1}')
else
    ACTUAL_SHA256=$(shasum -a 256 "$TMP_BINARY" | awk '{print $1}')
fi

if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    echo "ERROR: Checksum verification FAILED!"
    echo "  Expected: $EXPECTED_SHA256"
    echo "  Actual:   $ACTUAL_SHA256"
    echo "  Existing binary (if any) at $INSTALL_DIR/$BINARY_NAME was NOT replaced."
    exit 1
fi

echo "Checksum verified OK."
# 0755 (conventional executable mode) rather than `chmod a+x` over
# mktemp's 0600, which would yield 0711 (owner-only readable).
chmod 0755 "$TMP_BINARY"

# Smoke-test BEFORE replacing. Use the `version` subcommand — the
# `--version` flag exits 1 with `UnknownCommand`, so it would falsely
# reject a working binary. Capturing stdout to a variable means the
# `if` exit status is the binary's exit status (no pipe to mask it).
echo "Smoke-testing the downloaded binary..."
if ! VERSION_OUT=$("$TMP_BINARY" version 2>"$SMOKE_STDERR") || [ -z "$VERSION_OUT" ]; then
    echo "ERROR: Downloaded binary failed to run (\`version\` subcommand returned no output or non-zero exit)."
    echo "  This may indicate an incompatible system, missing libc, or a corrupted release asset."
    if [ -s "$SMOKE_STDERR" ]; then
        echo "  Binary stderr:"
        sed 's/^/    /' "$SMOKE_STDERR"
    fi
    echo "  Existing binary (if any) at $INSTALL_DIR/$BINARY_NAME was NOT replaced."
    exit 1
fi

# `mv` within the same filesystem is atomic.
mv "$TMP_BINARY" "$INSTALL_DIR/$BINARY_NAME"
# Leave the EXIT trap registered so $SMOKE_STDERR still gets cleaned;
# `rm -f` on the moved-away $TMP_BINARY is a silent no-op.

# Check if install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "WARNING: $INSTALL_DIR is not in your PATH"
    echo "Add this to your shell profile (~/.bashrc or ~/.zshrc):"
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
fi

echo ""
echo "Lightpanda installed successfully: ${VERSION_OUT:-OK}"

echo ""
echo "=== Setup Complete ==="
echo "Binary location: $INSTALL_DIR/$BINARY_NAME"
echo "Run with: lightpanda serve --host 127.0.0.1 --port 9222"
