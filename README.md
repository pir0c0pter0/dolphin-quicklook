# Dolphin Quick Look

**macOS-style Quick Look for KDE Dolphin.** Double-click an image, PDF, video, or audio file to preview it inline with smooth animations. Double-click again (or press `Escape`) to return to the file list.

No external apps. No popups. Everything happens inside Dolphin.

<p align="center">
  <img src="demo.gif" alt="Dolphin Quick Look Demo">
</p>

---

## Features

### Core

- **Inline preview** — files open directly in the file list area, not in a separate window
- **Smooth animations** — zoom-in/zoom-out transitions (250ms, cubic ease-out) with frame-driven rendering that syncs with your monitor's refresh rate (60Hz, 120Hz, 144Hz, 240Hz+)
- **Fade-out on close** — preview fades and scales down smoothly instead of disappearing abruptly
- **Dark overlay** — semi-transparent background keeps focus on the content
- **Rounded corners & drop shadow** — clean, modern look with dynamic shadow based on animation progress
- **Filename display** — shown below the preview

### Rendering

- **Pure QPainter** — zero OpenGL dependency, works on every Linux system including VMs, Wayland-only setups, and headless environments with no GPU
- **100% compatibility** — no GPU probing, no driver quirks, no fallback paths — one rendering pipeline that works everywhere
- **Smooth pixmap transform** — `SmoothPixmapTransform` and `Antialiasing` render hints for crisp content at any scale
- **Crossfade transitions** — opacity blending between old and new content for smooth page navigation and hi-res upgrades
- **Rounded corners** — QPainterPath clipping for clean, modern content presentation

### Image Preview

- **All Qt-supported formats** — PNG, JPEG, GIF, BMP, WebP, SVG, TIFF, ICO, AVIF, HEIF/HEIC, JXL, and more
- **Transparent image support** — alpha channel is preserved and composited over the dark overlay; drop shadow is automatically disabled for transparent images
- **Large image protection** — images larger than 4K are capped at 3840x2160 to prevent OOM
- **HEIF/HEIC detection** — warns when files cannot be opened due to missing `libheif` / `qt6-imageformats`

### Zoom

- **Scroll wheel zoom** — zoom from 1.0x to 5.0x in 0.15x increments
- **Cursor-centered** — zoom follows your mouse position, not the image center
- **Click & drag pan** — move around zoomed images with left-click drag (cursor changes to open hand)
- **Right-click reset** — smoothly animates back to 1.0x with a 200ms transition
- **Progressive rendering** — triggers high-resolution re-render at each new zoom level for sharp details

### PDF Preview (optional — requires Qt PDF)

- **First page preview** — renders the first page at display-fit DPI for instant, sharp display
- **Multi-page navigation** — browse pages with arrow keys, Page Up/Down, or clickable arrow buttons
- **Page indicator** — displays "Page X of Y" below the preview
- **Password-protected PDFs** — prompts for password with up to 3 attempts, then renders normally
- **High-quality rendering** — Qt PDF render options: `Antialiasing`, `TextAntialiasing` via `QPdfDocumentRenderOptions`
- **Async page rendering** — uses `QPdfPageRenderer` in multi-threaded mode; main UI stays responsive
- **Loading spinner** — smooth rotating conical gradient animation while pages load
- **Page cache** — LRU cache holds up to 5 pages with automatic adjacent-page prefetching
- **Crossfade transitions** — 150ms blend between pages for smooth navigation
- **Hi-res re-render** — after initial display, re-renders at higher DPI (up to 600) for zoom clarity

### Video Preview (optional — requires Qt Multimedia)

- **Inline playback** — videos play directly in the overlay, no external player
- **Looping** — continuous playback, restarts automatically
- **Audio** — plays at 50% volume by default
- **Smart loading** — extracts first frame as thumbnail, then starts playback after animation completes
- **Timeout protection** — auto-closes if first frame doesn't arrive within 5 seconds

### Audio Preview (optional — requires Qt Multimedia)

- **Rotating vinyl record** — realistic vinyl disc visualization with grooves, highlight reflections, green center label, and spindle hole
- **Real-time FFT spectrum** — 48-bar radial spectrum analyzer rendered inside the vinyl center label, driven by live audio decoding (first ~2 minutes of decoded samples are retained; longer tracks play normally but the spectrum freezes past the cap)
- **Smooth spectrum animation** — exponential smoothing (0.35/0.65 blend) prevents flickering between frames
- **Playback time display** — current position and total duration shown below the vinyl (supports h:mm:ss for long tracks)
- **Looping playback** — audio restarts automatically
- **Audio at 50% volume** — same default as video

### HiDPI Support

