#!/bin/bash
set -e

while getopts ":f:p:o:r:" opt; do
  case $opt in
    f) FEED="$OPTARG" ;;
    o) ORG="$OPTARG" ;;
    p) PACKAGE="$OPTARG" ;;
    r) PYPIRCPATH="$OPTARG" ;;
  esac
done

TEMPDIR='pip-temp'
mkdir -p $TEMPDIR

echo "Building wheel for $PACKAGE..."
sudo python3 -m pip wheel $PACKAGE -w $TEMPDIR
sudo chown -R $(whoami):$(whoami) $TEMPDIR

echo "Applying Azure Artifacts compatibility fixes..."
for whl in $TEMPDIR/*.whl; do
    [ -f "$whl" ] || continue
    echo "  Cleaning $whl"
    UNPACK_DIR=$(mktemp -d)
    python3 -m wheel unpack "$whl" -d "$UNPACK_DIR"
    
    # Find all METADATA files (some wheels contain vendored packages with their own METADATA)
    find "$UNPACK_DIR" -name "METADATA" -print0 | while IFS= read -r -d '' METADATA_FILE; do
        # Use sys.argv to safely pass the path, avoiding bash string interpolation issues
        python3 -c "
import sys
from email import message_from_string
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f: msg = message_from_string(f.read())
# Remove incompatible Metadata 2.2/2.3 fields
for h in ['License-File', 'License-Files', 'Dynamic', 'License-Expression']:
    while h in msg: del msg[h]
# Force Metadata-Version to 2.1 for Azure compatibility
msg.replace_header('Metadata-Version', '2.1')
with open(path, 'w', encoding='utf-8') as f: f.write(msg.as_string())
" "$METADATA_FILE"
    done
    
    rm -f "$whl"
    python3 -m wheel pack $(find "$UNPACK_DIR" -mindepth 1 -maxdepth 1 -type d) -d "$TEMPDIR"
    rm -rf "$UNPACK_DIR"
done

echo "Uploading to Azure Artifacts..."
python3 -m twine upload -r $FEED --config-file $PYPIRCPATH $TEMPDIR/*
echo "Upload complete!"
