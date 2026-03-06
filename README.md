# Dolphin Quick Look

**macOS-style Quick Look for KDE Dolphin.** Double-click an image, PDF, video, or audio file to preview it inline with smooth animations. Double-click again (or press `Escape`) to return to the file list.

No external apps. No popups. Everything happens inside Dolphin.

---

## Features

### Core

- **Inline preview** — files open directly in the file list area, not in a separate window
- **Smooth animations** — zoom-in/zoom-out transitions (250ms, cubic ease-out) with frame-driven rendering that syncs with your monitor's refresh rate (60Hz, 120Hz, 144Hz, 240Hz+)
- **Fade-out on close** — preview fades and scales down smoothly instead of disappearing abruptly
- **Dark overlay** — semi-transparent background keeps focus on the content
- **Rounded corners & drop shadow** — clean, modern look with dynamic shadow based on animation progress
- **Filename display** — shown below the preview

### GPU-Accelerated Rendering

- **Automatic GPU detection** — probes OpenGL 2.1+ / ES 2.0+ at startup, falls back to software if unavailable (llvmpipe, softpipe, swrast are detected and bypassed)
- **GLSL shader pipeline** — rounded rectangle SDF masking, Gaussian 3x3 unsharp mask sharpening (strength 0.2), crossfade transitions, and text overlay — all in a single fragment shader pass
- **Software fallback** — pure QPainter rendering path provides identical visuals on systems without GPU support

### Image Preview

- **All Qt-supported formats** — PNG, JPEG, GIF, BMP, WebP, SVG, TIFF, ICO, AVIF, HEIF/HEIC, JXL, and more
- **Transparent PNG support** — alpha channel is preserved and composited over the dark overlay
- **Image sharpening** — subtle GPU-accelerated unsharp mask (3x3 Gaussian kernel) for crisp rendering
- **Large image protection** — images larger than 4K are capped at 3840x2160 to prevent OOM
- **HEIF/HEIC detection** — warns when files cannot be opened due to missing `libheif` / `qt6-imageformats`

### Zoom

- **Scroll wheel zoom** — zoom from 1.0x to 5.0x in 0.15x increments
- **Cursor-centered** — zoom follows your mouse position, not the image center
- **Click & drag pan** — move around zoomed images with left-click drag (cursor changes to open hand)
- **Right-click reset** — smoothly animates back to 1.0x with a 200ms transition
- **Progressive rendering** — triggers high-resolution re-render at each new zoom level for sharp details

### PDF Preview (optional — requires Poppler)

- **First page preview** — renders the first page at 216 DPI for instant display
- **Multi-page navigation** — browse pages with arrow keys, Page Up/Down, or clickable arrow buttons
- **Page indicator** — displays "Page X of Y" below the preview
- **Async loading** — pages render in a background thread; main UI stays responsive
- **Loading spinner** — smooth rotating conical gradient animation while pages load
- **Page cache** — LRU cache holds up to 5 pages with automatic adjacent-page prefetching
- **Crossfade transitions** — 150ms blend between pages for smooth navigation
- **Timeout protection** — auto-closes if a page fails to load within 3 seconds

### Video Preview (optional — requires Qt Multimedia)

- **Inline playback** — videos play directly in the overlay, no external player
- **Looping** — continuous playback, restarts automatically
- **Audio** — plays at 50% volume by default
- **Smart loading** — extracts first frame as thumbnail, then starts playback after animation completes
- **Timeout protection** — auto-closes if first frame doesn't arrive within 3 seconds

### Audio Preview (optional — requires Qt Multimedia)

- **Rotating vinyl record** — realistic vinyl disc visualization with grooves, highlight reflections, green center label, and spindle hole
- **Real-time FFT spectrum** — 48-bar radial spectrum analyzer rendered inside the vinyl center label, driven by live audio decoding
- **Smooth spectrum animation** — exponential smoothing (0.35/0.65 blend) prevents flickering between frames
- **Playback time display** — current position and total duration shown below the vinyl (supports h:mm:ss for long tracks)
- **Looping playback** — audio restarts automatically
- **Audio at 50% volume** — same default as video

### HiDPI Support

- **DPI-aware text** — labels rendered at full device pixel ratio
- **Physical pixel coordinates** — all GL shader uniforms and texture uploads respect `devicePixelRatioF()`
- **Sharp on any display** — no blurry scaling on 2x/3x HiDPI screens

### Stability

- **Race condition protection** — async renders are canceled and awaited before content switches or destruction
- **Page navigation guard** — stale render results are discarded if the user navigated away
- **Active state checks** — async callbacks bail out if the preview was closed
- **Video phase management** — enum-based state machine prevents frame processing conflicts
- **Audio decoder error handling** — graceful fallback when audio decoding fails
- **Null guards** — defensive checks throughout to prevent crashes on edge cases

