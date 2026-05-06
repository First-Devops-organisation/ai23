#!/bin/bash
set -e

echo "Updating pip and installing core tools..."
sudo python3 -m pip install --upgrade pip
sudo python3 -m pip install wheel setuptools twine artifacts-keyring

echo "All tools installed successfully."
