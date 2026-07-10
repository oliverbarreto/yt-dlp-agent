#!/bin/bash

# YouTube Video Download Agent
# This script automatically downloads all videos from the list with up to 2 concurrent downloads

# Clear the terminal
clear

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_LIST_PATH="$SCRIPT_DIR/download_list.md"
DOWNLOAD_LIST_TEMPLATE_PATH="$SCRIPT_DIR/download_list_TEMPLATE.md"

# Function to load environment variables from .env file
load_env() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        echo "🔧 Loading configuration from .env file..."
        export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
        echo "✅ Configuration loaded successfully"
    else
        echo ""
        echo "❌ ERROR: .env file not found!"
        echo ""
        echo "📋 To use this script, you need to:"
        echo "   1. Copy the template: cp .env.example .env"
        echo "   2. Edit .env and configure your settings:"
        echo "      - PROJECT_FOLDER: Subfolder under this project for media, or . for VIDEOS/ at project root"
        echo "      - MAX_CONCURRENT_DOWNLOADS: Set concurrent download limit"
        echo "      - DOWNLOAD_QUALITY: Set video quality preference"
        echo ""
        echo "🔧 Example configuration:"
        echo "   PROJECT_FOLDER=\".\"    # => <project>/VIDEOS/<category>/"
        echo "   PROJECT_FOLDER=\"media\"  # => <project>/media/VIDEOS/<category>/"
        echo "   MAX_CONCURRENT_DOWNLOADS=2"
        echo "   DOWNLOAD_QUALITY=\"bestvideo[height<=1080]+bestaudio/best[height<=1080]\""
        echo ""
        echo "⚠️  Please create and configure your .env file before running this script."
        echo ""
        exit 1
    fi
}

# Load environment variables
load_env

# Prefer Homebrew's isolated yt-dlp (libexec venv). The /opt/homebrew/bin/yt-dlp shim can
# shadow it and run an older pip-installed package from python@3.14 site-packages instead.
resolve_yt_dlp() {
    if [ -n "${YT_DLP:-}" ] && [ -x "$YT_DLP" ]; then
        echo "$YT_DLP"
        return 0
    fi
    if command -v brew &>/dev/null; then
        local brew_yt_dlp
        brew_yt_dlp="$(brew --prefix yt-dlp 2>/dev/null)/libexec/bin/yt-dlp"
        if [ -x "$brew_yt_dlp" ]; then
            echo "$brew_yt_dlp"
            return 0
        fi
    fi
    command -v yt-dlp 2>/dev/null
}

# Accept youtube.com and www.youtube.com watch URLs
YOUTUBE_URL_GREP='https://(www\.)?youtube\.com/watch'

# Check if download_list.md exists
if [ ! -f "$DOWNLOAD_LIST_PATH" ]; then
    echo ""
    echo "❌ ERROR: download_list.md file not found!"
    echo ""
    echo "📋 To use this script, you need to:"
    echo "   1. Copy the template: cp download_list_TEMPLATE.md download_list.md"
    echo "   2. Edit download_list.md and add your YouTube video URLs"
    echo "   3. Organize videos by categories using '### Category Name' format"
    echo ""
    echo "📁 Example structure:"
    echo "   ### CATEGORY 1"
    echo "   - [ ] https://www.youtube.com/watch?v=VIDEO_ID_1"
    echo "   - [ ] https://www.youtube.com/watch?v=VIDEO_ID_2"
    echo ""
    echo "   ### CATEGORY 2"
    echo "   - [ ] https://www.youtube.com/watch?v=VIDEO_ID_3"
    echo ""
    echo "🔧 After creating the file, run this script again."
    echo ""
    exit 1
fi

# Validate download_list.md structure
echo "🔍 Validating download_list.md structure..."

