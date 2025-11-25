#!/bin/sh

# Trap SIGINT (Ctrl+C) to provide a message and exit code 130
trap 'printf "\nAborted by user.\n"; exit 130' INT

# Set the binary folder
BINARY_FOLDER="/usr/local/bin"
BINARY_FILE="$BINARY_FOLDER/tpn"
TEMP_DIR=$(mktemp -d -t tpn_update_XXXXXX)

# Download the current executable
REPO_URL="https://raw.githubusercontent.com/taofu-labs/tpn-cli"
FILE_URL="$REPO_URL/main/tpn.sh"

# Download the file
printf 'Downloading latest TPN CLI version from GitHub\n'
TEMP_FILE="$TEMP_DIR/tpn.sh"
curl -fsSL "$FILE_URL" -o "$TEMP_FILE"
cp "$TEMP_FILE" "$BINARY_FILE"

# Get the current owner (macOS-compatible)
OWNER=$(stat -f '%Su' "$BINARY_FILE")

# If user is not owner, change ownership
if [ "$OWNER" != "$USER" ]; then
  printf 'Changing ownership of %s to %s\n' "$BINARY_FILE" "$USER"
  chown "$USER" "$BINARY_FILE"
fi

# Get current permissions
PERMS=$(stat -f '%Mp%Lp' "$BINARY_FILE")

# If permissions not 755, change them
if [ "$PERMS" != "0755" ]; then
  printf 'Changing permissions of %s to 755\n' "$BINARY_FILE"
  chmod 755 "$BINARY_FILE"
fi

# If not yet executable, make it executable
if [ ! -x "$BINARY_FILE" ]; then
  printf 'Making %s executable\n' "$BINARY_FILE"
  chmod +x "$BINARY_FILE"
fi

# Clean up
rm -rf "$TEMP_DIR"
printf 'TPN CLI tool updated successfully to the latest version.\n'