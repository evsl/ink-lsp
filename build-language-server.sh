#!/bin/bash

# .NET Project Build Script
# Builds cross-platform executables for Windows, macOS, and Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CONFIGURATION="Release"
OUTPUT_DIR="dist/LanguageServer"
PROJECT_PATH="inklecate/inklecate.csproj"
ZIP_OUTPUT=false

# Available platforms
PLATFORMS=(
    "win-x64"
    "win-arm64"
    "osx-x64"
    "osx-arm64"
    "linux-x64"
    "linux-arm64"
)

print_usage() {
    echo -e "${BLUE}.NET Project Build Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] [PLATFORMS...]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -c, --config        Build configuration (Debug|Release) [default: Release]"
    echo "  -o, --output        Output directory [default: dist]"
    echo "  -a, --all           Build for all platforms"
    echo "  -z, --zip           Create zip archives of the output directories"
    echo "  -f, --framework     Target framework [default: net9.0]"
    echo ""
    echo "Available Platforms:"
    for platform in "${PLATFORMS[@]}"; do
        echo "  - $platform"
    done
    echo ""
    echo "Examples:"
    echo "  $0 --all                    # Build for all platforms"
    echo "  $0 --all --zip              # Build for all platforms and create zip files"
    echo "  $0 osx-arm64 linux-x64      # Build for specific platforms"
    echo "  $0 -c Debug win-x64         # Build debug version for Windows x64"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

build_platform() {
    local platform=$1
    local folder_name="inklecate-${platform}"
    local output_path="$OUTPUT_DIR/$folder_name"
    
    log_info "Building for $platform..."
    
    # Build command
    local build_cmd="dotnet publish \"$PROJECT_PATH\" -r $platform -c $CONFIGURATION -o \"$output_path\" -p:UseAppHost=true --self-contained true -p:PublishSingleFile=true"
    
    # Execute build
    if eval $build_cmd; then
        log_success "Successfully built for $platform"
        
        # Show output info
        if [ -d "$output_path" ]; then
            local file_count=$(find "$output_path" -type f | wc -l)
            local dir_size=$(du -sh "$output_path" | cut -f1)
            log_info "Output: $output_path ($file_count files, $dir_size)"
            
            # Create zip if requested
            if [ "$ZIP_OUTPUT" = true ]; then
                create_zip "$folder_name" "$output_path"
            fi
        fi
    else
        log_error "Failed to build for $platform"
        return 1
    fi
}

create_zip() {
    local folder_name=$1
    local output_path=$2
    local zip_path="$OUTPUT_DIR/${folder_name}.zip"
    
    log_info "Creating zip archive: ${folder_name}.zip"
    
    # Change to the platform output directory to zip its contents
    local current_dir=$(pwd)
    cd "$output_path"
    
    if zip -r "../${folder_name}.zip" . > /dev/null 2>&1; then
        cd "$current_dir"
        local zip_size=$(du -sh "$zip_path" | cut -f1)
        log_success "Created zip archive: ${folder_name}.zip ($zip_size)"
    else
        cd "$current_dir"
        log_error "Failed to create zip archive for $folder_name"
        return 1
    fi
}

# Parse command line arguments
PLATFORMS_TO_BUILD=()
BUILD_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -c|--config)
            CONFIGURATION="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -a|--all)
            BUILD_ALL=true
            shift
            ;;
        -z|--zip)
            ZIP_OUTPUT=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            # Check if it's a valid platform
            if [[ " ${PLATFORMS[@]} " =~ " $1 " ]]; then
                PLATFORMS_TO_BUILD+=("$1")
            else
                log_error "Unknown platform: $1"
                echo "Available platforms: ${PLATFORMS[*]}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Determine which platforms to build
if [ "$BUILD_ALL" = true ]; then
    PLATFORMS_TO_BUILD=("${PLATFORMS[@]}")
elif [ ${#PLATFORMS_TO_BUILD[@]} -eq 0 ]; then
    log_error "No platforms specified. Use --all or specify platform names."
    print_usage
    exit 1
fi

# Validate configuration
if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
    log_error "Invalid configuration: $CONFIGURATION. Must be Debug or Release."
    exit 1
fi

# Check if project file exists
if [ ! -f "$PROJECT_PATH" ]; then
    log_error "Project file not found: $PROJECT_PATH"
    exit 1
fi

# Print build summary
echo -e "${BLUE}=== Build Summary ===${NC}"
echo "Configuration: $CONFIGURATION"
echo "Output directory: $OUTPUT_DIR"
echo "Target framework: $TARGET_FRAMEWORK"
echo "Create zip files: $ZIP_OUTPUT"
echo "Platforms: ${PLATFORMS_TO_BUILD[*]}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build for each platform
FAILED_BUILDS=()
SUCCESSFUL_BUILDS=()

for platform in "${PLATFORMS_TO_BUILD[@]}"; do
    if build_platform "$platform"; then
        SUCCESSFUL_BUILDS+=("$platform")
    else
        FAILED_BUILDS+=("$platform")
    fi
    echo ""
done

# Print final summary
echo -e "${BLUE}=== Build Results ===${NC}"
if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
    log_success "Successfully built for: ${SUCCESSFUL_BUILDS[*]}"
fi

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    log_error "Failed builds for: ${FAILED_BUILDS[*]}"
    exit 1
fi

log_success "All builds completed successfully!"
log_info "Output directory: $OUTPUT_DIR"
