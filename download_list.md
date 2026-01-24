# YouTube Video Download List

**Created:** August 24, 2025 00:00  
**Status:** Initialized - Ready to start downloads

## Download Progress

### CATEGORY 1

### CATEGORY 2

### CATEGORY 3

---

## Download Commands

Use the following command format for each video:

```bash
yt-dlp -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" "URL" -o "%(category)s/%(title)s.%(ext)s"
```

## Notes

- Can run up to 2 concurrent downloads
- Update this file after each successful download by changing `- [ ]` to `- [x]`
