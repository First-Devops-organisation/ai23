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
sudo python3 -m pip wheel $PACKAGE -w $TEMPDIR --break-system-packages
sudo chown -R $(whoami):$(whoami) $TEMPDIR

echo "Applying Azure Artifacts compatibility fixes..."
for whl in $TEMPDIR/*.whl; do
    [ -f "$whl" ] || continue
    echo "  Cleaning $whl"
    UNPACK_DIR=$(mktemp -d)
    python3 -m wheel unpack "$whl" -d "$UNPACK_DIR"
    
    METADATA_FILE=$(find "$UNPACK_DIR" -name "METADATA")
    
    # This Python script strips fields that Azure Artifacts rejects (License-File, Dynamic, etc.)
    python3 -c "
from email import message_from_string
path = '$METADATA_FILE'
with open(path, 'r', encoding='utf-8') as f: msg = message_from_string(f.read())
# Remove incompatible Metadata 2.2/2.3 fields
for h in ['License-File', 'License-Files', 'Dynamic', 'License-Expression']:
    while h in msg: del msg[h]
# Force Metadata-Version to 2.1 for Azure compatibility
msg.replace_header('Metadata-Version', '2.1')
with open(path, 'w', encoding='utf-8') as f: f.write(msg.as_string())
"
    
    rm -f "$whl"
    python3 -m wheel pack $(find "$UNPACK_DIR" -mindepth 1 -maxdepth 1 -type d) -d "$TEMPDIR"
    rm -rf "$UNPACK_DIR"
done

echo "Uploading to Azure Artifacts..."
python3 -m twine upload -r $FEED --config-file $PYPIRCPATH $TEMPDIR/*
echo "Upload complete!"