## Demo

| Action | Result |
|--------|--------|
| Double-click image/PDF/video/audio | Preview opens with zoom-in animation |
| Double-click preview | Preview closes with fade-out animation |
| Press `Escape` or `Space` | Preview closes |
| Scroll wheel over preview | Zoom in/out (1x-5x) |
| Drag while zoomed | Pan the image |
| Right-click while zoomed | Reset zoom to 1x |
| Up/Down arrows (PDF) | Navigate pages |

## Installation

### Quick Install (Recommended)

```bash
git clone https://github.com/pir0c0pter0/dolphin-quicklook.git
cd dolphin-quicklook
./install.sh
```

The script will:
1. Clone KDE Dolphin source
2. Apply the Quick Look patch
3. Build Dolphin
4. Optionally install (replaces system Dolphin)

### Manual Install

```bash
# Clone Dolphin
git clone --depth 1 https://invent.kde.org/system/dolphin.git
cd dolphin

# Apply patch
git apply /path/to/dolphin-quicklook/patches/dolphin-quicklook.patch

# Build
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build . -j$(nproc)

# Test without installing
./bin/dolphin

# Or install system-wide
sudo cmake --install .
```

### Build Dependencies

**Arch / CachyOS / EndeavourOS / Manjaro:**
```bash
sudo pacman -S base-devel git cmake extra-cmake-modules qt6-base qt6-multimedia kio poppler-qt6
```

**Fedora / Nobara:**
```bash
sudo dnf install git cmake extra-cmake-modules gcc-c++ qt6-qtbase-devel qt6-qtmultimedia-devel kf6-kio-devel poppler-qt6-devel
```

**Ubuntu / Debian / KDE Neon:**
```bash
sudo apt install git cmake build-essential extra-cmake-modules qt6-base-dev qt6-multimedia-dev libkf6kio-dev libpoppler-qt6-dev
```

**openSUSE:**
```bash
sudo zypper install git cmake extra-cmake-modules qt6-base-devel qt6-multimedia-devel kf6-kio-devel libpoppler-qt6-devel
```

**Void Linux:**
```bash
sudo xbps-install git cmake extra-cmake-modules qt6-base-devel qt6-multimedia-devel kio-devel poppler-qt6-devel
```

**Gentoo:**
```bash
sudo emerge dev-vcs/git dev-build/cmake kde-frameworks/extra-cmake-modules dev-qt/qtbase dev-qt/qtmultimedia kde-frameworks/kio app-text/poppler[qt6]
```

> **Note:** `qt6-multimedia` and `poppler-qt6` are optional. Without them, video/audio and PDF preview will be disabled respectively. Image preview always works.

### Uninstall

Reinstall the original Dolphin from your package manager:

```bash
# Arch / CachyOS / EndeavourOS / Manjaro
sudo pacman -S dolphin

# Fedora / Nobara
sudo dnf reinstall dolphin

# Ubuntu / Debian / KDE Neon
sudo apt install --reinstall dolphin

# openSUSE
sudo zypper install -f dolphin

# Void Linux
sudo xbps-install -f dolphin
```

## How It Works

The patch adds new files and modifies existing ones in Dolphin's source:

### New Files

| File | Purpose |
|------|---------|
| `src/views/quicklookoverlay.h` | Quick Look overlay widget header |
| `src/views/quicklookoverlay.cpp` | Overlay logic: content loading, animation, input handling |
| `src/views/quicklookglrenderer.h` | GPU renderer header (OpenGL) |
| `src/views/quicklookglrenderer.cpp` | GPU-accelerated rendering via GLSL shaders |
| `src/views/quicklookrenderer.h` | Abstract renderer base class |
| `src/views/quicklookswrenderer.h` | Software renderer header |
| `src/views/quicklookswrenderer.cpp` | CPU-based rendering via QPainter |

### Modified Files

| File | Change |
|------|--------|
| `src/views/dolphinview.h` | Added `QuickLookOverlay` member and forward declaration |
| `src/views/dolphinview.cpp` | Intercepts double-click on supported files to show overlay instead of opening external app |
| `src/CMakeLists.txt` | Added Quick Look sources, optional Poppler/Qt Multimedia |
| `CMakeLists.txt` | Added optional `find_package` for Poppler and Qt Multimedia |

### Architecture

