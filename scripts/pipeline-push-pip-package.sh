#! /bin/bash
if [ -z $BASH_VERSION ]; then
  print_log "current SHELL is not BASH. please use bash to run this script" "error"
  exit 1
fi

while getopts ":f:p:o:r:" opt; do
  case $opt in
  f)
    FEED="$OPTARG"
    ;;
  o)
    ORG="$OPTARG"
    ;;
  p)
    PACKAGE="$OPTARG"
    ;;
  r)
    PYPIRCPATH="$OPTARG"
    ;;
  \?)
    echo "Invalid option -$OPTARG" >&2
    exit 1
    ;;
  esac

  case $OPTARG in
  -*)
    echo "Option $opt is not valid. Please use -f for feed, -o for ADO organization, -p for package name" >&2
    exit 1
    ;;
  esac
done
echo "PYPIRC_PATH: $PYPIRCPATH"
cat $PYPIRCPATH
URL="https://pkgs.dev.azure.com/$ORG/_packaging/$FEED/pypi/simple"
TEMPDIR='pip-temp'

echo "creating temp directory"
sudo mkdir -p $TEMPDIR
sudo dir
echo "downloading package $PACKAGE"
sudo python3 -m pip wheel $PACKAGE -w $TEMPDIR
# Ensure the current user can read/write the downloaded wheels
sudo chown -R $(whoami):$(whoami) $TEMPDIR

echo "Cleaning metadata for Azure Artifacts compatibility"
for whl in $TEMPDIR/*.whl; do
    if [ ! -f "$whl" ]; then continue; fi
    echo "Processing $whl"
    # Create a unique temp dir for unpacking
    UNPACK_DIR=$(mktemp -d)
    python3 -m wheel unpack "$whl" -d "$UNPACK_DIR"
    
    # Find the METADATA file and remove offending lines
    # Azure Artifacts rejects 'License-File' and 'License-Files' in some cases
    find "$UNPACK_DIR" -name "METADATA" -exec sed -i '/^License-File/d' {} +
    
    # Find the actual package directory inside UNPACK_DIR
    PKG_DIR_INTERNAL=$(find "$UNPACK_DIR" -mindepth 1 -maxdepth 1 -type d)
    
    if [ -n "$PKG_DIR_INTERNAL" ]; then
        # Repack to TEMPDIR
        python3 -m wheel pack "$PKG_DIR_INTERNAL" -d "$TEMPDIR"
        # Remove the original wheel
        rm -f "$whl"
    fi
    
    # Clean up temp dir
    rm -rf "$UNPACK_DIR"
done

echo "Uploading package $PACKAGE"
# Use the config file provided by TwineAuthenticate task
python3 -m twine upload -r $FEED --disable-progress-bar --config-file $PYPIRCPATH $TEMPDIR/*
