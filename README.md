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

- **Scroll wheel zoom** — zoom from 1.0x to 5.0x, ~15% per scroll step
- **Cursor-centered** — zoom follows your mouse position, not the image center
- **Click & drag pan** — move around zoomed images with left-click drag (cursor changes to open hand)
- **Right-click reset** — smoothly animates back to 1.0x with a 200ms transition
- **Progressive rendering** — triggers high-resolution re-render at each new zoom level for sharp details

### PDF Preview (optional — requires Qt PDF)

- **First page preview** — renders the first page immediately so the PDF appears without delay
- **Multi-page navigation** — browse pages with arrow keys, Page Up/Down, or clickable arrow buttons
- **Page indicator** — displays "Page X of Y" below the preview
- **Password-protected PDFs** — prompts for password with up to 3 attempts, then renders normally
- **High-quality rendering** — pages render antialiased through Qt PDF's `QPdfPageRenderer`
- **Async page rendering** — uses `QPdfPageRenderer` in multi-threaded mode; main UI stays responsive
- **Loading spinner** — smooth rotating conical gradient animation while pages load
- **Page cache** — LRU cache holds up to 5 pages with automatic adjacent-page prefetching
- **Crossfade transitions** — 150ms blend between pages for smooth navigation
- **Hi-res re-render** — the initial preview renders at a fast low resolution, then re-renders at full display resolution (and higher while zoomed) for crisp detail

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

## Activation Mode

The default is **double-click** — tap any supported file twice and the preview opens immediately. Single Space on a selected item is also accepted (as an opt-in "prime then double-click" flow for users who prefer an explicit arm-then-open gesture).

Set in `~/.config/dolphinrc` under `[General]`:

```ini
[General]
QuickLookActivation=DoubleClickOnly       # default — double-click opens preview right away
# QuickLookActivation=PrimeThenDoubleClick  # opt-in — double-click only opens preview if Space was pressed first (otherwise normal open)
```

Close keys (`Escape`, `Space`, double-click on the preview) are the same in both modes.

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

### Atomic Fedora (Bazzite / Silverblue / Kinoite)

On an immutable `rpm-ostree` host, `/usr` is read-only and the build
toolchain is not in the base image, so `./install.sh` cannot work. Use the
atomic installer instead:

```bash
git clone https://github.com/pir0c0pter0/dolphin-quicklook.git
cd dolphin-quicklook
./scripts/install-bazzite.sh
```

It builds Dolphin inside a Toolbx container, installs into `~/.local` (no
`sudo`, no system changes, no reboot), and points the dock launcher and the
systemd user unit at the patched build. Re-run it any time to rebuild and
update after pulling a newer patch.

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
| `src/views/quicklook/quicklookcontroller.h/cpp` | Owns the overlay, the Space-prime timer, and the container eventFilter; reattaches across panes in split view |
| `src/views/quicklook/quicklookoverlay.h/cpp` | Overlay widget (pImpl'd): animation, rendering, input, zoom — dispatches to content handlers |
| `src/views/quicklook/quicklookcontenthandler.h/cpp` | Abstract base for content backends (open / close / statusText / logicalContentSize …) |
| `src/views/quicklook/quicklookimagehandler.h/cpp` | Image backend: progressive decode + async hi-res crossfade rerender |
| `src/views/quicklook/quicklookpdfhandler.h/cpp` | PDF backend: Qt PDF rendering, page cache, async loading, password support |
| `src/views/quicklook/quicklookmediahandler.h/cpp` | Media backend: video playback, audio with vinyl/FFT visualization |
| `src/views/quicklook/quicklookconstants.h` | Shared layout constants (ContentPadding, BottomExtraSpace, FrameIntervalMs…) |

### Modified Files

| File | Change |
|------|--------|
| `src/views/dolphinview.h` | Narrow seam: `aboutToActivateItem` signal, `consumeActivation()` slot, `itemListContainer()` accessor — no `QuickLook` string anywhere in the class |
| `src/views/dolphinview.cpp` | `slotItemActivated` emits `aboutToActivateItem` before the normal `itemActivated`, honours `consumeActivation()` |
| `src/dolphintabpage.h/cpp` | Owns `std::unique_ptr<QuickLookController>` per tab; retargets it via `activeViewChanged` so split view just works |
| `src/settings/dolphin_generalsettings.kcfg` | New `QuickLookActivation` enum (`DoubleClickOnly` default / `PrimeThenDoubleClick` opt-in) |
| `src/CMakeLists.txt` | Added Quick Look sources, optional Qt PDF / Qt Multimedia |
| `CMakeLists.txt` | Added optional `find_package` for Qt PDF and Qt Multimedia |

> **No OpenGL dependency.** The entire rendering pipeline uses QPainter — no GPU drivers, no GL probing, no fallback paths. Works on every system that can run Qt.

### Architecture

```
DolphinTabPage
  └── std::unique_ptr<QuickLookController>            <- one per tab, split-view aware
        └── QuickLookOverlay                           <- pImpl'd widget, reparented to active pane's container
              └── QuickLookContentHandler *            <- polymorphic slot
                    ├── QuickLookImageHandler          <- images (QImageReader + progressive hi-res)
                    ├── QuickLookPdfHandler            <- PDFs (Qt PDF)
                    └── QuickLookMediaHandler          <- video / audio (Qt Multimedia)

DolphinView                                           <- narrow seam only
  + Q_SIGNAL  aboutToActivateItem(KFileItem)          <- intercept point
  + Q_SLOT    consumeActivation()                     <- controller suppresses the default itemActivated
  + accessor  itemListContainer()                     <- controller uses it for reparenting + eventFilter
```

When a supported file is double-clicked:

1. `DolphinView::slotItemActivated` emits `aboutToActivateItem(item)` *before* the normal `itemActivated` emit
2. `QuickLookController::onAboutToActivateItem` checks the MIME type and activation mode (`DoubleClickOnly` always allows; `PrimeThenDoubleClick` requires a prior Space-press to arm the prime timer)
3. If allowed, the controller reparents and resizes the overlay to the active pane's container, calls `QuickLookOverlay::showPreview(url)`, and on success calls `view->consumeActivation()` so the normal `itemActivated` emit is suppressed
4. `QuickLookOverlay` routes through `QuickLookContentHandler *` to the right backend (image / PDF / video / audio) and animates in (250ms cubic ease-out, scale 0.3→1.0)
5. Content renders via QPainter over the dark overlay with rounded corners and a dynamic shadow
6. Double-click, `Escape`, or `Space` triggers `hidePreview()` which animates back out; on finish the overlay emits `previewClosed()` and releases content
7. Split view: `DolphinTabPage::activeViewChanged` fires whenever the user toggles panes; the controller detaches from the old view, reparents the overlay to the new pane's container, and re-wires its eventFilter — no second overlay needed

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
- [x] High-quality antialiased PDF rendering via Qt PDF
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