```
DolphinView
  └── m_topLayout (QVBoxLayout)
        └── m_container (KItemListContainer)  <- file list lives here
              └── QuickLookOverlay             <- our overlay, parented to container
                    ├── QuickLookGLRenderer    <- GPU path (default)
                    └── QuickLookSWRenderer    <- CPU fallback
```

When a supported file is double-clicked:

1. `DolphinView::slotItemActivated()` checks the MIME type
2. If it's a supported type, `QuickLookOverlay::showPreview()` is called
3. The overlay resizes to fill the container and renders the content with a `QPropertyAnimation`
4. The file list remains underneath — it's just covered by the overlay
5. Double-click or `Escape` triggers `hidePreview()` which animates back out

## Supported Formats

### Images (always available)

Any format supported by Qt's `QImageReader`, including:

| Format | Extension | MIME Type |
|--------|-----------|-----------|
| PNG | `.png` | `image/png` |
| JPEG | `.jpg`, `.jpeg` | `image/jpeg` |
| GIF | `.gif` | `image/gif` |
| BMP | `.bmp` | `image/bmp` |
| WebP | `.webp` | `image/webp` |
| SVG | `.svg` | `image/svg+xml` |
| SVGZ | `.svgz` | `image/svg+xml-compressed` |
| TIFF | `.tif`, `.tiff` | `image/tiff` |
| ICO | `.ico` | `image/x-icon` |
| XPM | `.xpm` | `image/x-xpixmap` |
| PBM / PGM / PPM | `.pbm`, `.pgm`, `.ppm` | `image/x-portable-bitmap` etc. |
| AVIF | `.avif` | `image/avif` |
| HEIF / HEIC | `.heif`, `.heic` | `image/heif` |
| JXL (JPEG XL) | `.jxl` | `image/jxl` |

> **Note:** AVIF, HEIF/HEIC, and JXL support depends on Qt image plugins installed on your system (e.g., `qt6-imageformats` or `kimageformats`).

### PDF (optional -- requires Poppler)

| Format | Extension | MIME Type |
|--------|-----------|-----------|
| PDF | `.pdf` | `application/pdf` |

Renders pages with navigation. Requires `poppler-qt6` at build time.

### Video (optional -- requires Qt Multimedia)

| Format | Extension | MIME Type |
|--------|-----------|-----------|
| MP4 | `.mp4` | `video/mp4` |
| MKV | `.mkv` | `video/x-matroska` |
| WebM | `.webm` | `video/webm` |
| AVI | `.avi` | `video/x-msvideo` |
| MOV | `.mov` | `video/quicktime` |
| OGV | `.ogv` | `video/ogg` |
| FLV | `.flv` | `video/x-flv` |
| WMV | `.wmv` | `video/x-ms-wmv` |
| M4V | `.m4v` | `video/x-m4v` |
| 3GP | `.3gp` | `video/3gpp` |
| TS | `.ts` | `video/mp2t` |

> **Note:** Actual codec support depends on your system's GStreamer or FFmpeg backends. Most Linux distributions ship with broad codec support out of the box.

Videos play inline with looping and audio. Requires `qt6-multimedia` at build time.

### Audio (optional -- requires Qt Multimedia)

| Format | Extension | MIME Type |
|--------|-----------|-----------|
| MP3 | `.mp3` | `audio/mpeg` |
| FLAC | `.flac` | `audio/flac` |
| OGG Vorbis | `.ogg` | `audio/ogg` |
| WAV | `.wav` | `audio/wav` |
| AAC / M4A | `.aac`, `.m4a` | `audio/aac`, `audio/mp4` |
| Opus | `.opus` | `audio/opus` |
| WMA | `.wma` | `audio/x-ms-wma` |
| AIFF | `.aiff` | `audio/aiff` |

> **Note:** Actual codec support depends on your system's GStreamer or FFmpeg backends.

Audio files display a rotating vinyl record with a real-time FFT spectrum analyzer. Requires `qt6-multimedia` at build time.

## Roadmap

- [x] Inline image preview with animation
- [x] PDF preview with multi-page navigation
- [x] Video preview with inline playback
- [x] Audio preview with vinyl visualization and FFT spectrum
- [x] GPU-accelerated rendering with software fallback
- [x] Zoom with scroll wheel and pan
- [x] HiDPI support
- [ ] Submit as upstream KDE Merge Request

## Contributing

Contributions are welcome! This is a proof-of-concept that could become a native Dolphin feature.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a Pull Request

## License

GPL-2.0-or-later -- same as KDE Dolphin.

## Credits

Built by [@pir0c0pter0](https://github.com/pir0c0pter0) as a native KDE contribution.

Powered by KDE Frameworks 6, Qt 6, and a desire for better file previews on Linux.
