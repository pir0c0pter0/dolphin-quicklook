# Dolphin Quick Look user guide

This guide describes the patched build in this repository, not stock Dolphin.

## Open and close

1. Select one supported local file in Dolphin.
2. Double-click it to open the inline preview.
3. Press `Space` or `Escape` to close it.

Choose **Double-click** (default) or **Space key** under **Configure Dolphin → View → Open Quick Look with**. Remote URLs are not previewed. Unsupported or unavailable formats keep Dolphin's normal behavior.

## Controls

| Input | Result |
|---|---|
| Double-click or `Space` | Open the selected supported local file, according to the configured activation method |
| `Escape` | Close an active preview |
| Wheel | Zoom image or PDF from 1x to 5x |
| Left drag | Pan while zoomed |
| Right click | Reset zoom to 1x |
| `Up` / `Page Up` | Previous PDF page |
| `Down` / `Page Down` | Next PDF page |
| PDF arrow buttons | Previous or next page |

Audio visualization is not zoomable.

## Formats and optional backends

Quick Look dispatches by MIME type, then relies on the installed Qt backend to decode the file.

| Content | Build requirement | Runtime notes |
|---|---|---|
| Images | Qt GUI | Actual formats come from `QImageReader` and installed Qt/KDE image plugins |
| PDF | Qt PDF | Local files only; files above 64 MiB are rejected |
| Video | Qt Multimedia | Actual codecs come from the Qt multimedia backend |
| Audio | Qt Multimedia | Actual codecs come from the Qt multimedia backend |

Common PNG and JPEG support is normally present. AVIF, HEIF/HEIC, JPEG XL, video, and audio support varies by distribution and installed plugins. There is no Quick Look-specific HEIF warning; a failed decode simply means that backend cannot preview the file.

## Images and zoom

The initial image decode is scaled toward the available viewport when the image plugin supports scaled decoding. Zoom requests a new background decode and crossfades to it when ready. Render targets are bounded by the overlay's pixel-size limits, but this is not a general guarantee against memory use by every image decoder.

## PDFs

PDF documents are opened locally by Qt PDF. Document loading itself is synchronous. Pages are rendered asynchronously at sizes derived from the current viewport and zoom, not at a fixed DPI.

The preview keeps up to five preview-sized pages, prefetches adjacent pages, and does not cache high-resolution zoom renders. A spinner is shown while a page render is outstanding. There is no PDF page timeout.

Password-protected PDFs allow up to three attempts. The entered password is cleared from the document object after each attempt.

## Video and audio

Qt Multimedia starts playback after the preview is requested. Video loading fails if no first frame arrives within five seconds. Playback loops and uses 50% volume.

Audio shows a rotating record and a 48-bar FFT visualization. Decoded samples are retained up to an internal bounded buffer; playback can continue after the visualization reaches that buffer's end.

Available containers and codecs depend on the Qt Multimedia backend (commonly GStreamer or FFmpeg) and its installed codec packages.

## Rendering and animation

The overlay uses QPainter and a 16 ms frame timer for animations. A timer request is not a monitor-sync or refresh-rate guarantee; actual smoothness depends on Qt event delivery, the compositor, display, decoding work, and the machine.

Dolphin remains a graphical Qt application. Software painting removes an OpenGL-specific dependency from this feature, but does not make Dolphin usable in a headless environment without a Qt display platform.

## Troubleshooting

### The configured activation does nothing

- Confirm this is the patched binary: on atomic Fedora it is `$HOME/.local/bin/dolphin`.
- Confirm the intended method under **Configure Dolphin → View → Open Quick Look with**.
- Confirm one local file is selected.
- Close all Dolphin windows and restart the `plasma-dolphin.service` user service, or log out and back in.
- Rebuild after pulling changes; the patch is tied to the pinned Dolphin commit.

### A PDF is not previewed

Build again with the Qt PDF development package installed. PDFs over 64 MiB are deliberately rejected. Corrupt, unsupported, or password-locked documents can also fail.

### An image format is not previewed

Check the formats reported by the Qt image plugins installed by your distribution. Installing an image-format plugin can add formats, but package names vary; Quick Look does not bundle codecs.

### Video or audio fails

Install the multimedia codecs appropriate for the Qt backend and distribution, then restart Dolphin. The extension alone does not guarantee codec support.

### Build fails

The pinned source declares Qt 6.4 and KDE Frameworks 6.23. A stable distribution may satisfy Qt but not that development snapshot's Frameworks requirement. Use a matching development environment; do not retarget the patch to an arbitrary Dolphin release.

## Install, update, and remove

See [README.md](README.md#install-on-a-mutable-distribution) for the distinct mutable and atomic workflows. Atomic automatic updates use only the locally installed snapshot; approve a new revision by updating the checkout and rerunning:

```bash
./scripts/update-bazzite-hook.sh --install
```

Remove a mutable install with `./install.sh --uninstall`. Remove an atomic user install with `./scripts/install-bazzite.sh --uninstall`.
