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
    echo "Processing $whl..."
    
    # Create a unique temp dir for unpacking
    UNPACK_DIR=$(mktemp -d)
    
    if python3 -m wheel unpack "$whl" -d "$UNPACK_DIR"; then
        # Find the METADATA file
        METADATA_FILE=$(find "$UNPACK_DIR" -name "METADATA")
        
        if [ -n "$METADATA_FILE" ]; then
            echo "  Fixing metadata in $METADATA_FILE"
            # Remove offending License fields
            sed -i '/^License-File/d' "$METADATA_FILE"
            # Downgrade Metadata-Version to 2.1 (Azure Artifacts often rejects 2.2+)
            sed -i 's/^Metadata-Version: .*/Metadata-Version: 2.1/' "$METADATA_FILE"
        fi
        
        # Find the actual package directory inside UNPACK_DIR
        PKG_DIR_INTERNAL=$(find "$UNPACK_DIR" -mindepth 1 -maxdepth 1 -type d)
        
        if [ -n "$PKG_DIR_INTERNAL" ]; then
            echo "  Repacking wheel..."
            if python3 -m wheel pack "$PKG_DIR_INTERNAL" -d "$TEMPDIR"; then
                echo "  Successfully cleaned $whl"
                rm -f "$whl"
            else
                echo "  Failed to repack wheel $whl"
            fi
        else
            echo "  Could not find internal package directory for $whl"
        fi
    else
        echo "  Failed to unpack wheel $whl. It might be malformed or wheel package is missing."
    fi
    
    # Clean up temp dir
    rm -rf "$UNPACK_DIR"
done

echo "Final list of packages to upload:"
ls -l $TEMPDIR

echo "Uploading package $PACKAGE"
# Use the config file provided by TwineAuthenticate task
python3 -m twine upload -r $FEED --disable-progress-bar --config-file $PYPIRCPATH $TEMPDIR/*
