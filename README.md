# Dolphin Quick Look

**macOS-style Quick Look for KDE Dolphin.** Double-click an image to preview it inline with a smooth animation. Double-click again (or press `Escape`) to return to the file list.

No external apps. No popups. Everything happens inside Dolphin.

---

## Features

- **Inline preview** — images open directly in the file list area, not in a separate window
- **Smooth animations** — zoom-in/zoom-out transitions (250ms, cubic ease-out) with frame-driven rendering that syncs with your monitor's refresh rate (supports 60Hz, 120Hz, 144Hz, 240Hz+)
- **Dark overlay** — semi-transparent background keeps focus on the image
- **Rounded corners & drop shadow** — clean, modern look
- **Filename display** — shown below the preview
- **Keyboard support** — `Escape` or `Space` to dismiss
- **Multiple formats** — images, PDFs, and videos (see [Supported Formats](#supported-formats))
- **PDF preview** — renders the first page with page count (requires Poppler)
- **Video preview** — inline playback with looping and audio (requires Qt Multimedia)

## Demo

| Action | Result |
|--------|--------|
| Double-click image/PDF/video | Preview opens with zoom-in animation |
| Double-click preview | Preview closes with zoom-out animation |
| Press `Escape` or `Space` | Preview closes |

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

> **Note:** `qt6-multimedia` and `poppler-qt6` are optional. Without them, video and PDF preview will be disabled respectively. Image preview always works.

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

The patch adds two files and modifies three existing ones in Dolphin's source:

### New Files

| File | Purpose |
|------|---------|
| `src/views/quicklookoverlay.h` | Header for the Quick Look overlay widget |
| `src/views/quicklookoverlay.cpp` | Implementation: rendering, animation, input handling |

### Modified Files

| File | Change |
|------|--------|
| `src/views/dolphinview.h` | Added `QuickLookOverlay` member and forward declaration |
| `src/views/dolphinview.cpp` | Intercepts double-click on supported files to show overlay instead of opening external app |
| `src/CMakeLists.txt` | Added `quicklookoverlay.cpp` to the build, optional Poppler/Qt Multimedia |
| `CMakeLists.txt` | Added optional `find_package` for Poppler and Qt Multimedia |

### Architecture

```
DolphinView
  └── m_topLayout (QVBoxLayout)
        └── m_container (KItemListContainer)  ← file list lives here
              └── QuickLookOverlay             ← our overlay, parented to container
```

When a supported file is double-clicked:

1. `DolphinView::slotItemActivated()` checks the MIME type
2. If it's a supported type, `QuickLookOverlay::showPreview()` is called
3. The overlay resizes to fill the container and renders the image with a `QPropertyAnimation`
4. The file list remains underneath — it's just covered by the overlay
5. Double-click or `Escape` triggers `hidePreview()` which animates back out

The overlay uses custom `QPainter` rendering for smooth animations, rounded corners, and drop shadows without requiring QML or external dependencies.

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

### PDF (optional — requires Poppler)

| Format | Extension | MIME Type |
|--------|-----------|-----------|
| PDF | `.pdf` | `application/pdf` |

Renders the first page as a preview with page count displayed. Requires `poppler-qt6` at build time.

### Video (optional — requires Qt Multimedia)

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

## Roadmap

- [x] Inline image preview with animation
- [x] PDF preview (via Poppler)
- [x] Video preview (embedded player)
- [ ] Arrow key navigation (next/previous file while preview is open)
- [ ] Zoom with scroll wheel
- [ ] Submit as upstream KDE Merge Request

## Contributing

Contributions are welcome! This is a proof-of-concept that could become a native Dolphin feature.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a Pull Request

## License

GPL-2.0-or-later — same as KDE Dolphin.

## Credits

Built by [@pir0c0pter0](https://github.com/pir0c0pter0) as a native KDE contribution.

Powered by KDE Frameworks 6, Qt 6, and a desire for better file previews on Linux.
