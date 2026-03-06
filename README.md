# Dolphin Quick Look

**macOS-style Quick Look for KDE Dolphin.** Double-click an image to preview it inline with a smooth animation. Double-click again (or press `Escape`) to return to the file list.

No external apps. No popups. Everything happens inside Dolphin.

---

## Features

- **Inline preview** — images open directly in the file list area, not in a separate window
- **Smooth animations** — zoom-in/zoom-out transitions (250ms, cubic ease-out)
- **Dark overlay** — semi-transparent background keeps focus on the image
- **Rounded corners & drop shadow** — clean, modern look
- **Filename display** — shown below the preview
- **Keyboard support** — `Escape` or `Space` to dismiss
- **Multiple formats** — PNG, JPEG, GIF, BMP, WebP, SVG, TIFF, ICO

## Demo

| Action | Result |
|--------|--------|
| Double-click image | Preview opens with zoom-in animation |
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
make -j$(nproc)

# Test without installing
./bin/dolphin

# Or install system-wide
sudo make install
```

### Build Dependencies

**Arch / CachyOS:**
```bash
sudo pacman -S base-devel cmake extra-cmake-modules qt6-base kio kitemviews kwindowsystem kbookmarks kconfig kconfigwidgets kcrash kiconthemes ki18n kwidgetsaddons
```

**Fedora:**
```bash
sudo dnf builddep dolphin
```

**Ubuntu / KDE Neon:**
```bash
sudo apt build-dep dolphin
```

### Uninstall

Reinstall the original Dolphin from your package manager:

```bash
# Arch / CachyOS
sudo pacman -S dolphin

# Fedora
sudo dnf reinstall dolphin

# Ubuntu / KDE Neon
sudo apt install --reinstall dolphin
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
| `src/views/dolphinview.cpp` | Intercepts image double-click to show overlay instead of opening external app |
| `src/CMakeLists.txt` | Added `quicklookoverlay.cpp` to the build |

### Architecture

```
DolphinView
  └── m_topLayout (QVBoxLayout)
        └── m_container (KItemListContainer)  ← file list lives here
              └── QuickLookOverlay             ← our overlay, parented to container
```

When an image file is double-clicked:

1. `DolphinView::slotItemActivated()` checks the MIME type
2. If it's a supported image type, `QuickLookOverlay::showPreview()` is called
3. The overlay resizes to fill the container and renders the image with a `QPropertyAnimation`
4. The file list remains underneath — it's just covered by the overlay
5. Double-click or `Escape` triggers `hidePreview()` which animates back out

The overlay uses custom `QPainter` rendering for smooth animations, rounded corners, and drop shadows without requiring QML or external dependencies.

## Supported Formats

| Format | MIME Type |
|--------|-----------|
| PNG | `image/png` |
| JPEG | `image/jpeg` |
| GIF | `image/gif` |
| BMP | `image/bmp` |
| WebP | `image/webp` |
| SVG | `image/svg+xml` |
| SVGZ | `image/svg+xml-compressed` |
| TIFF | `image/tiff` |
| ICO | `image/x-icon` |

## Roadmap

- [ ] PDF preview (via Poppler)
- [ ] Video preview (embedded player)
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
