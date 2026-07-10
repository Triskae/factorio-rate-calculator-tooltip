#!/usr/bin/env bash

set -euo pipefail

MOD_DIR="${1:-.}"

NAME="$(jq -r '.name' "$MOD_DIR/info.json")"
VERSION="$(jq -r '.version' "$MOD_DIR/info.json")"
OUTPUT="${NAME}_${VERSION}.zip"

if [[ -z "$NAME" || "$NAME" == "null" ]]; then
  echo "Erreur : name absent de info.json"
  exit 1
fi

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
  echo "Erreur : version absente de info.json"
  exit 1
fi

rm -f "$OUTPUT"

PARENT_DIR="$(dirname "$MOD_DIR")"
FOLDER_NAME="$(basename "$MOD_DIR")"

(
  cd "$PARENT_DIR"

  zip -r "$OLDPWD/$OUTPUT" "$FOLDER_NAME" \
    -x "*/.DS_Store" \
    -x "*/.git/*" \
    -x "*/.idea/*" \
    -x "*/.vscode/*" \
    -x "*/node_modules/*"
)

echo "Package créé : $OUTPUT"