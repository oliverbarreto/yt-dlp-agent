# YouTube Video Download Agent

A powerful, autonomous YouTube video downloader with intelligent organization, progress tracking, and concurrent downloads.

## 🚀 Features

- **🔄 Autonomous Operation**: No manual input required - runs completely hands-free
- **⚡ Concurrent Downloads**: Downloads up to 2 videos simultaneously for maximum speed
- **📁 Smart Organization**: Automatically creates category folders and organizes videos
- **📊 Real-time Progress**: Visual progress bar with completion percentage and counts
- **📝 Auto-tracking**: Updates progress automatically after each download
- **🕒 Timestamped Archives**: Archives completed download lists with timestamps
- **🎯 Intelligent Naming**: Uses metadata for descriptive filenames
- **🛡️ Error Handling**: Graceful error handling and folder creation
- **🧹 Clean Interface**: Terminal clearing and organized output

## 📁 Directory Structure

The script will create the following directory structure using the `WORKING_DIRECTORY` & `PROJECT_FOLDER` variables specified in the `.env` file. Example: `yt-dlp-agent → /Users/oliver/Downloads/yt-dlp-agent/VIDEOS/`

```
/Users/oliver/Downloads/yt-dlp-agent/
├── VIDEOS/
│   ├── CATEGORY 1/
│   ├── CATEGORY 2/
│   ├── CATEGORY 3/
│   └── [other categories...]
├── downloaded/
│   └── download_list_YYYYmmdd-HH:MM.md
├── download_list.md
└── download_videos.sh
```

## 📋 Tracking File Format

The `download_list.md` file should be organized as follows:

```markdown
# YouTube Video Download List

### CATEGORY 1

- [ ] https://www.youtube.com/watch?v=VIDEOID

### CATEGORY 2

- [ ] https://www.youtube.com/watch?v=VIDEOID
- [ ] https://www.youtube.com/watch?v=VIDEOID
```

**Important**: Categories must use the `### Category Name` format (title 3) for automatic folder creation.

## 🎯 Setup and Usage

### 1. Prerequisites

Ensure `yt-dlp` & `ffmpeg` are installed as a script using Homebrew:

```bash
brew install yt-dlp
brew install ffmpeg
```

### 2. Give Execution Permissions

```bash
chmod +x download_videos.sh
```

### 3. Configure the `.env` file

Configure the `.env` file with your preferred settings.

```bash
cp .env.example .env
```

Set the `WORKING_DIRECTORY` & `PROJECT_FOLDER` variables in the `.env` file. Then set the maximum concurrent downloads to the number of videos you want to download simultaneously `MAX_CONCURRENT_DOWNLOADS`

### 4. Add videos to download

Update the `download_list.md` file and add the videos you want to download to the categories you want. Use the format:

```markdown
### CATEGORY 1

- [ ] https://www.youtube.com/watch?v=VIDEOID

### CATEGORY 2

- [ ] https://www.youtube.com/watch?v=VIDEOID
```

### 5. Run the Download Agent

```bash
./download_videos.sh
```

### 5. Enjoy!

The script will run in the background and download the videos to the `VIDEOS` folder.

You can check the progress in the terminal and the `download_list.md` file will be updated automatically after each download. When the script is finished, it will move the `download_list.md` file to the `downloaded/` folder and archive it with a timestamp. It will also create a new `download_list.md` from the template `download_list_TEMPLATE.md`.

## 🔧 How It Works

### **Automatic Setup Phase:**

1. **Terminal Clearing**: Starts with a clean terminal interface
2. **Directory Creation**: Automatically creates working folders and category directories
3. **Structure Validation**: Ensures all necessary folders exist

### **Download Phase:**

1. **Video Detection**: Reads all pending videos from `download_list.md`
2. **Concurrent Processing**: Downloads up to 2 videos simultaneously
3. **Progress Tracking**: Shows real-time progress bar with completion status
4. **Auto-organization**: Saves videos to appropriate category folders
5. **Progress Updates**: Updates tracking file after each successful download

### **Completion Phase:**

1. **Final Progress**: Displays 100% completion status
2. **Summary Report**: Shows total, completed, and pending video counts
3. **File Archiving**: Moves `download_list.md` to `downloaded/download_list_YYYYmmdd-HH:MM.md`

## 📁 File Naming Convention

Downloaded videos use the format:

```
YYYYmmdd - CHANNEL_NAME - VIDEO_TITLE - VIDEO_ID - RESOLUTION.ext
```

**Example:**

```
20250824 - AI JASON - How to Build an AI Agent - UZb0if-7wGE - 1080p.mp4
```

## 📊 Progress Tracking

The script provides comprehensive progress information:

