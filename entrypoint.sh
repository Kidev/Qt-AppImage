#!/bin/bash
set -e

# Parse arguments
INSTALL_FOLDER="$1"
APP_NAME="$2"
COMMENT="$3"
CATEGORY="$4"
ICON="$5"
BINARY="$6"

echo "====== Qt to AppImage ======"
echo "Install folder: $INSTALL_FOLDER"
echo "App name: $APP_NAME"
echo "Comment: $COMMENT"
echo "Category: $CATEGORY"
echo "Icon: $ICON"
echo "Binary: $BINARY"
echo "=========================="

# Convert to absolute path
INSTALL_FOLDER=$(realpath "$INSTALL_FOLDER")
echo "Absolute install folder: $INSTALL_FOLDER"

# Validate install folder exists
if [ ! -d "$INSTALL_FOLDER" ]; then
    echo "Error: install folder '$INSTALL_FOLDER' does not exist"
    exit 1
fi

# Debug: List contents of bin directory
echo "Contents of $INSTALL_FOLDER/bin/:"
ls -la "$INSTALL_FOLDER/bin/" || echo "Directory does not exist or is not accessible"

# Find binary if not specified
if [ -z "$BINARY" ]; then
    echo "Searching for binary in $INSTALL_FOLDER/bin/"

    # First, check if bin directory exists
    if [ ! -d "$INSTALL_FOLDER/bin" ]; then
        echo "Error: $INSTALL_FOLDER/bin directory does not exist"
        exit 1
    fi

    # Find first executable file that's not qt.conf
    BINARY_FULL_PATH=$(find "$INSTALL_FOLDER/bin" -type f -executable ! -name "qt.conf" | head -1)

    if [ -z "$BINARY_FULL_PATH" ]; then
        echo "Error: No executable found in $INSTALL_FOLDER/bin/"
        echo "Checking for any files in $INSTALL_FOLDER/bin/:"
        find "$INSTALL_FOLDER/bin" -type f | head -5
        exit 1
    fi

    BINARY=$(basename "$BINARY_FULL_PATH")
    echo "Found binary: $BINARY at $BINARY_FULL_PATH"

    # Verify the binary actually exists and is executable
    if [ ! -f "$BINARY_FULL_PATH" ]; then
        echo "Error: Found binary $BINARY_FULL_PATH does not exist"
        exit 1
    fi

    if [ ! -x "$BINARY_FULL_PATH" ]; then
        echo "Warning: Binary $BINARY_FULL_PATH is not executable, making it executable..."
        chmod +x "$BINARY_FULL_PATH"
    fi
else
    BINARY_FULL_PATH="$INSTALL_FOLDER/bin/$BINARY"
fi

# Verify binary exists
if [ ! -f "$BINARY_FULL_PATH" ]; then
    echo "Error: Binary '$BINARY' not found at $BINARY_FULL_PATH"
    echo "Available files in $INSTALL_FOLDER/bin/:"
    find "$INSTALL_FOLDER/bin" -type f | head -10
    exit 1
fi

# Deduce app name if not specified
if [ -z "$APP_NAME" ]; then
    APP_NAME="${BINARY}"
    echo "Deduced app name: $APP_NAME"
fi

# Create AppDir in current directory
APPDIR="${APP_NAME}.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR"

# Store current directory
CURRENT_DIR=$(pwd)

# Copy binary (before changing directory)
echo "Copying binary from $BINARY_FULL_PATH to $APPDIR/$BINARY"
cp "$BINARY_FULL_PATH" "$APPDIR/$BINARY"

# Make sure binary is executable
chmod +x "$APPDIR/$BINARY"

# Copy qt.conf if exists
if [ -f "$INSTALL_FOLDER/bin/qt.conf" ]; then
    cp "$INSTALL_FOLDER/bin/qt.conf" "$APPDIR/"
fi

# Copy libraries
if [ -d "$INSTALL_FOLDER/lib" ]; then
    cp -r "$INSTALL_FOLDER/lib" "$APPDIR/"
else
    echo "Warning: No lib directory found in $INSTALL_FOLDER"
fi

# Copy plugins
if [ -d "$INSTALL_FOLDER/plugins" ]; then
    cp -r "$INSTALL_FOLDER/plugins" "$APPDIR/"
else
    echo "Warning: No plugins directory found in $INSTALL_FOLDER"
fi

# Copy QML modules if they exist
if [ -d "$INSTALL_FOLDER/qml" ]; then
    cp -r "$INSTALL_FOLDER/qml" "$APPDIR/"
fi

# Now change into AppDir for creating internal files
cd "$APPDIR"

# Create AppRun script
cat > AppRun << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}:${PATH}"
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="${HERE}/plugins"
export QML2_IMPORT_PATH="${HERE}/qml"
export QT_QPA_PLATFORM_PLUGIN_PATH="${HERE}/plugins/platforms"
export QT_XCB_GL_INTEGRATION=xcb_egl

# Run the application
exec "${HERE}/BINARY_PLACEHOLDER" "$@"
EOF

# Replace placeholder with actual binary name
sed -i "s/BINARY_PLACEHOLDER/$BINARY/g" AppRun
chmod +x AppRun

# Create desktop file
cat > "${BINARY}.desktop" << EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec=${BINARY}
Comment=${COMMENT}
Icon=${BINARY}
Categories=${CATEGORY};
Terminal=false
EOF

# Handle icon - convert icon path to absolute if it's relative
if [ -n "$ICON" ]; then
    # Make icon path absolute if it's relative
    if [[ ! "$ICON" = /* ]]; then
        ICON="${CURRENT_DIR}/${ICON}"
    fi

    if [ -f "$ICON" ]; then
        cp "$ICON" "${BINARY}.png"
    else
        echo "Warning: Icon file not found at $ICON, creating default icon..."
        create_default_icon
    fi
else
    echo "Creating default icon..."
    create_default_icon
fi

# Function to create default icon
create_default_icon() {
    convert -size 128x128 xc:transparent -fill "#41cd52" -draw "circle 64,64 64,16" \
        -fill white -pointsize 48 -gravity center -annotate 0 "Qt" "${BINARY}.png"
}

# Strip debug symbols to reduce size
find lib -name "*.so*" -type f -exec strip {} \; 2>/dev/null || true

# Go back to the original directory for creating the AppImage
cd ..

# Create AppImage
/usr/local/bin/appimagetool "$APPDIR" "${APP_NAME}.AppImage"

# Set output for GitHub Actions
echo "appimage=${APP_NAME}.AppImage" >> $GITHUB_OUTPUT

echo "AppImage created successfully: ${APP_NAME}.AppImage"
