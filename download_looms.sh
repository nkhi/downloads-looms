#!/bin/bash

# Loom Video Downloader with Audio Verification
# Only downloads videos that have audio streams
# Properly merges separate video+audio streams into single MP4

set -e  # Exit on error

# Configuration
OUTPUT_DIR="."
INPUT_FILE="loomurls.txt"
DRY_RUN=false
VERBOSE=false

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--verbose] [-o OUTPUT_DIR] [INPUT_FILE]"
            exit 1
            ;;
        *)
            INPUT_FILE="$1"
            shift
            ;;
    esac
done

# Check dependencies
if ! command -v yt-dlp &> /dev/null; then
    echo -e "${RED}Error: yt-dlp is not installed${NC}"
    echo "Install with: brew install yt-dlp"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}Error: ffmpeg is not installed${NC}"
    echo "Install with: brew install ffmpeg"
    exit 1
fi

if ! command -v ffprobe &> /dev/null; then
    echo -e "${RED}Error: ffprobe is not installed${NC}"
    echo "Install with: brew install ffmpeg"
    exit 1
fi

# Check input file
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: File '$INPUT_FILE' not found!${NC}"
    echo "Please create '$INPUT_FILE' with one Loom URL per line."
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to check if a URL has audio
has_audio() {
    local url="$1"
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Checking available formats...${NC}"
        yt-dlp -F "$url"
    fi
    
    # Get format info as JSON
    local formats=$(yt-dlp -J "$url" 2>/dev/null)
    
    # Check if any format has audio
    if echo "$formats" | grep -q '"acodec".*"none"' && ! echo "$formats" | grep -q '"acodec".*"[^n][^o][^n][^e]"'; then
        return 1  # No audio found
    fi
    
    # Also check for explicit audio-only or combined streams
    if echo "$formats" | grep -qE '"vcodec".*"none".*"acodec".*"[^n][^o][^n][^e]"|"acodec".*"[^n][^o][^n][^e]".*"vcodec".*"[^n][^o][^n][^e]"'; then
        return 0  # Audio found
    fi
    
    return 1  # Default to no audio
}

# Function to download a single video
download_video() {
    local url="$1"
    
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}Processing: $url${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    # Check if video has audio
    if ! has_audio "$url"; then
        echo -e "${RED}⚠️  SKIPPING: No audio stream detected for this video${NC}"
        echo -e "${YELLOW}This video will not be downloaded.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Audio stream detected${NC}"
    
    # Download with proper format selection and merging
    # Priority:
    # 1. http-transcoded (pre-merged MP4 with audio)
    # 2. bestvideo+bestaudio (merge best streams)
    # 3. best (single best format)
    
    local yt_dlp_opts=(
        --format "http-transcoded/bestvideo+bestaudio/best"
        --merge-output-format mp4
        --output "$OUTPUT_DIR/%(title)s.%(ext)s"
        --no-playlist
        --prefer-free-formats
    )
    
    if [ "$VERBOSE" = true ]; then
        yt_dlp_opts+=(--verbose)
    else
        yt_dlp_opts+=(--progress)
    fi
    
    echo -e "${GREEN}Downloading...${NC}"
    if yt-dlp "${yt_dlp_opts[@]}" "$url"; then
        echo -e "${GREEN}✓ Download complete${NC}"
        
        # Verify the downloaded file has audio
        local downloaded_file=$(yt-dlp --get-filename --output "$OUTPUT_DIR/%(title)s.mp4" "$url")
        if [ -f "$downloaded_file" ]; then
            if ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$downloaded_file" 2>/dev/null | grep -q .; then
                echo -e "${GREEN}✓ Audio verified in downloaded file${NC}"
            else
                echo -e "${YELLOW}⚠️  Warning: Could not verify audio in downloaded file${NC}"
            fi
        fi
        
        return 0
    else
        echo -e "${RED}✗ Download failed${NC}"
        return 1
    fi
}

# Main execution
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}=== DRY RUN MODE ===${NC}"
    echo -e "${YELLOW}Will download only the first URL to test the workflow${NC}\n"
    
    # Get first non-empty, non-comment line
    FIRST_URL=$(grep -vE '^\s*($|#)' "$INPUT_FILE" | head -n 1)
    
    if [ -z "$FIRST_URL" ]; then
        echo -e "${RED}No URLs found in $INPUT_FILE${NC}"
        exit 1
    fi
    
    download_video "$FIRST_URL"
    
    echo -e "\n${GREEN}=== DRY RUN COMPLETE ===${NC}"
    echo -e "${YELLOW}If successful, run without --dry-run to download all videos${NC}"
    exit 0
fi

# Process all URLs
echo -e "${GREEN}Reading URLs from $INPUT_FILE...${NC}"
echo -e "${GREEN}Downloading to $OUTPUT_DIR...${NC}\n"

SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

while IFS= read -r url || [ -n "$url" ]; do
    # Skip empty lines and comments
    [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
    
    if download_video "$url"; then
        ((SUCCESS_COUNT++))
    else
        if has_audio "$url"; then
            ((FAIL_COUNT++))
        else
            ((SKIP_COUNT++))
        fi
    fi
    
done < "$INPUT_FILE"

# Summary
echo -e "\n${BLUE}================================================${NC}"
echo -e "${BLUE}SUMMARY${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}Successfully downloaded: $SUCCESS_COUNT${NC}"
echo -e "${YELLOW}Skipped (no audio): $SKIP_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo -e "\n${GREEN}Done!${NC}"
