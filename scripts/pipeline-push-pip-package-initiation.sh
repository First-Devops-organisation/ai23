#! /bin/bash
if [ -z $BASH_VERSION ]; then
  print_log "current SHELL is not BASH. please use bash to run this script" "error"
  exit 1
fi

echo "installing artifacts-keyring pip package"
sudo python3 -m pip install keyring artifacts-keyring
echo "installing wheel and setuptools"
sudo python3 -m pip install wheel "setuptools<59.0.0"
echo "installing twine pip package"
sudo python3 -m pip install twine
