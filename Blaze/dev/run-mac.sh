#!/bin/bash
# Blaze macOS Development Run Script
# Pure SPM-based build and run with InjectionIII support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/.build"

echo "=== Blaze Development Build ==="
echo "Project: $PROJECT_ROOT"
echo ""

# Parse arguments
BUILD_CONFIG="debug"
OPEN_APP=true
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_CONFIG="release"
            shift
            ;;
        --no-open)
            OPEN_APP=false
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./run-mac.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --release    Build release configuration (default: debug)"
            echo "  --no-open    Don't launch app after build"
            echo "  --clean      Clean build directory before building"
            echo "  --help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./run-mac.sh              # Debug build and launch"
            echo "  ./run-mac.sh --release    # Release build and launch"
            echo "  ./run-mac.sh --clean      # Clean debug build and launch"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

cd "$PROJECT_ROOT"

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    echo ""
fi

# Resolve dependencies if needed
if [ ! -d "$BUILD_DIR" ] || [ ! -f "Package.resolved" ]; then
    echo "Resolving dependencies..."
    swift package resolve
    echo ""
fi

# Build
echo "Building ($BUILD_CONFIG)..."
if [ "$BUILD_CONFIG" == "release" ]; then
    swift build -c release 2>&1 | tee /tmp/blaze-build.log
    BUILD_STATUS=${PIPESTATUS[0]}
    APP_PATH="$BUILD_DIR/release/Blaze"
else
    swift build 2>&1 | tee /tmp/blaze-build.log
    BUILD_STATUS=${PIPESTATUS[0]}
    APP_PATH="$BUILD_DIR/debug/Blaze"
fi

# Check build success
if [ $BUILD_STATUS -ne 0 ]; then
    echo ""
    echo "=== BUILD FAILED ==="
    echo "See /tmp/blaze-build.log for details"
    exit 1
fi

echo ""
echo "=== Build Successful ==="
echo "Executable: $APP_PATH"

# Verify executable exists
if [ ! -f "$APP_PATH" ]; then
    echo "ERROR: Executable not found at $APP_PATH"
    echo "Check build output for issues."
    exit 1
fi

# Open app
if [ "$OPEN_APP" = true ]; then
    echo ""
    echo "Launching Blaze..."

    # For macOS GUI app, run directly
    "$APP_PATH" &
    APP_PID=$!

    echo "Blaze launched (PID: $APP_PID)"
    echo ""
    echo "Tip: Open InjectionIII and select the project folder for hot reload support."
fi
