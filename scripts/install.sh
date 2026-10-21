#!/bin/bash
# Lightpanda Setup Script
# Run once to install Lightpanda browser

set -e

INSTALL_DIR="${LIGHTPANDA_DIR:-$HOME/.local/bin}"
BINARY_NAME="lightpanda"
VERSION="${LIGHTPANDA_VERSION:-latest}"

echo "=== Lightpanda Setup ==="
echo "Install directory: $INSTALL_DIR"

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux)
        case "$ARCH" in
            x86_64)
                ASSET_NAME="lightpanda-x86_64-linux"
                ;;
            aarch64|arm64)
                ASSET_NAME="lightpanda-aarch64-linux"
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
                ASSET_NAME="lightpanda-x86_64-macos"
                ;;
            arm64|aarch64)
                ASSET_NAME="lightpanda-aarch64-macos"
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

echo "Detected: $OS $ARCH"

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

# Resolve the release: the latest stable one by default, or LIGHTPANDA_VERSION (a tag, or "nightly")
if [ "$VERSION" = "latest" ]; then
    RELEASE_API="https://api.github.com/repos/lightpanda-io/browser/releases/latest"
else
    RELEASE_API="https://api.github.com/repos/lightpanda-io/browser/releases/tags/$VERSION"
fi

# One API call gives both the tag and the checksum, so they always match
echo "Fetching release info from GitHub API..."
RELEASE_JSON=$(curl -sL "$RELEASE_API")
TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name')

if [ -z "$TAG" ] || [ "$TAG" = "null" ]; then
    echo "ERROR: Could not find release '$VERSION' on GitHub."
    exit 1
fi

DOWNLOAD_URL="https://github.com/lightpanda-io/browser/releases/download/$TAG/$ASSET_NAME"
echo "Release: $TAG"
echo "Download URL: $DOWNLOAD_URL"

# Fetch expected SHA256 digest from the same release
EXPECTED_DIGEST=$(echo "$RELEASE_JSON" | jq -r --arg name "$ASSET_NAME" '.assets[] | select(.name == $name) | .digest')

if [ -z "$EXPECTED_DIGEST" ] || [ "$EXPECTED_DIGEST" = "null" ]; then
    echo "ERROR: Could not retrieve checksum for $ASSET_NAME from GitHub API."
    exit 1
fi

# Strip the "sha256:" prefix
EXPECTED_SHA256="${EXPECTED_DIGEST#sha256:}"
echo "Expected SHA256: $EXPECTED_SHA256"

# Download binary
echo "Downloading Lightpanda..."
curl -L -o "$INSTALL_DIR/$BINARY_NAME" "$DOWNLOAD_URL"

# Verify checksum
echo "Verifying checksum..."
if command -v sha256sum &> /dev/null; then
    ACTUAL_SHA256=$(sha256sum "$INSTALL_DIR/$BINARY_NAME" | awk '{print $1}')
else
    ACTUAL_SHA256=$(shasum -a 256 "$INSTALL_DIR/$BINARY_NAME" | awk '{print $1}')
fi

if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    echo "ERROR: Checksum verification FAILED!"
    echo "  Expected: $EXPECTED_SHA256"
    echo "  Actual:   $ACTUAL_SHA256"
    rm -f "$INSTALL_DIR/$BINARY_NAME"
    exit 1
fi

echo "Checksum verified OK."
chmod a+x "$INSTALL_DIR/$BINARY_NAME"

# Check if install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "WARNING: $INSTALL_DIR is not in your PATH"
    echo "Add this to your shell profile (~/.bashrc or ~/.zshrc):"
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
fi

# Test installation
echo ""
echo "Testing Lightpanda..."
if "$INSTALL_DIR/$BINARY_NAME" --version 2>/dev/null || "$INSTALL_DIR/$BINARY_NAME" --help 2>/dev/null | head -1; then
    echo "Lightpanda installed successfully!"
else
    echo "Binary installed at: $INSTALL_DIR/$BINARY_NAME"
fi

echo ""
echo "=== Setup Complete ==="
echo "Binary location: $INSTALL_DIR/$BINARY_NAME"
echo "Run with: lightpanda serve --host 127.0.0.1 --port 9222"
