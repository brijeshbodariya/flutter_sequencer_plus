#!/bin/bash
set -e

VERSION="v1.0.0"
REPO_URL="https://github.com/RBeato/flutter_sequencer_plus/releases/download"

EXPECTED_XC="95def6efebafeb6e4780bfae6cf7056c621b15a2ebaa14c30241333c1bc36e71"
EXPECTED_SRC="1efb3b75d4c619cf74fe7e589a58806fa96f63b69596b19dd4e6ca40c16b1d13"

verify_checksum() {
  local file=$1
  local expected=$2
  local actual=$(shasum -a 256 $file | cut -d' ' -f1)
  if [ "$expected" != "$actual" ]; then
    echo "Checksum mismatch for $file"
    exit 1
  fi
}

# Ensure script runs from ios directory
cd "$(dirname "$0")"

mkdir -p third_party/sfizz/xcframeworks
mkdir -p third_party/sfizz/src

# Download and unzip xcframeworks if missing
if [ ! -d "third_party/sfizz/xcframeworks/libsfizz.xcframework" ]; then
    echo "Downloading prebuilt xcframeworks..."
    curl -L "$REPO_URL/$VERSION/xcframeworks.zip" -o xcframeworks.zip
    verify_checksum xcframeworks.zip "$EXPECTED_XC"
    unzip -q xcframeworks.zip -d third_party/sfizz
    rm xcframeworks.zip
fi

# Download and unzip headers if missing
if [ ! -f "third_party/sfizz/src/sfizz.hpp" ]; then
    echo "Downloading sfizz headers..."
    curl -L "$REPO_URL/$VERSION/src.zip" -o src.zip
    verify_checksum src.zip "$EXPECTED_SRC"
    unzip -q src.zip -d third_party/sfizz
    rm src.zip
fi

echo "sfizz.xcframeworks and headers are ready."
# For sfizz, we'll create a simpler approach
if [ ! -d sfizz ]; then
    mkdir -p sfizz/build
fi

cd sfizz

# Create empty static libraries as placeholders
if [ ! -f "build/libsfizz_fat.a" ]; then
    echo "Creating empty libsfizz_fat.a for compatibility..."
    mkdir -p build/empty_obj
    cd build/empty_obj
    
    # Create a simple C file with necessary symbols
    cat > placeholder.c << EOF
void sfizz_placeholder() {}
EOF
    
    # Compile for device (arm64)
    xcrun --sdk iphoneos clang -arch arm64 -c placeholder.c -o placeholder_arm64.o
    
    # Compile for simulator (x86_64)
    xcrun --sdk iphonesimulator clang -arch x86_64 -c placeholder.c -o placeholder_x86_64.o
    
    # Create the libraries for each architecture
    xcrun --sdk iphoneos ar rcs ../libsfizz_iphoneos.a placeholder_arm64.o
    xcrun --sdk iphonesimulator ar rcs ../libsfizz_iphonesimulator.a placeholder_x86_64.o
    
    # Create a fat binary
    xcrun lipo -create ../libsfizz_iphoneos.a ../libsfizz_iphonesimulator.a -output ../libsfizz_fat.a
    
    cd ..
    echo "Created placeholder library at $(pwd)/libsfizz_fat.a"
    ls -la libsfizz_fat.a
else
    echo "Library build/libsfizz_fat.a already exists"
fi

echo "prepare.sh script completed successfully"
