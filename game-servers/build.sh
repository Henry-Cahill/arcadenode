#!/bin/bash
# ArcadeNode Game Server Image Builder
# Builds all game server cartridge images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="${REGISTRY:-}"  # Optional: Set to push to a registry (e.g., "ghcr.io/username")
VERSION="${VERSION:-latest}"
PUSH="${PUSH:-false}"
PARALLEL="${PARALLEL:-false}"

# Image definitions
declare -A IMAGES=(
    ["minecraft"]="Minecraft Java Edition"
    ["minecraft-bedrock"]="Minecraft Bedrock Edition"
    ["project-zomboid"]="Project Zomboid"
    ["arma-reforger"]="Arma Reforger"
)

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         ArcadeNode Game Server Image Builder              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

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

usage() {
    echo "Usage: $0 [OPTIONS] [IMAGE...]"
    echo ""
    echo "Build ArcadeNode game server Docker images"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --version TAG   Set version tag (default: latest)"
    echo "  -r, --registry URL  Set registry URL for tagging"
    echo "  -p, --push          Push images after building"
    echo "  -P, --parallel      Build images in parallel"
    echo "  -l, --list          List available images"
    echo "  -c, --clean         Remove all arcadenode images"
    echo ""
    echo "Images:"
    echo "  minecraft           Minecraft Java Edition (Paper/Vanilla)"
    echo "  minecraft-bedrock   Minecraft Bedrock Edition"
    echo "  project-zomboid     Project Zomboid Dedicated Server"
    echo "  arma-reforger       Arma Reforger Dedicated Server"
    echo "  all                 Build all images (default)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build all images"
    echo "  $0 minecraft                 # Build only Minecraft Java"
    echo "  $0 -v 1.0.0 --push           # Build all with version tag and push"
    echo "  $0 -r ghcr.io/user -p        # Build, tag for registry, and push"
}

list_images() {
    echo "Available game server images:"
    echo ""
    for key in "${!IMAGES[@]}"; do
        echo "  - $key: ${IMAGES[$key]}"
    done
}

clean_images() {
    print_status "Removing all ArcadeNode game server images..."
    
    local images=$(docker images --filter "reference=arcadenode/*" -q 2>/dev/null)
    if [ -n "$images" ]; then
        docker rmi -f $images
        print_success "All ArcadeNode images removed"
    else
        print_warning "No ArcadeNode images found"
    fi
}

build_image() {
    local name=$1
    local description=${IMAGES[$name]}
    local image_name="arcadenode/${name}"
    local build_dir="${SCRIPT_DIR}/${name}"
    
    if [ ! -d "$build_dir" ]; then
        print_error "Directory not found: $build_dir"
        return 1
    fi
    
    print_status "Building ${description} (${image_name}:${VERSION})..."
    
    local start_time=$(date +%s)
    
    if docker build -t "${image_name}:${VERSION}" "$build_dir"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "${description} built successfully (${duration}s)"
        
        # Tag as latest if version is not latest
        if [ "$VERSION" != "latest" ]; then
            docker tag "${image_name}:${VERSION}" "${image_name}:latest"
        fi
        
        # Tag for registry if specified
        if [ -n "$REGISTRY" ]; then
            local registry_tag="${REGISTRY}/${name}:${VERSION}"
            docker tag "${image_name}:${VERSION}" "$registry_tag"
            print_status "Tagged as ${registry_tag}"
            
            if [ "$PUSH" = "true" ]; then
                print_status "Pushing ${registry_tag}..."
                docker push "$registry_tag"
                print_success "Pushed ${registry_tag}"
            fi
        elif [ "$PUSH" = "true" ]; then
            print_status "Pushing ${image_name}:${VERSION}..."
            docker push "${image_name}:${VERSION}"
            print_success "Pushed ${image_name}:${VERSION}"
        fi
        
        return 0
    else
        print_error "Failed to build ${description}"
        return 1
    fi
}

build_all() {
    local images_to_build=("$@")
    local failed=()
    local succeeded=()
    
    if [ "$PARALLEL" = "true" ]; then
        print_status "Building images in parallel..."
        local pids=()
        
        for name in "${images_to_build[@]}"; do
            build_image "$name" &
            pids+=($!)
        done
        
        for i in "${!pids[@]}"; do
            if wait ${pids[$i]}; then
                succeeded+=("${images_to_build[$i]}")
            else
                failed+=("${images_to_build[$i]}")
            fi
        done
    else
        for name in "${images_to_build[@]}"; do
            if build_image "$name"; then
                succeeded+=("$name")
            else
                failed+=("$name")
            fi
        done
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "                      Build Summary                         "
    echo "═══════════════════════════════════════════════════════════"
    
    if [ ${#succeeded[@]} -gt 0 ]; then
        print_success "Built: ${succeeded[*]}"
    fi
    
    if [ ${#failed[@]} -gt 0 ]; then
        print_error "Failed: ${failed[*]}"
        return 1
    fi
    
    echo ""
    print_success "All images built successfully!"
    
    # Show image sizes
    echo ""
    print_status "Image sizes:"
    docker images --filter "reference=arcadenode/*" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
}

# Parse arguments
IMAGES_TO_BUILD=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -p|--push)
            PUSH="true"
            shift
            ;;
        -P|--parallel)
            PARALLEL="true"
            shift
            ;;
        -l|--list)
            list_images
            exit 0
            ;;
        -c|--clean)
            clean_images
            exit 0
            ;;
        all)
            IMAGES_TO_BUILD=(${!IMAGES[@]})
            shift
            ;;
        *)
            if [[ -v "IMAGES[$1]" ]]; then
                IMAGES_TO_BUILD+=("$1")
            else
                print_error "Unknown image: $1"
                echo "Use --list to see available images"
                exit 1
            fi
            shift
            ;;
    esac
done

# Default to all images if none specified
if [ ${#IMAGES_TO_BUILD[@]} -eq 0 ]; then
    IMAGES_TO_BUILD=(${!IMAGES[@]})
fi

# Main execution
print_banner
print_status "Version: ${VERSION}"
print_status "Registry: ${REGISTRY:-none}"
print_status "Push: ${PUSH}"
print_status "Parallel: ${PARALLEL}"
print_status "Images: ${IMAGES_TO_BUILD[*]}"
echo ""

build_all "${IMAGES_TO_BUILD[@]}"
