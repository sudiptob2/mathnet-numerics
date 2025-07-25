#!/bin/bash

# =============================================================================
# Custom Math.NET Numerics MKL Provider Build Script
# =============================================================================
#
# This script builds and publishes custom Math.NET Numerics MKL provider packages
# using the existing repository infrastructure. It modifies nuspec files on-the-fly
# to create packages with custom package IDs, then reverts all changes to keep
# the repository clean.
#
# USAGE:
#   ./build-custom-mkl.sh help      # Show this help
#   ./build-custom-mkl.sh build     # Build packages only
#   ./build-custom-mkl.sh publish   # Publish to NuGet (requires NUGET_API_KEY)
#   ./build-custom-mkl.sh cleanup   # Clean up and revert changes
#   ./build-custom-mkl.sh all       # Complete workflow: build -> publish -> cleanup
#
# PREREQUISITES:
#   - Intel OneAPI MKL installed
#   - NuGet API key (for publishing)
#   - Git repository (for revert functionality)
#
# PACKAGES CREATED:
#   - Sudiptob2.MathNet.Numerics.MKL.Linux (combined x64+x86)
#   - Sudiptob2.MathNet.Numerics.MKL.Linux-x64 (x64 only)
#   - Sudiptob2.MathNet.Numerics.MKL.Linux-x86 (x86 only)
#
# CUSTOMIZATION:
#   Edit the variables below to change package prefix and author name
# =============================================================================

set -e  # Exit on any error

# Configuration - Edit these to customize your packages
PACKAGE_PREFIX="Sudiptob2.MathNet"  # Change this to your preferred prefix
AUTHOR_NAME="Sudiptob2"             # Change this to your name
PACKAGE_DIR="out/MKL/NuGet"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to revert changes - Restores original nuspec files
revert_changes() {
    print_status "Reverting nuspec file changes..."
    git checkout -- build/MathNet.Numerics.MKL.Linux.nuspec 2>/dev/null || true
    git checkout -- build/MathNet.Numerics.MKL.Linux-x64.nuspec 2>/dev/null || true
    git checkout -- build/MathNet.Numerics.MKL.Linux-x86.nuspec 2>/dev/null || true
    print_success "Changes reverted successfully."
}

# Function to apply custom package names - Modifies nuspec files temporarily
apply_custom_names() {
    print_status "Applying custom package names to nuspec files..."
    
    # Update main Linux package (combined x64+x86)
    sed -i "s/<id>MathNet.Numerics.MKL.Linux<\/id>/<id>${PACKAGE_PREFIX}.Numerics.MKL.Linux<\/id>/g" build/MathNet.Numerics.MKL.Linux.nuspec
    sed -i "s/<title>Math.NET Numerics - MKL Native Provider for Linux (x64 and x86)<\/title>/<title>${PACKAGE_PREFIX} Math.NET Numerics - MKL Native Provider for Linux (x64 and x86)<\/title>/g" build/MathNet.Numerics.MKL.Linux.nuspec
    sed -i "s/<authors>Christoph Ruegg, Marcus Cuda, Jurgen Van Gael<\/authors>/<authors>${AUTHOR_NAME}<\/authors>/g" build/MathNet.Numerics.MKL.Linux.nuspec
    
    # Update x64 package
    sed -i "s/<id>MathNet.Numerics.MKL.Linux-x64<\/id>/<id>${PACKAGE_PREFIX}.Numerics.MKL.Linux-x64<\/id>/g" build/MathNet.Numerics.MKL.Linux-x64.nuspec
    sed -i "s/<title>Math.NET Numerics - MKL Native Provider for Linux (x64)<\/title>/<title>${PACKAGE_PREFIX} Math.NET Numerics - MKL Native Provider for Linux (x64)<\/title>/g" build/MathNet.Numerics.MKL.Linux-x64.nuspec
    sed -i "s/<authors>Christoph Ruegg, Marcus Cuda, Jurgen Van Gael<\/authors>/<authors>${AUTHOR_NAME}<\/authors>/g" build/MathNet.Numerics.MKL.Linux-x64.nuspec
    
    # Update x86 package (mandatory)
    sed -i "s/<id>MathNet.Numerics.MKL.Linux-x86<\/id>/<id>${PACKAGE_PREFIX}.Numerics.MKL.Linux-x86<\/id>/g" build/MathNet.Numerics.MKL.Linux-x86.nuspec
    sed -i "s/<title>Math.NET Numerics - MKL Native Provider for Linux (x86)<\/title>/<title>${PACKAGE_PREFIX} Math.NET Numerics - MKL Native Provider for Linux (x86)<\/title>/g" build/MathNet.Numerics.MKL.Linux-x86.nuspec
    sed -i "s/<authors>Christoph Ruegg, Marcus Cuda, Jurgen Van Gael<\/authors>/<authors>${AUTHOR_NAME}<\/authors>/g" build/MathNet.Numerics.MKL.Linux-x86.nuspec
    
    print_success "Custom package names applied successfully."
}