- **Visual Progress Bar**: `[████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 12/25 (48%)`
- **Real-time Updates**: Progress updates after each download completion
- **Status Counts**: Shows completed vs pending video counts
- **Category Processing**: Displays which category is currently being processed

## 🔄 Concurrent Download System

- **Maximum Concurrency**: 2 simultaneous downloads
- **Smart Queuing**: Automatically manages download queue
- **Resource Management**: Prevents system overload with intelligent delays
- **Background Processing**: Downloads run in background for smooth operation

## 📝 Output and Logging

- **Clear Status Messages**: Emoji-enhanced status updates
- **Progress Indicators**: Visual feedback for all operations
- **Error Handling**: Clear error messages for failed downloads
- **Completion Summary**: Comprehensive summary when finished

## 🛠️ Technical Details

- **Script Language**: Bash shell script
- **Dependencies**: yt-dlp, standard Unix tools
- **Compatibility**: macOS (tested on Darwin 24.5.0)
- **Concurrency**: Background job management with `wait` command
- **File Operations**: Safe file moving and directory creation

## 🚨 Troubleshooting

### Common Issues:

1. **yt-dlp not found**: Install with `pip install yt-dlp`
2. **Permission denied**: Run `chmod +x download_videos.sh`
3. **Category folders not created**: Ensure categories use `### Category Name` format
4. **Downloads fail**: Check internet connection and video availability

### Stopping the Script:

- Press `Ctrl+C` at any time to stop the download process
- The script will gracefully handle interruption

## 📈 Future Enhancements

The script is designed to be easily extensible for:

- Custom download quality preferences
- Additional metadata extraction
- Network retry mechanisms
- Custom progress reporting
- Integration with other tools

---

**Note**: This script automatically handles all setup tasks that were previously manual. The old `setup_downloads.sh` script is no longer needed and has been moved to the `scripts/` folder for reference.

---

## .env Variable Usage Analysis

### 1. **WORKING_DIRECTORY** (Line 113)

```bash
cd "$WORKING_DIRECTORY"
```

- Purpose: Sets the base directory for downloads
- Usage: Script changes to this directory before creating the project folder
- Example: `/Users/oliver/Downloads`
- Location in script: Line 113

### 2. **PROJECT_FOLDER** (Lines 116, 119)

```bash
mkdir -p "$PROJECT_FOLDER"
cd "$PROJECT_FOLDER"
```

- Purpose: Name of the project folder created inside WORKING_DIRECTORY
- Usage: Creates and navigates into this folder where all downloads are stored
- Final path structure: `$WORKING_DIRECTORY/$PROJECT_FOLDER/VIDEOS/`
- Example: `yt-dlp-agent` → `/Users/oliver/Downloads/yt-dlp-agent/VIDEOS/`
- Location in script: Lines 116, 119

### 3. **MAX_CONCURRENT_DOWNLOADS** (Lines 280, 311)

```bash
local max_concurrent="$MAX_CONCURRENT_DOWNLOADS"
while [ $current_downloads -ge $max_concurrent ]; do
```

- Purpose: Limits how many downloads run simultaneously
- Usage: Controls concurrency in the download loop
- Behavior: Waits when the limit is reached, then starts new downloads as others finish
- Location in script:
  - Line 280: Assigned to local variable
  - Line 311: Used in concurrency check loop

### 4. **DOWNLOAD_QUALITY** (Line 174)

```bash
yt-dlp -f "$DOWNLOAD_QUALITY" \
```

- Purpose: Sets the video quality/format for yt-dlp
- Usage: Passed directly to yt-dlp's `-f` (format) option
- Example: `"bestvideo[height<=1080]+bestaudio/best[height<=1080]"`
- Location in script: Line 174 (inside `download_video` function)

## How Variables Are Loaded

The script loads .env variables using this method (lines 10-37):

```bash
export $(cat .env | grep -v '^#' | xargs)
```

This:

- Reads the .env file
- Filters out comment lines (starting with `#`)
- Exports all variables to the shell environment
- Makes them available throughout the script

## Example of Configuration Flow

1. Script starts in: `/Users/oliver/Downloads/yt-dlp-agent/`
2. Changes to: `/Users/oliver/Downloads/` (WORKING_DIRECTORY)
3. Creates/enters: `yt-dlp-agent/` (PROJECT_FOLDER)
4. Final working directory: `/Users/oliver/Downloads/yt-dlp-agent/`
5. Videos saved to: `/Users/oliver/Downloads/yt-dlp-agent/VIDEOS/CATEGORY_NAME/`

Note: Since your WORKING_DIRECTORY and PROJECT_FOLDER combine to the same path as the script location, downloads end up in the same directory structure where the script runs, but it can be configured to save to a different directory.

All variables are used correctly and are essential for the script's operation.
