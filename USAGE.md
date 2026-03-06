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
- [Rendering Modes](#rendering-modes)
- [Supported Formats](#supported-formats)
- [Optional Dependencies](#optional-dependencies)
- [Troubleshooting](#troubleshooting)

---

## Opening a Preview

**Double-click** any supported file in Dolphin's file list. The preview opens with a smooth zoom-in animation directly inside the file browser.

Supported content types:
- **Images** -- always available (PNG, JPEG, WebP, SVG, GIF, TIFF, AVIF, HEIF, JXL, and more)
- **PDFs** -- requires `poppler-qt6` at build time
- **Videos** -- requires `qt6-multimedia` at build time

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

Double-click a `.pdf` file. The first page renders at 216 DPI for a quick, sharp preview.

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
| Load timeout (3s) | Preview auto-closes |

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

The first frame must arrive within **3 seconds**. If it doesn't (corrupted file, unsupported codec), the preview auto-closes.

### Codec Support

Video codec support depends on your system's multimedia backends:

- **GStreamer** -- most common on Linux, broad format support
- **FFmpeg** -- alternative backend on some distributions

Most Linux distributions include wide codec support out of the box. If a specific format doesn't play, install additional codec packages for your distribution.

## Rendering Modes

Quick Look automatically selects the best rendering mode for your system.

### GPU Rendering (Default)

Used when a hardware-accelerated OpenGL 2.1+ or ES 2.0+ context is available.

**Benefits:**
- Smooth animations at native refresh rate
- GLSL shader-based image sharpening (3x3 Gaussian unsharp mask)
- Efficient crossfade transitions via multi-texture blending
- Lower CPU usage during animation

**Excluded GPUs:** Software renderers (llvmpipe, softpipe, swrast) are detected and bypassed.

### Software Rendering (Fallback)

Used when GPU rendering is unavailable (virtual machines, remote sessions, minimal GPU drivers).

**Characteristics:**
- Pure QPainter rendering -- no GPU required
- Identical visual output to the GPU path
- May show lower frame rates during animation on slower hardware
- All features work the same (zoom, PDF navigation, video)

> You don't need to configure anything. The renderer is selected automatically at startup.

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

### PDF (Requires Poppler)

| Format | Extensions |
|--------|------------|
| PDF | `.pdf` |

Build with `poppler-qt6` to enable. Without it, PDF files open in the default application.

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

## Optional Dependencies

| Dependency | What It Enables | Package Name |
|------------|-----------------|--------------|
| Poppler (Qt6) | PDF preview | `poppler-qt6` (Arch), `poppler-qt6-devel` (Fedora), `libpoppler-qt6-dev` (Debian) |
| Qt6 Multimedia | Video preview | `qt6-multimedia` (Arch), `qt6-qtmultimedia-devel` (Fedora), `qt6-multimedia-dev` (Debian) |
| Qt6 Image Formats | AVIF, HEIF, JXL | `qt6-imageformats` (Arch), `qt6-qtimageformats` (Fedora), `qt6-image-formats-plugins` (Debian) |
| KDE Image Formats | Additional formats | `kimageformats` |

Image preview (PNG, JPEG, WebP, SVG, etc.) works without any optional dependencies.

## Troubleshooting

### Preview doesn't open

- **File type not supported** -- Quick Look only handles images, PDFs, and videos. Other files open with the default application.
- **PDF not opening** -- Dolphin was built without Poppler support. Rebuild with `poppler-qt6` installed.
- **Video not opening** -- Dolphin was built without Qt Multimedia. Rebuild with `qt6-multimedia` installed.

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

- **Software rendering** -- if your system fell back to CPU rendering, animations may be slower. Check your GPU drivers.
- **High-resolution display** -- on 4K+ displays, ensure your GPU drivers support hardware acceleration.

### PDF pages load slowly

- Large PDFs with complex vector graphics take longer to render at 216 DPI.
- Pages are rendered asynchronously -- the UI remains responsive during loading.
- Adjacent pages are prefetched, so the next/previous page is usually already cached.

### Video doesn't play / no audio

- Check that your system has GStreamer or FFmpeg codec support installed.
- On Arch: `sudo pacman -S gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav`
- On Fedora: `sudo dnf install gstreamer1-plugins-good gstreamer1-plugins-bad-free`
- On Ubuntu: `sudo apt install gstreamer1.0-plugins-good gstreamer1.0-plugins-bad`

### Zoom doesn't work

- Scroll wheel must be directly over the **content area** (the image/PDF), not the dark overlay border.
- Maximum zoom is 5.0x. If you're already at max, scrolling up has no effect.
- Right-click to reset zoom if the view seems stuck.

### Preview auto-closes immediately

- **Timeout** -- if a PDF page or video first frame doesn't load within 3 seconds, the preview auto-closes as a safety measure.
- This usually indicates a corrupted file or missing codec support.
