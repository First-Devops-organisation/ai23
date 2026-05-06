#!/bin/bash
set -e

echo "Installing core tools..."
# We skip upgrading pip directly as it is often managed by the OS (Debian/Ubuntu)
# We use --break-system-packages if needed for Python 3.11+ compatibility in some environments
sudo python3 -m pip install wheel setuptools twine artifacts-keyring --break-system-packages || \
sudo python3 -m pip install wheel setuptools twine artifacts-keyring

echo "All tools installed successfully."
