# Dolphin Quick Look -- User Manual

Complete guide to using the Quick Look feature in KDE Dolphin.

---

## Table of Contents

- [Opening a Preview](#opening-a-preview)
- [Closing a Preview](#closing-a-preview)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Mouse Controls](#mouse-controls)
- [Zooming](#zooming)
- [PDF Navigation](#pdf-navigation)
- [Video Playback](#video-playback)
- [Audio Playback](#audio-playback)
- [Rendering](#rendering)
- [Supported Formats](#supported-formats)
- [Optional Dependencies](#optional-dependencies)
- [Troubleshooting](#troubleshooting)

---

## Opening a Preview

**Double-click** any supported file in Dolphin's file list. The preview opens with a smooth zoom-in animation directly inside the file browser.

Supported content types:
- **Images** -- always available (PNG, JPEG, WebP, SVG, GIF, TIFF, AVIF, HEIF, JXL, and more)
- **PDFs** -- requires `qt6-pdf` (`Qt6::Pdf`) at build time
- **Videos** -- requires `qt6-multimedia` at build time
- **Audio** -- requires `qt6-multimedia` at build time

If the file is not a supported type, Dolphin opens it normally with the default application.

## Closing a Preview

Any of these will close the preview with a fade-out animation:

| Method | Description |
|--------|-------------|
| `Escape` | Press Escape key |
| `Space` | Press Space bar |
| Double-click | Double-click anywhere on the preview |

The overlay animates out (scales down from 1.0x to 0.3x over 250ms) and returns you to the file list.

## Keyboard Shortcuts

### General

| Key | Action |
|-----|--------|
| `Escape` | Close the preview |
| `Space` | Close the preview |

### PDF Only (multi-page documents)

| Key | Action |
|-----|--------|
| `Up Arrow` | Go to the previous page |
| `Page Up` | Go to the previous page |
| `Down Arrow` | Go to the next page |
| `Page Down` | Go to the next page |

> Page navigation keys only work when viewing a PDF with more than one page.

## Mouse Controls

### General

| Action | Result |
|--------|--------|
| Double-click the preview | Close the preview |
| Scroll wheel over the content | Zoom in / zoom out |

### When Zoomed In

| Action | Result |
|--------|--------|
| Left-click + drag | Pan around the zoomed image |
| Right-click | Reset zoom back to 1.0x (animated) |

> The cursor changes to an open hand when zoomed to indicate panning is available.

### PDF Navigation

| Action | Result |
|--------|--------|
| Click the up arrow (right side) | Go to the previous page |
| Click the down arrow (right side) | Go to the next page |

> Navigation arrows appear to the right of the PDF content. Disabled arrows appear faded (30% opacity) when you're at the first or last page.

## Zooming

Zoom lets you inspect images and PDFs in detail.

### How It Works

1. **Scroll up** over the preview content to zoom in
2. **Scroll down** to zoom out
3. Zoom follows your **cursor position** -- the point under your mouse stays fixed
4. **Drag** with left-click to pan around when zoomed
5. **Right-click** to smoothly reset back to 1.0x

### Zoom Specifications

| Property | Value |
|----------|-------|
| Minimum zoom | 1.0x (default) |
| Maximum zoom | 5.0x |
| Step per scroll | 0.15x |
| Reset animation | 200ms, cubic ease-out |

### Progressive Rendering

When you zoom in, the image is re-rendered at the new zoom level for maximum sharpness. This happens in the background -- you'll see a brief crossfade (150ms) when the higher-resolution version is ready.

## PDF Navigation

### Opening a PDF

Double-click a `.pdf` file. The first page renders at display-fit DPI for a sharp preview. PDF rendering uses Qt's built-in PDF engine (`Qt6::Pdf`), not Poppler.

### Password-Protected PDFs

If the PDF is password-protected, a dialog will prompt you to enter the password. You get up to **3 attempts** — after that, the preview is canceled and the file opens with the default application.

### Multi-Page Documents

If the PDF has more than one page:

1. **Arrow buttons** appear to the right of the content
   - Up arrow: previous page
   - Down arrow: next page
2. A **page indicator** shows "Page X of Y" below the preview
3. Pages load **asynchronously** -- a spinning loader appears while rendering
4. Pages **crossfade** into view (150ms transition) for smooth navigation

### Page Caching

- Up to **5 pages** are cached in memory (LRU eviction)
- **Adjacent pages** are prefetched automatically for instant navigation
- Cache is cleared when the preview is closed

### Loading Behavior

| State | What Happens |
|-------|--------------|
| Page loading | Spinner animation appears |
| Page ready | Crossfades into the new page |
| Load timeout (5s) | Preview auto-closes |

## Video Playback

### Opening a Video

Double-click a video file. Quick Look extracts the first frame as a thumbnail during the open animation, then starts playback automatically.

### Playback Behavior

| Property | Value |
|----------|-------|
| Looping | Yes, infinite loop |
| Audio | Plays at 50% volume |
| Auto-play | Starts after open animation completes |
| On close | Pauses immediately |

### Loading Behavior

The first frame must arrive within **5 seconds**. If it doesn't (corrupted file, unsupported codec), the preview auto-closes.

### Codec Support

Video codec support depends on your system's multimedia backends:

- **GStreamer** -- most common on Linux, broad format support
- **FFmpeg** -- alternative backend on some distributions

Most Linux distributions include wide codec support out of the box. If a specific format doesn't play, install additional codec packages for your distribution.

## Audio Playback

### Opening an Audio File

Double-click an audio file (MP3, FLAC, OGG, WAV, etc.). Quick Look displays a rotating vinyl record with a real-time spectrum analyzer.

### Visual Elements

| Element | Description |
|---------|-------------|
| Vinyl disc | Realistic rotating record with grooves and light reflections |
| Green center label | Conical gradient with depth overlay, mimics classic vinyl labels |
| Spectrum bars | 48 radial bars inside the center label, driven by real-time FFT analysis |
| Spindle hole | Small center dot completing the vinyl look |

### Playback Behavior

| Property | Value |
|----------|-------|
| Looping | Yes, infinite loop |
| Audio | Plays at 50% volume |
| Auto-play | Starts after open animation completes |
| On close | Pauses immediately |
| Time display | Shows current / total duration (h:mm:ss for tracks over 60 minutes) |

### Spectrum Analyzer

The spectrum visualization uses a 1024-point FFT window to analyze the audio in real-time:

- **48 frequency bars** arranged radially inside the vinyl's center label
- **Exponential smoothing** (0.35 new / 0.65 previous) for fluid animation
- **Logarithmic frequency mapping** -- bass frequencies get more visual space
- **Green gradient** bars matching the vinyl label color scheme
- Updates at ~30 FPS, synchronized with vinyl rotation

> **Decode buffer cap:** only the first ~2 minutes of decoded audio samples are retained (44.1 kHz mono equivalent). Playback continues normally for longer tracks, but the spectrum analyzer freezes past that point to keep memory bounded.

### Zoom

Zoom is **disabled** for audio content since the vinyl is a fixed-size visualization, not zoomable content.

### Codec Support

Audio codec support depends on your system's multimedia backends (same as video):

- **GStreamer** -- most common on Linux
- **FFmpeg** -- alternative backend

Common formats (MP3, FLAC, OGG, WAV) work out of the box on most distributions.

## Rendering

Quick Look uses pure QPainter rendering -- no OpenGL, no GPU dependency.

- `SmoothPixmapTransform` and `Antialiasing` render hints for crisp content at any scale
- Crossfade transitions via opacity blending between old and new content
- Rounded corners via QPainterPath clipping
- Works on every Linux system including VMs, Wayland-only setups, and headless environments

## Supported Formats

### Images (Always Available)

All formats supported by Qt's `QImageReader`:

| Format | Extensions |
|--------|------------|
| PNG | `.png` |
| JPEG | `.jpg`, `.jpeg` |
| GIF | `.gif` |
| BMP | `.bmp` |
| WebP | `.webp` |
| SVG / SVGZ | `.svg`, `.svgz` |
| TIFF | `.tif`, `.tiff` |
| ICO | `.ico` |
| XPM | `.xpm` |
| PBM / PGM / PPM | `.pbm`, `.pgm`, `.ppm` |
| AVIF | `.avif` * |
| HEIF / HEIC | `.heif`, `.heic` * |
| JPEG XL | `.jxl` * |

\* Requires `qt6-imageformats` or `kimageformats` to be installed.

### PDF (Requires Qt PDF)

| Format | Extensions |
|--------|------------|
| PDF | `.pdf` |

Build with `qt6-pdf` (`Qt6::Pdf`) to enable. Without it, PDF files open in the default application.

### Video (Requires Qt Multimedia)

| Format | Extensions |
|--------|------------|
| MP4 | `.mp4` |
| MKV | `.mkv` |
| WebM | `.webm` |
| AVI | `.avi` |
| MOV | `.mov` |
| OGV | `.ogv` |
| FLV | `.flv` |
| WMV | `.wmv` |
| M4V | `.m4v` |
| 3GP | `.3gp` |
| MPEG-TS | `.ts` |

Build with `qt6-multimedia` to enable. Without it, video files open in the default player.

### Audio (Requires Qt Multimedia)

| Format | Extensions |
|--------|------------|
| MP3 | `.mp3` |
| FLAC | `.flac` |
| OGG Vorbis | `.ogg` |
| WAV | `.wav` |
| AAC / M4A | `.aac`, `.m4a` |
| Opus | `.opus` |
| WMA | `.wma` |
| AIFF | `.aiff` |

Build with `qt6-multimedia` to enable. Without it, audio files open in the default player.

## Optional Dependencies

| Dependency | What It Enables | Package Name |
|------------|-----------------|--------------|
| Qt6 PDF | PDF preview | `qt6-pdf` (Arch), `qt6-qtpdf-devel` (Fedora), `libqt6pdf6-dev` (Debian) |
| Qt6 Multimedia | Video and audio preview | `qt6-multimedia` (Arch), `qt6-qtmultimedia-devel` (Fedora), `qt6-multimedia-dev` (Debian) |
| Qt6 Image Formats | AVIF, HEIF, JXL | `qt6-imageformats` (Arch), `qt6-qtimageformats` (Fedora), `qt6-image-formats-plugins` (Debian) |
| KDE Image Formats | Additional formats | `kimageformats` |

Image preview (PNG, JPEG, WebP, SVG, etc.) works without any optional dependencies.

## Troubleshooting

### Preview doesn't open

- **File type not supported** -- Quick Look only handles images, PDFs, videos, and audio files. Other files open with the default application.
- **PDF not opening** -- Dolphin was built without Qt PDF support. Rebuild with `qt6-pdf` / `qt6-qtpdf-devel` / `libqt6pdf6-dev` installed.
- **Video or audio not opening** -- Dolphin was built without Qt Multimedia. Rebuild with `qt6-multimedia` installed.

### HEIF/HEIC files don't load

Install the Qt image format plugins:

```bash
# Arch / CachyOS
sudo pacman -S qt6-imageformats

# Fedora
sudo dnf install qt6-qtimageformats

# Ubuntu / Debian
sudo apt install qt6-image-formats-plugins
```

### Animations are choppy

- **High-resolution display** -- on 4K+ displays, hi-res re-rendering may take slightly longer for very large images.

### PDF pages load slowly

- Large PDFs with complex vector graphics take longer to render at 216 DPI.
- Pages are rendered asynchronously -- the UI remains responsive during loading.
- Adjacent pages are prefetched, so the next/previous page is usually already cached.

### Video doesn't play / no audio / audio file shows no spectrum

- Check that your system has GStreamer or FFmpeg codec support installed.
- On Arch: `sudo pacman -S gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav`
- On Fedora: `sudo dnf install gstreamer1-plugins-good gstreamer1-plugins-bad-free`
- On Ubuntu: `sudo apt install gstreamer1.0-plugins-good gstreamer1.0-plugins-bad`
- For audio files: the vinyl will still rotate even if the audio decoder fails, but the spectrum bars won't appear. This usually means the codec is not installed.

### Zoom doesn't work

- Scroll wheel must be directly over the **content area** (the image/PDF), not the dark overlay border.
- Maximum zoom is 5.0x. If you're already at max, scrolling up has no effect.
- Right-click to reset zoom if the view seems stuck.

### Preview auto-closes immediately

- **Timeout** -- if a PDF page or video first frame doesn't load within 5 seconds, the preview auto-closes as a safety measure.
- This usually indicates a corrupted file or missing codec support.