# Check if file contains categories
if ! grep -q "^### " "$DOWNLOAD_LIST_PATH"; then
    echo ""
    echo "❌ ERROR: Invalid download_list.md structure!"
    echo ""
    echo "📋 Your download_list.md file must contain:"
    echo "   - Categories marked with '### Category Name'"
    echo "   - Video URLs in the format: - [ ] https://youtube.com/watch?v=VIDEO_ID"
    echo ""
    echo "📁 Example structure:"
    echo "   ### CATEGORY 1"
    echo "   - [ ] https://www.youtube.com/watch?v=VIDEO_ID_1"
    echo "   - [ ] https://www.youtube.com/watch?v=VIDEO_ID_2"
    echo ""
    echo "🔧 Please fix the file structure and run this script again."
    echo ""
    exit 1
fi

# Check if file contains pending video URLs (- [ ] lines only)
if ! grep -qE "^- \[ \].*$YOUTUBE_URL_GREP" "$DOWNLOAD_LIST_PATH"; then
    echo ""
    echo "❌ ERROR: No pending YouTube video URLs found!"
    echo ""
    echo "📄 Checked: $DOWNLOAD_LIST_PATH"
    echo ""
    echo "📋 Your download_list.md file must contain at least one pending entry:"
    echo "   - [ ] https://youtube.com/watch?v=VIDEO_ID"
    echo ""
    echo "💡 If you just finished a run, the script resets this file from the template."
    echo "   Save your edits to download_list.md, then run the script again."
    echo ""
    exit 1
fi

echo "✅ download_list.md structure validated successfully!"
echo ""

# Video storage: <script_dir>/PROJECT_FOLDER/VIDEOS/<category>/  (not WORKING_DIRECTORY/Downloads)
# PROJECT_FOLDER of "." or empty => <script_dir>/VIDEOS/<category>/
echo "🔧 Setting up project media folders..."
if [ -z "${PROJECT_FOLDER:-}" ] || [ "$PROJECT_FOLDER" = "." ]; then
    MEDIA_BASE="$SCRIPT_DIR"
else
    MEDIA_BASE="$SCRIPT_DIR/$PROJECT_FOLDER"
fi
mkdir -p "$MEDIA_BASE/VIDEOS" || { echo "❌ ERROR: could not create $MEDIA_BASE/VIDEOS"; exit 1; }
cd "$MEDIA_BASE" || { echo "❌ ERROR: could not cd to $MEDIA_BASE"; exit 1; }
echo "📁 Video root: $MEDIA_BASE/VIDEOS/"

