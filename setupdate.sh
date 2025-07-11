#!/bin/sh

# Warn in red that this script is deprecated and will be removed in the future
echo -e "\033[31mWarning: This script is deprecated and will be removed in the future. Please use 'setup.sh' instead.\033[0m"

# Set the binary folder
BINARY_FOLDER="/usr/local/bin"
BINARY_FILE="$BINARY_FOLDER/tpn"

# Download the current executable
REPO_URL="https://raw.githubusercontent.com/taofu-labs/tpn-cli"
FILE_URL="$REPO_URL/main/tpn.sh"

# Make sure binfolder exists
mkdir -p "$BINARY_FOLDER"

# Download the file
sudo rm -f "$BINARY_FILE"  # Remove any existing file
curl -fsSL "$FILE_URL" | sudo tee "$BINARY_FILE" > /dev/null

# Get the current owner (macOS-compatible)
OWNER=$(stat -f '%Su' "$BINARY_FILE")

# If user is not owner, change ownership
if [ "$OWNER" != "$USER" ]; then
  echo "Changing ownership of $BINARY_FILE to $USER"
  sudo chown "$USER" "$BINARY_FILE"
fi

# Get current permissions
PERMS=$(stat -f '%Mp%Lp' "$BINARY_FILE")

# If permissions not 755, change them
if [ "$PERMS" != "0755" ]; then
  echo "Changing permissions of $BINARY_FILE to 755"
  sudo chmod 755 "$BINARY_FILE"
fi

# If not yet executable, make it executable
if [ ! -x "$BINARY_FILE" ]; then
  echo "Making $BINARY_FILE executable"
  sudo chmod +x "$BINARY_FILE"
fi