- **DPI-aware rendering** — all coordinates and text respect `devicePixelRatioF()`
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
sudo pacman -S base-devel git cmake extra-cmake-modules qt6-base qt6-multimedia qt6-pdf kio
```

**Fedora / Nobara:**
```bash
sudo dnf install git cmake extra-cmake-modules gcc-c++ qt6-qtbase-devel qt6-qtmultimedia-devel qt6-qtpdf-devel kf6-kio-devel
```

**Ubuntu / Debian / KDE Neon:**
```bash
sudo apt install git cmake build-essential extra-cmake-modules qt6-base-dev qt6-multimedia-dev libqt6pdf6-dev libkf6kio-dev
```

**openSUSE:**
```bash
sudo zypper install git cmake extra-cmake-modules qt6-base-devel qt6-multimedia-devel qt6-pdf-devel kf6-kio-devel
```

**Void Linux:**
```bash
sudo xbps-install git cmake extra-cmake-modules qt6-base-devel qt6-multimedia-devel qt6-pdf-devel kio-devel
```

**Gentoo:**
```bash
sudo emerge dev-vcs/git dev-build/cmake kde-frameworks/extra-cmake-modules dev-qt/qtbase dev-qt/qtmultimedia dev-qt/qtpdf kde-frameworks/kio
```

> **Note:** `qt6-multimedia` and `qt6-pdf` are optional. Without them, video/audio and PDF preview will be disabled respectively. Image preview always works.

> **Upstream target:** the patch is built against **Dolphin master** (KDE `invent.kde.org/system/dolphin` HEAD). Stable Dolphin releases (e.g. 24.x) use an older CMake variable name (`QT_REQUIRED_VERSION` instead of `QT_MIN_VERSION`) and the patch does not apply cleanly there. The installer pins a known-good upstream commit to keep builds reproducible.

### Uninstall

The patched build installs files alongside the distro's Dolphin package. To cleanly revert:

```bash
# 1. Remove files tracked by the patched build's cmake install:
sudo xargs rm -v < build/dolphin/build/install_manifest.txt

# 2. Reinstall the original Dolphin from your package manager:
#    (pick the line for your distro)
sudo pacman -S dolphin                           # Arch / CachyOS / EndeavourOS / Manjaro
sudo dnf reinstall dolphin                       # Fedora / Nobara
sudo apt install --reinstall dolphin             # Ubuntu / Debian / KDE Neon
sudo zypper install -f dolphin                   # openSUSE
sudo xbps-install -f dolphin                     # Void Linux
```

> Skipping step 1 can leave orphan files under `src/views/quicklook/` translations and KCM entries that the package manager won't touch.

## How It Works

The patch adds new files and modifies existing ones in Dolphin's source:

### New Files

| File | Purpose |
|------|---------|
| `src/views/quicklook/quicklookoverlay.h/cpp` | Overlay orchestrator: content loading, animation, rendering, input, zoom |
| `src/views/quicklook/quicklookconstants.h` | Shared layout constants (ContentPadding, BottomExtraSpace, FrameIntervalMs…) |
| `src/views/quicklook/quicklookpdfhandler.h/cpp` | PDF engine: Qt PDF rendering, page cache, async loading, password support |
| `src/views/quicklook/quicklookmediahandler.h/cpp` | Media engine: video playback, audio with vinyl/FFT visualization |

### Modified Files

| File | Change |
|------|--------|
| `src/views/dolphinview.h` | Added `QuickLookOverlay` member and forward declaration |
| `src/views/dolphinview.cpp` | Intercepts double-click on supported files to show overlay instead of opening external app |
| `src/CMakeLists.txt` | Added Quick Look sources, optional Qt PDF / Qt Multimedia |
| `CMakeLists.txt` | Added optional `find_package` for Qt PDF and Qt Multimedia |

> **No OpenGL dependency.** The entire rendering pipeline uses QPainter — no GPU drivers, no GL probing, no fallback paths. Works on every system that can run Qt.

### Architecture

```
DolphinView
  └── m_topLayout (QVBoxLayout)
        └── m_container (KItemListContainer)    <- file list lives here
              └── QuickLookOverlay               <- our overlay, parented to container
                    ├── QPainter                   <- rendering (no OpenGL)
                    ├── QuickLookPdfHandler        <- PDF engine (Qt PDF)
                    └── QuickLookMediaHandler      <- Video/audio engine (QtMultimedia)
```

When a supported file is double-clicked:

1. `DolphinView::slotItemActivated()` checks the MIME type
2. If supported, `QuickLookOverlay::showPreview()` routes to the right handler (image / PDF / video / audio)
3. The overlay resizes to fill the container and animates in (250ms cubic ease-out, scale 0.3→1.0)
4. Content is rendered via QPainter and composited with background, shadow, and rounded corners
5. The file list remains underneath — just covered by the overlay
6. Double-click or `Escape` triggers `hidePreview()` which animates back out

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

### PDF (optional -- requires Qt PDF)

| Format | Extension | MIME Type |
|--------|-----------|-----------|
| PDF | `.pdf` | `application/pdf` |

Renders pages with navigation. Requires `Qt6::Pdf` (package `qt6-pdf` / `qt6-qtpdf-devel` / `libqt6pdf6-dev` depending on distro) at build time.

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

- [x] Inline image preview with smooth animation
- [x] PDF preview with multi-page navigation and page cache
- [x] Password-protected PDF support
- [x] Video preview with inline playback and looping
- [x] Audio preview with rotating vinyl and real-time FFT spectrum
- [x] Pure QPainter rendering — 100% compatible, no OpenGL dependency
- [x] High-quality PDF rendering (Qt PDF antialiased + text-antialiased render options)
- [x] Zoom with scroll wheel (cursor-centered) and drag-to-pan
- [x] Progressive hi-res re-render with crossfade transitions
- [x] HiDPI / multi-DPI display support
- [x] Transparent image support (alpha compositing, no shadow)
- [x] Thread-safe async rendering with race condition protection
- [x] Submitted as upstream KDE Merge Request ([!1209](https://invent.kde.org/system/dolphin/-/merge_requests/1209))

## Contributing

Contributions are welcome! This is a proof-of-concept that could become a native Dolphin feature.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a Pull Request

## License

GPL-2.0-or-later -- same as KDE Dolphin.

## Credits

Built by [@pir0c0pter0](https://github.com/pir0c0pter0) (pir0c0pter0000@gmail.com) as a native KDE contribution.

Powered by KDE Frameworks 6, Qt 6, and a desire for better file previews on Linux.