# Function to create category folders from download_list.md
create_category_folders() {
    echo "📁 Creating category folders from download list..."
    
    # Extract category names from download_list.md and create folders
    while IFS= read -r line; do
        if [[ $line =~ ^###[[:space:]](.+)$ ]]; then
            category="${BASH_REMATCH[1]}"
            if [ -n "$category" ]; then
                mkdir -p "VIDEOS/$category"
                echo "   ✅ Created folder: VIDEOS/$category"
            fi
        fi
    done < "$DOWNLOAD_LIST_PATH"
    
    echo "📁 Category folders created successfully!"
}

# Create category folders
create_category_folders

echo ""

# Resolve yt-dlp binary (Homebrew libexec first; override with YT_DLP in .env)
YT_DLP=$(resolve_yt_dlp)
if [ -z "$YT_DLP" ] || [ ! -x "$YT_DLP" ]; then
    echo "❌ yt-dlp is not installed. Please install it first:"
    echo "brew install yt-dlp"
    exit 1
fi

echo "========================================================"
echo "🚀 YouTube Video Download Agent - Autonomous Mode"
echo "========================================================"
echo "Current directory: $(pwd)"
echo "yt-dlp binary: $YT_DLP"
echo "yt-dlp version: $("$YT_DLP" --version)"
echo ""

# Max filename length (bytes) for a single path component; APFS is 255. Stay under to allow rename.
MAX_FILENAME_BYTES=255

# Length of a filename in bytes (UTF-8)
filename_byte_len() {
    printf '%s' "$1" | wc -c | tr -d ' '
}

# Shorten a single path component (basename) to at most max_bytes UTF-8 bytes, keeping the
# extension (last dot segment) intact. Truncates the stem from the right on a character boundary.
# Uses python3 when available; otherwise returns the name unchanged.
trim_filename_to_max_bytes() {
    local name="$1"
    local max_b="${2:-255}"
    if ! command -v python3 &>/dev/null; then
        printf '%s' "$name"
        return 0
    fi
    python3 - "$name" "$max_b" <<'END_TRIM_PY'
import sys
name, max_b = sys.argv[1], int(sys.argv[2])
b = name.encode("utf-8")
if len(b) <= max_b:
    print(name, end="")
    raise SystemExit(0)
idx = name.rfind(".")
if idx > 0:
    stem, ext = name[:idx], name[idx:]
else:
    stem, ext = name, ""
ext_b = ext.encode("utf-8")
max_stem = max_b - len(ext_b)
if max_stem < 1:
    s = b[:max_b]
    while s:
        try:
            print(s.decode("utf-8"), end="")
            break
        except UnicodeDecodeError:
            s = s[:-1]
    else:
        print("", end="")
    raise SystemExit(0)
s = stem.encode("utf-8")[:max_stem]
while s:
    try:
        print(s.decode("utf-8") + ext, end="")
        break
    except UnicodeDecodeError:
        s = s[:-1]
else:
    print(ext, end="")
END_TRIM_PY
}

# After yt-dlp finishes, the merged output is VIDEOS/$category/${video_id}.<ext>
# Pick the primary file if several matches exist (e.g. stray fragments), preferring the largest.
find_id_downloaded_file() {
    local category="$1"
    local video_id="$2"
    local best=""
    local best_size=0
    local f size
    shopt -s nullglob
    for f in "VIDEOS/$category/${video_id}."*; do
        [[ "$f" == *.part ]] && continue
        [[ -f "$f" ]] || continue
        size=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
        if [ -n "$size" ] && [ "$size" -gt "$best_size" ]; then
            best_size=$size
            best=$f
        fi
    done
    shopt -u nullglob
    echo "$best"
}

# Function to download a single video
download_video() {
    local url="$1"
    local category="$2"
    local total_videos="$3"
    local video_id=""
    local downloaded_file
    local target_path
    local target_base
    local blen

    echo "🤖 Starting download: $url"
    echo "📁 Category: $category"

    # YouTube id from watch URL (?v= or &v=)
    if [[ "$url" =~ [\?\&]v=([A-Za-z0-9_-]{6,12}) ]]; then
        video_id="${BASH_REMATCH[1]}"
    else
        echo "❌ Could not parse video id from URL: $url"
        return 1
    fi

    # Create category directory inside VIDEOS if it doesn't exist
    mkdir -p "VIDEOS/$category"

    # Use short id-based name during download+merge to avoid "Unable to rename .part" when the
    # final template path is too long (APFS ~255 bytes per name) or similar rename failures.
    local naming_pattern="%(upload_date)s - %(uploader)s - %(title)s - %(id)s - %(resolution)s.%(ext)s"

    if ! "$YT_DLP" -f "$DOWNLOAD_QUALITY" \
           -o "VIDEOS/$category/${video_id}.%(ext)s" \
           "$url"; then
        echo "❌ Download failed for: $url"
        return 1
    fi

    downloaded_file=$(find_id_downloaded_file "$category" "$video_id")
    if [ -z "$downloaded_file" ] || [ ! -f "$downloaded_file" ]; then
        echo "❌ No output file found after download (id=$video_id): $url"
        return 1
    fi

    # Desired name from the same format as before (metadata only, no re-download)
    target_path=$("$YT_DLP" -f "$DOWNLOAD_QUALITY" -o "VIDEOS/$category/$naming_pattern" \
        --print "%(filename)s" --skip-download "$url" 2>/dev/null | grep '^VIDEOS/' | tail -1)

    if [ -z "$target_path" ]; then
        echo "✅ Download completed; kept filename ${downloaded_file##*/} (could not build display name metadata)."
    else
        target_base="${target_path##*/}"
        blen=$(filename_byte_len "$target_base")
        if [ -n "$blen" ] && [ "$blen" -gt "$MAX_FILENAME_BYTES" ]; then
            echo "📎 Trimming filename (${blen} bytes → max ${MAX_FILENAME_BYTES}, keeping extension)..."
            target_base=$(trim_filename_to_max_bytes "$target_base" "$MAX_FILENAME_BYTES")
            target_path="VIDEOS/$category/$target_base"
        fi
        if [ "$downloaded_file" = "$target_path" ]; then
            echo "✅ Download completed successfully! 💾 $target_path"
        elif [ -e "$target_path" ] && [ ! "$downloaded_file" -ef "$target_path" ]; then
            echo "✅ Download completed; kept ${downloaded_file##*/} (target name already exists: $target_path)"
        elif mv -n "$downloaded_file" "$target_path" 2>/dev/null; then
            echo "✅ Download completed successfully!"
            echo "💾 Saved to: $target_path"
        else
            echo "✅ Download completed; kept id-based name after rename failed: ${downloaded_file##*/}"
        fi
    fi

    # Update the tracking file on any successful download (data on disk, even if we kept the id name)
    sed -i '' "s|- \[ \] $url|- [x] $url|" "$DOWNLOAD_LIST_PATH"
    echo "📝 Updated tracking file"

    update_progress "$total_videos"
    echo ""
    return 0
}

# Function to count videos by status
count_videos() {
    local status="$1"
    local count=0
    
    if [ "$status" = "pending" ]; then
        count=$(grep -c "^- \[ \]" "$DOWNLOAD_LIST_PATH" 2>/dev/null || echo "0")
    elif [ "$status" = "completed" ]; then
        count=$(grep -c "^- \[x\]" "$DOWNLOAD_LIST_PATH" 2>/dev/null || echo "0")
    fi
    
    # Trim whitespace and ensure it's a number
    count=$(echo "$count" | tr -d '[:space:]')
    if [ -z "$count" ] || ! [[ "$count" =~ ^[0-9]+$ ]]; then
        count=0
    fi
    
    echo "$count"
}

# Function to display progress bar
show_progress() {
    local completed="$1"
    local total="$2"
    local width=50
    
    # Trim whitespace and ensure both are numbers
    completed=$(echo "$completed" | tr -d '[:space:]')
    total=$(echo "$total" | tr -d '[:space:]')
    
    # Default to 0 if empty or not a number
    if [ -z "$completed" ] || ! [[ "$completed" =~ ^[0-9]+$ ]]; then
        completed=0
    fi
    if [ -z "$total" ] || ! [[ "$total" =~ ^[0-9]+$ ]]; then
        total=0
    fi
    
    # Handle division by zero
    if [ "$total" -eq 0 ]; then
        total=1
    fi
    local percentage=$((completed * 100 / total))
    local filled=$((completed * width / total))
    local empty=$((width - filled))
    
    # Create progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done
    
    # Display progress
    printf "\r📊 Progress: [%s] %d/%d (%d%%)" "$bar" "$completed" "$total" "$percentage"
}

# Function to update progress after each download
update_progress() {
    local completed=$(count_videos "completed")
    local total="$1"
    show_progress "$completed" "$total"
}

# Function to update the download_list.md file with completion status
update_download_list_status() {
    echo "📝 Updating download_list.md with completion status..."
    
    # Get current date and time
    local current_datetime=$(date +"%B %d, %Y %H:%M")
    
    # Update the date line (line 3)
    sed -i '' "3s/.*/**Created:** $current_datetime/" "$DOWNLOAD_LIST_PATH"
    
    # Update the status line (line 4)
    sed -i '' "4s/.*/**Status:** Finalized - All downloads completed/" "$DOWNLOAD_LIST_PATH"
    
    echo "✅ Download list status updated successfully!"
}

# Function to process downloads with concurrency control
process_downloads() {
    local max_concurrent="$MAX_CONCURRENT_DOWNLOADS"
    local current_downloads=0
    local total_videos=0
    local category=""
    
    # Count total videos
    total_videos=$(grep -cE "^- \[ \].*$YOUTUBE_URL_GREP" "$DOWNLOAD_LIST_PATH")
    
    echo "📊 Total videos to download: $total_videos"
    echo "🚀 Starting downloads with max $max_concurrent concurrent downloads..."
    echo ""
    
    # Show initial progress
    show_progress 0 "$total_videos"
    echo ""
    
    # Process each line in the file
    while IFS= read -r line; do
        # Check if this is a category header
        if [[ $line =~ ^###[[:space:]](.+)$ ]]; then
            category="${BASH_REMATCH[1]}"
            echo "📂 Processing category: $category"
        # Check if this is a video URL line (pending download)
        elif [[ $line =~ ^-[[:space:]]+\[[[:space:]]*\][[:space:]]+(https://(www\.)?youtube\.com/watch[^[:space:]]+)$ ]]; then
            url="${BASH_REMATCH[1]}"
            
            if [ -n "$category" ]; then
                echo "🎬 Found video: $url"
                echo "📁 Category: $category"
                
                # Wait if we've reached max concurrent downloads
                while [ $current_downloads -ge $max_concurrent ]; do
                    sleep 5
                    # Check if any downloads completed
                    current_downloads=$(jobs -r | wc -l)
                done
                
                # Start download in background
                echo "🚀 Starting download in background..."
                download_video "$url" "$category" "$total_videos" &
                current_downloads=$((current_downloads + 1))
                
                # Small delay to prevent overwhelming the system
                sleep 2
            else
                echo "⚠️  Warning: Found video URL but no category defined: $url"
            fi
        fi
    done < "$DOWNLOAD_LIST_PATH"
    
    # Wait for all background downloads to complete
    echo ""
    echo "⏳ Waiting for all downloads to complete..."
    wait
    
    # Show final progress
    echo ""
    show_progress "$(count_videos "completed")" "$total_videos"
    echo ""
    
    echo ""
    echo "🎉 All downloads completed!"
    echo "📊 Summary:"
    echo "   - Total videos: $total_videos"
    echo "   - Completed: $(count_videos "completed")"
    echo "   - Pending: $(count_videos "pending")"
    echo ""
    echo "📁 All videos saved under: ${MEDIA_BASE}/VIDEOS/"
    
    # Update download_list.md with completion status before moving
    update_download_list_status
    
    # Move download_list.md to downloaded folder with timestamp
    if [ -f "$DOWNLOAD_LIST_PATH" ]; then
        # Create downloaded folder if it doesn't exist (in script directory)
        mkdir -p "$SCRIPT_DIR/downloaded"
        
        # Generate timestamp in YYYYmmdd-hh:mm format
        timestamp=$(date +"%Y%m%d-%H:%M")
        new_filename="$SCRIPT_DIR/downloaded/download_list_${timestamp}.md"
        
        # Move the file
        mv "$DOWNLOAD_LIST_PATH" "$new_filename"
        echo "📄 Moved download list to: $new_filename"
        
        # Create new download_list.md from template for next session
        if [ -f "$DOWNLOAD_LIST_TEMPLATE_PATH" ]; then
            cp "$DOWNLOAD_LIST_TEMPLATE_PATH" "$DOWNLOAD_LIST_PATH"
            echo "📋 Created new download_list.md from template for next session"
        else
            echo "⚠️  Warning: download_list_TEMPLATE.md not found, cannot create new download list"
        fi
    fi
}

# Main execution
echo "🤖 Starting autonomous download process..."
echo "Press Ctrl+C to stop at any time"
echo ""

# Start the autonomous download process
process_downloads