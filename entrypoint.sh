#!/bin/bash
set -e

# Parse arguments
INSTALL_FOLDER="$1"
APP_NAME="$2"
COMMENT="$3"
CATEGORY="$4"
ICON="$5"
BINARY="$6"

echo "== Qt to AppImage Converter =="
echo "Install folder: $INSTALL_FOLDER"
echo "App name: $APP_NAME"
echo "Comment: $COMMENT"
echo "Category: $CATEGORY"
echo "Icon: $ICON"
echo "Binary: $BINARY"
echo "=========================="

# Validate install folder exists
if [ ! -d "$INSTALL_FOLDER" ]; then
  echo "Error: Qt folder '$INSTALL_FOLDER' does not exist"
  exit 1
fi

# Find binary if not specified
if [ -z "$BINARY" ]; then
  echo "Searching for binary in $INSTALL_FOLDER/bin/"
  # Find first executable that's not qt.conf
  BINARY=$(find "$INSTALL_FOLDER/bin" -type f -executable ! -name "qt.conf" | head -1 | xargs basename 2>/dev/null)
  if [ -z "$BINARY" ]; then
    echo "Error: No executable found in $INSTALL_FOLDER/bin/"
    exit 1
  fi
  echo "Found binary: $BINARY"
fi

# Verify binary exists
if [ ! -f "$INSTALL_FOLDER/bin/$BINARY" ]; then
  echo "Error: Binary '$BINARY' not found in $INSTALL_FOLDER/bin/"
  exit 1
fi

# Deduce app name if not specified
if [ -z "$APP_NAME" ]; then
  APP_NAME="${BINARY}"
  echo "Deduced app name: $APP_NAME"
fi

# Create AppDir
APPDIR="${APP_NAME}.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR"
cd "$APPDIR"

# Copy binary
cp "$INSTALL_FOLDER/bin/$BINARY" .

# Copy qt.conf if exists
if [ -f "$INSTALL_FOLDER/bin/qt.conf" ]; then
  cp "$INSTALL_FOLDER/bin/qt.conf" .
fi

# Copy libraries
cp -r "$INSTALL_FOLDER/lib" .

# Copy plugins
cp -r "$INSTALL_FOLDER/plugins" .

# Copy QML modules if they exist
if [ -d "$INSTALL_FOLDER/qml" ]; then
  cp -r "$INSTALL_FOLDER/qml" .
fi

# Create AppRun script
cat >AppRun <<'EOF'
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
cat >"${BINARY}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec=${BINARY}
Comment=${COMMENT}
Icon=${BINARY}
Categories=${CATEGORY};
Terminal=false
EOF

# Handle icon
if [ -n "$ICON" ] && [ -f "$ICON" ]; then
  cp "$ICON" "${BINARY}.png"
else
  # Create a simple default icon
  convert -size 128x128 xc:transparent -fill "#41cd52" -draw "circle 64,64 64,16" \
    -fill white -pointsize 48 -gravity center -annotate 0 "Qt" "${BINARY}.png"
fi

# Strip debug symbols to reduce size
find lib -name "*.so*" -type f -exec strip {} \; 2>/dev/null || true

cd ..

# Create AppImage
/usr/local/bin/appimagetool "$APPDIR" "${APP_NAME}.AppImage"

# Set output for GitHub Actions
echo "appimage=${APP_NAME}.AppImage" >> $GITHUB_OUTPUT

echo "AppImage created successfully: ${APP_NAME}.AppImage"
