#!/bin/bash

# YouTube Video Download Agent
# This script automatically downloads all videos from the list with up to 2 concurrent downloads

# Clear the terminal
clear

# Function to load environment variables from .env file
load_env() {
    if [ -f ".env" ]; then
        echo "🔧 Loading configuration from .env file..."
        export $(cat .env | grep -v '^#' | xargs)
        echo "✅ Configuration loaded successfully"
    else
        echo "⚠️  .env file not found, using default values"
        export WORKING_DIRECTORY="/Users/oliver/Downloads"
        export MAX_CONCURRENT_DOWNLOADS=2
        export DOWNLOAD_QUALITY="bestvideo[height<=1080]+bestaudio/best[height<=1080]"
    fi
}

# Load environment variables
load_env

# Check if download_list.md exists
if [ ! -f "download_list.md" ]; then
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
if ! grep -q "^### " download_list.md; then
    echo ""
    echo "❌ ERROR: Invalid download_list.md structure!"
    echo ""
    echo "📋 Your download_list.md file must contain:"
    echo "   - Categories marked with '### Category Name'"
    echo "   - Video URLs in the format: - [ ] https://www.youtube.com/watch?v=VIDEO_ID"
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

# Check if file contains video URLs
if ! grep -q "https://www.youtube.com/watch" download_list.md; then
    echo ""
    echo "❌ ERROR: No YouTube video URLs found!"
    echo ""
    echo "📋 Your download_list.md file must contain:"
    echo "   - At least one YouTube video URL"
    echo "   - URLs in the format: - [ ] https://www.youtube.com/watch?v=VIDEO_ID"
    echo ""
    echo "🔧 Please add video URLs to the file and run this script again."
    echo ""
    exit 1
fi

echo "✅ download_list.md structure validated successfully!"
echo ""

# Create working folder and category directories
echo "🔧 Setting up working directory and category folders..."

# Navigate to WORKING directory from .env file
cd "$WORKING_DIRECTORY"

# Create main yt-dlp-agent folder if it doesn't exist
mkdir -p yt-dlp-agent

# Navigate to the yt-dlp-agent directory
cd yt-dlp-agent

# Create VIDEOS folder if it doesn't exist
mkdir -p VIDEOS

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
    done < download_list.md
    
    echo "📁 Category folders created successfully!"
}

# Create category folders
create_category_folders

echo ""

# Check if yt-dlp is installed
if ! command -v yt-dlp &> /dev/null; then
    echo "❌ yt-dlp is not installed. Please install it first:"
    echo "pip install yt-dlp"
    exit 1
fi

echo "========================================================"
echo "🚀 YouTube Video Download Agent - Autonomous Mode"
echo "========================================================"
echo "Current directory: $(pwd)"
echo "yt-dlp version: $(yt-dlp --version)"
echo ""

# Function to download a single video
download_video() {
    local url="$1"
    local category="$2"
    local total_videos="$3"
    
    echo "🤖 Starting download: $url"
    echo "📁 Category: $category"
    
    # Create category directory inside VIDEOS if it doesn't exist
    mkdir -p "VIDEOS/$category"
    
    # Download with yt-dlp to the VIDEOS/CATEGORY folder with new filename format
    yt-dlp -f "$DOWNLOAD_QUALITY" \
           -o "VIDEOS/$category/%(upload_date)s - %(uploader)s - %(title)s - %(id)s - %(resolution)s.%(ext)s" \
           "$url"
    
    if [ $? -eq 0 ]; then
        echo "✅ Download completed successfully!"
        echo "💾 Saved to: VIDEOS/$category/"
        # Update the tracking file
        sed -i '' "s|- \[ \] $url|- [x] $url|" download_list.md
        echo "📝 Updated tracking file"
        
        # Update progress bar
        update_progress "$total_videos"
        echo ""  # New line after progress update
        
        return 0
    else
        echo "❌ Download failed for: $url"
        return 1
    fi
}

# Function to count videos by status
count_videos() {
    local status="$1"
    local count=0
    
    if [ "$status" = "pending" ]; then
        count=$(grep -c "^- \[ \]" download_list.md 2>/dev/null || echo "0")
    elif [ "$status" = "completed" ]; then
        count=$(grep -c "^- \[x\]" download_list.md 2>/dev/null || echo "0")
    fi
    
    echo "$count"
}

# Function to display progress bar
show_progress() {
    local completed="$1"
    local total="$2"
    local width=50
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

# Function to process downloads with concurrency control
process_downloads() {
    local max_concurrent="$MAX_CONCURRENT_DOWNLOADS"
    local current_downloads=0
    local total_videos=0
    local category=""
    
    # Count total videos
    total_videos=$(grep -c "https://www.youtube.com/watch" download_list.md)
    
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
        elif [[ $line =~ ^-[[:space:]]\[[[:space:]]\][[:space:]](https://www.youtube.com/watch[^[:space:]]+)$ ]]; then
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
    done < download_list.md
    
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
    echo "📁 All videos saved in VIDEOS/ folder structure"
    
    # Move download_list.md to downloaded folder with timestamp
    if [ -f "download_list.md" ]; then
        # Create downloaded folder if it doesn't exist
        mkdir -p downloaded
        
        # Generate timestamp in YYYYmmdd-hh:mm format
        timestamp=$(date +"%Y%m%d-%H:%M")
        new_filename="downloaded/download_list_${timestamp}.md"
        
        # Move the file
        mv download_list.md "$new_filename"
        echo "📄 Moved download list to: $new_filename"
    fi
}

# Main execution
echo "🤖 Starting autonomous download process..."
echo "Press Ctrl+C to stop at any time"
echo ""

# Start the autonomous download process
process_downloads