# Function to build packages
build_packages() {
    print_status "Building ${PACKAGE_PREFIX} Math.NET Numerics MKL Linux Provider..."
    
    # Step 1: Build native libraries using the existing mkl_build.sh script
    print_status "Building native libraries..."
    cd src/NativeProviders/Linux
    ./mkl_build.sh
    cd ../../..
    
    # Step 2: Build NuGet packages using the existing FAKE build system
    print_status "Building NuGet packages using existing build system..."
    dotnet tool restore
    
    # Use the existing build script but target only the MKL Linux packages
    FAKE_DETAILED_ERRORS=true dotnet run --project ./build/build.fsproj -- -t MklLinuxPack
    
    print_success "Build completed successfully!"
    print_status "Packages are available in: ${PACKAGE_DIR}/"
}

# Publish packages - Uploads to NuGet.org
publish_packages() {
    print_status "Publishing ${PACKAGE_PREFIX} Math.NET Numerics MKL Linux Provider to NuGet..."
    
    # Validate NuGet API key
    if [ -z "$NUGET_API_KEY" ]; then
        print_error "NUGET_API_KEY environment variable is not set."
        echo "Please set your NuGet API key:"
        echo "export NUGET_API_KEY=your-api-key-here"
        exit 1
    fi
    
    # Check if packages exist
    if [ ! -d "$PACKAGE_DIR" ]; then
        print_error "Package directory $PACKAGE_DIR does not exist."
        echo "Please run the build first: $0 build"
        exit 1
    fi
    
    # Check if there are any .nupkg files
    PACKAGE_COUNT=$(find "$PACKAGE_DIR" -name "*.nupkg" | wc -l)
    if [ "$PACKAGE_COUNT" -eq 0 ]; then
        print_error "No .nupkg files found in $PACKAGE_DIR"
        echo "Please run the build first: $0 build"
        exit 1
    fi
    
    print_status "Found $PACKAGE_COUNT package(s) to publish:"
    
    # List packages before publishing
    for package in "$PACKAGE_DIR"/*.nupkg; do
        if [ -f "$package" ]; then
            echo "  - $(basename "$package")"
        fi
    done
    
    echo ""
    print_status "Publishing packages..."
    
    # Publish each package to NuGet.org
    for package in "$PACKAGE_DIR"/*.nupkg; do
        if [ -f "$package" ]; then
            print_status "Publishing $(basename "$package")..."
            dotnet nuget push "$package" \
                --api-key "$NUGET_API_KEY" \
                --source https://api.nuget.org/v3/index.json \
                --skip-duplicate
            print_success "  ✓ Published successfully"
        fi
    done
    
    print_success "All packages published successfully!"
    print_status "Packages are now available on NuGet.org"
}

# Function to cleanup - Reverts changes and removes build artifacts
cleanup() {
    print_status "Cleaning up repository..."
    
    # Revert any changes to nuspec files
    revert_changes
    
    # Clean build outputs (native libraries and packages)
    print_status "Cleaning build outputs..."
    rm -rf out/MKL/NuGet/*.nupkg 2>/dev/null || true
    rm -rf out/MKL/Linux/x64/*.so 2>/dev/null || true
    rm -rf out/MKL/Linux/x86/*.so 2>/dev/null || true
    
    # Verify repository is clean
    if git diff --quiet; then
        print_success "✓ Repository is clean"
    else
        print_warning "⚠ Repository has uncommitted changes:"
        git status --porcelain
    fi
    
    print_success "Cleanup completed!"
}

# Function to show usage
show_usage() {
    echo "Custom Math.NET Numerics MKL Provider Build Script"
    echo "=================================================="
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build     Build the custom MKL packages (modifies nuspec files temporarily)"
    echo "  publish   Publish packages to NuGet (requires NUGET_API_KEY environment variable)"
    echo "  cleanup   Clean up build artifacts and revert any changes"
    echo "  all       Build, publish, and cleanup in sequence"
    echo "  help      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  NUGET_API_KEY    Your NuGet API key (required for publish)"
    echo ""
    echo "Examples:"
    echo "  $0 build                    # Build packages only"
    echo "  $0 publish                  # Publish packages (requires NUGET_API_KEY)"
    echo "  $0 all                      # Build, publish, and cleanup"
    echo "  export NUGET_API_KEY=xxx && $0 all  # Complete workflow"
    echo ""
    echo "Package Names:"
    echo "  - ${PACKAGE_PREFIX}.Numerics.MKL.Linux (combined x64+x86)"
    echo "  - ${PACKAGE_PREFIX}.Numerics.MKL.Linux-x64 (x64 only)"
    echo "  - ${PACKAGE_PREFIX}.Numerics.MKL.Linux-x86 (x86 only)"
    echo ""
    echo "Customization: Edit PACKAGE_PREFIX and AUTHOR_NAME variables in this script"
}

# Main script logic
case "${1:-help}" in
    "build")
        trap revert_changes EXIT
        
        apply_custom_names
        
        build_packages
        
        # Note: The trap will automatically revert changes when the script exits
        ;;
    "publish")
        publish_packages
        ;;
    "cleanup")
        cleanup
        ;;
    "all")
        print_status "Running complete workflow: build -> publish -> cleanup"
        
        # Build
        print_status "=== STEP 1: BUILD ==="
        $0 build
        
        # Publish
        print_status "=== STEP 2: PUBLISH ==="
        $0 publish
        
        # Cleanup
        print_status "=== STEP 3: CLEANUP ==="
        $0 cleanup
        
        print_success "Complete workflow finished successfully!"
        ;;
    "help"|*)
        show_usage
        exit 1
        ;;
esac
