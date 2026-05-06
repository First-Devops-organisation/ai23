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
echo "Building wheel for $PACKAGE"
sudo python3 -m pip wheel $PACKAGE -w $TEMPDIR
sudo chown -R $(whoami):$(whoami) $TEMPDIR

echo "Applying Azure Artifacts compatibility fixes"
for whl in $TEMPDIR/*.whl; do
    [ -f "$whl" ] || continue
    echo "  Cleaning $whl"
    UNPACK_DIR=$(mktemp -d)
    python3 -m wheel unpack "$whl" -d "$UNPACK_DIR"
    
    # Use a concise Python one-liner to fix metadata
    METADATA_FILE=$(find "$UNPACK_DIR" -name "METADATA")
    python3 -c "
from email import message_from_string
path = '$METADATA_FILE'
with open(path, 'r', encoding='utf-8') as f: msg = message_from_string(f.read())
for h in ['License-File', 'License-Files', 'Dynamic']:
    while h in msg: del msg[h]
msg.replace_header('Metadata-Version', '2.1')
with open(path, 'w', encoding='utf-8') as f: f.write(msg.as_string())
"
    
    rm -f "$whl"
    python3 -m wheel pack $(find "$UNPACK_DIR" -mindepth 1 -maxdepth 1 -type d) -d "$TEMPDIR"
    rm -rf "$UNPACK_DIR"
done

echo "Uploading to Azure Artifacts..."
python3 -m twine upload -r $FEED --config-file $PYPIRCPATH $TEMPDIR/*
