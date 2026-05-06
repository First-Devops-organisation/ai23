#! /bin/bash
if [ -z $BASH_VERSION ]; then
  print_log "current SHELL is not BASH. please use bash to run this script" "error"
  exit 1
fi

echo "Updating pip and installing core tools"
sudo python3 -m pip install --upgrade pip
sudo python3 -m pip install wheel setuptools twine artifacts-keyring
echo "Installation complete."
