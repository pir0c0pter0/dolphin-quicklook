/*
 * SPDX-FileCopyrightText: 2026 Mario STJr
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "quicklookoverlay.h"

#include <QImageReader>
#include <QKeyEvent>
#include <QLabel>
#include <QMimeDatabase>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QResizeEvent>
#include <QTimer>

#ifdef HAVE_QTMULTIMEDIA
#include <QAudioOutput>
#include <QMediaPlayer>
#include <QVideoFrame>
#include <QVideoSink>
#endif

namespace {
    constexpr int CornerRadius = 6;
    constexpr int ShadowOffset = 4;
    constexpr int TextSpacing = 12;
    constexpr int TextHeight = 30;
    constexpr int BgAlphaMax = 180;
    constexpr int ShadowAlphaMax = 80;
    constexpr int ContentPadding = 40;
    constexpr int BottomExtraSpace = 50;
    constexpr int ContentVerticalShift = 20;
#ifdef HAVE_QTMULTIMEDIA
    constexpr int VideoLoadTimeoutMs = 3000;
    constexpr qreal DefaultVolume = 0.5;
#endif
}

#ifdef HAVE_POPPLER
#include <poppler-qt6.h>
#endif

QuickLookOverlay::QuickLookOverlay(QWidget *parent)
    : QWidget(parent)
    , m_animationProgress(0.0)
    , m_active(false)
    , m_contentType(ContentType::Image)
#ifdef HAVE_QTMULTIMEDIA
    , m_videoPhase(VideoPhase::Loading)
    , m_mediaPlayer(nullptr)
    , m_videoSink(nullptr)
    , m_audioOutput(nullptr)
    , m_videoLoadTimer(nullptr)
#endif
{
    setFocusPolicy(Qt::StrongFocus);
    hide();
}

QuickLookOverlay::~QuickLookOverlay()
{
#ifdef HAVE_QTMULTIMEDIA
    cleanupVideo();
#endif
}

bool QuickLookOverlay::isSupportedMimeType(const QString &mimeType)
{
    if (mimeType.startsWith(QLatin1String("image/"))) {
        return true;
    }

    if (mimeType == QLatin1String("application/pdf")) {
#ifdef HAVE_POPPLER
        return true;
#else
        return false;
#endif
    }

#ifdef HAVE_QTMULTIMEDIA
    if (mimeType.startsWith(QLatin1String("video/"))) {
        return true;
    }
#endif

    return false;
}

bool QuickLookOverlay::loadImage(const QString &filePath)
{
    QImageReader reader(filePath);
    reader.setAutoTransform(true);

    // Cap decoded size to 4K to prevent OOM on very large images
    const QSize maxSize(3840, 2160);
    const QSize imgSize = reader.size();
    if (imgSize.isValid() && (imgSize.width() > maxSize.width() || imgSize.height() > maxSize.height())) {
        QSize scaled = imgSize;
        scaled.scale(maxSize, Qt::KeepAspectRatio);
        reader.setScaledSize(scaled);
    }

    const QImage image = reader.read();
    if (image.isNull()) {
        return false;
    }
    m_pixmap = QPixmap::fromImage(image);
    m_contentType = ContentType::Image;
    m_statusText.clear();
    return true;
}

bool QuickLookOverlay::loadPdf(const QString &filePath)
{
#ifdef HAVE_POPPLER
    auto document = Poppler::Document::load(filePath);
    if (!document) {
        return false;
    }

    document->setRenderHint(Poppler::Document::Antialiasing);
    document->setRenderHint(Poppler::Document::TextAntialiasing);

    auto page = document->page(0);
    if (!page) {
        return false;
    }

    const QImage image = page->renderToImage(144, 144);
    if (image.isNull()) {
        return false;
    }

    m_pixmap = QPixmap::fromImage(image);
    m_contentType = ContentType::Pdf;

    const int totalPages = document->numPages();
    m_statusText = (totalPages > 1)
        ? QStringLiteral(" — %1 pages").arg(totalPages)
        : QStringLiteral(" — 1 page");

    return true;
#else
    Q_UNUSED(filePath)
    return false;
#endif
}

#ifdef HAVE_QTMULTIMEDIA
void QuickLookOverlay::setupVideo(const QUrl &fileUrl)
{
    cleanupVideo();

    m_contentType = ContentType::Video;
    m_videoPhase = VideoPhase::Loading;
    m_pixmap = QPixmap();
    m_statusText.clear();

    m_audioOutput = new QAudioOutput(this);
    m_audioOutput->setVolume(DefaultVolume);

    m_mediaPlayer = new QMediaPlayer(this);
    m_mediaPlayer->setAudioOutput(m_audioOutput);

    m_videoSink = new QVideoSink(this);
    m_mediaPlayer->setVideoOutput(m_videoSink);

    m_mediaPlayer->setSource(fileUrl);
    m_mediaPlayer->setLoops(QMediaPlayer::Infinite);

    m_videoLoadTimer = new QTimer(this);
    m_videoLoadTimer->setSingleShot(true);
    connect(m_videoLoadTimer, &QTimer::timeout, this, [this]() {
        if (m_videoPhase == VideoPhase::Loading) {
            m_active = false;
            cleanupVideo();
            hide();
            Q_EMIT previewClosed();
        }
    });
    m_videoLoadTimer->start(VideoLoadTimeoutMs);

    connect(m_mediaPlayer, &QMediaPlayer::errorOccurred, this, [this]() {
        m_active = false;
        cleanupVideo();
        hide();
        Q_EMIT previewClosed();
    });

    connect(m_videoSink, &QVideoSink::videoFrameChanged, this, [this](const QVideoFrame &frame) {
        QVideoFrame f = frame;
        if (!f.isValid()) {
            return;
        }

        const QImage image = f.toImage();
        if (image.isNull()) {
            return;
        }

        if (m_videoPhase == VideoPhase::Loading) {
            // First frame arrived — cancel timeout and use as thumbnail
            if (m_videoLoadTimer) {
                m_videoLoadTimer->stop();
                m_videoLoadTimer->deleteLater();
                m_videoLoadTimer = nullptr;
            }
            m_pixmap = QPixmap::fromImage(image);
            m_videoPhase = VideoPhase::Animating;
            m_mediaPlayer->pause();

            if (!parentWidget()) {
                return;
            }
            move(0, 0);
            resize(parentWidget()->size());
            show();
            raise();
            setFocus();
            startShowAnimation();
            return;
        }

        if (m_videoPhase == VideoPhase::Playing) {
            // Live frame — update pixmap and repaint
            m_pixmap = QPixmap::fromImage(image);
            update();
        }
    });

    m_mediaPlayer->play();
}

void QuickLookOverlay::cleanupVideo()
{
    if (m_videoLoadTimer) {
        m_videoLoadTimer->stop();
        m_videoLoadTimer->deleteLater();
        m_videoLoadTimer = nullptr;
    }
    if (m_mediaPlayer) {
        m_mediaPlayer->stop();
        m_mediaPlayer->deleteLater();
        m_mediaPlayer = nullptr;
    }
    if (m_videoSink) {
        m_videoSink->deleteLater();
        m_videoSink = nullptr;
    }
    if (m_audioOutput) {
        m_audioOutput->deleteLater();
        m_audioOutput = nullptr;
    }
}
#endif

void QuickLookOverlay::showPreview(const QUrl &fileUrl)
{
    // Cancel any in-progress animation to avoid race conditions
    m_animating = false;

    if (!fileUrl.isLocalFile()) {
        return;
    }

    const QString filePath = fileUrl.toLocalFile();
    QMimeDatabase mimeDb;
    const QString mimeType = mimeDb.mimeTypeForFile(filePath).name();

    bool loaded = false;

    if (mimeType.startsWith(QLatin1String("image/"))) {
        loaded = loadImage(filePath);
    } else if (mimeType == QLatin1String("application/pdf")) {
        loaded = loadPdf(filePath);
    }
#ifdef HAVE_QTMULTIMEDIA
    else if (mimeType.startsWith(QLatin1String("video/"))) {
        m_currentUrl = fileUrl;
        m_active = true;
        setupVideo(fileUrl);
        return;
    }
#endif

    if (!loaded) {
        return;
    }

    m_currentUrl = fileUrl;
    m_active = true;

    if (!parentWidget()) {
        return;
    }
    move(0, 0);
    resize(parentWidget()->size());
    show();
    raise();
    setFocus();

    startShowAnimation();
}

void QuickLookOverlay::hidePreview()
{
    if (!m_active) {
        return;
    }

#ifdef HAVE_QTMULTIMEDIA
    if (m_contentType == ContentType::Video) {
        // m_pixmap already has the last rendered frame
        if (m_mediaPlayer) {
            m_mediaPlayer->pause();
        }
        m_videoPhase = VideoPhase::Closing;
    }
#endif

    startHideAnimation();
}

bool QuickLookOverlay::isPreviewActive() const
{
    return m_active;
}

qreal QuickLookOverlay::animationProgress() const
{
    return m_animationProgress;
}

void QuickLookOverlay::setAnimationProgress(qreal progress)
{
    m_animationProgress = progress;
    update();
}

void QuickLookOverlay::advanceAnimation()
{
    if (!m_animating) {
        return;
    }

    const qreal elapsed = static_cast<qreal>(m_animTimer.elapsed());
    const qreal duration = qMax(1.0, static_cast<qreal>(m_animDuration));
    const qreal t = qBound(0.0, elapsed / duration, 1.0);
    const qreal easedT = m_easingCurve.valueForProgress(t);
    m_animationProgress = m_animStartValue + (m_animEndValue - m_animStartValue) * easedT;

    if (t >= 1.0) {
        m_animating = false;
        onAnimationFinished();
    }
}

void QuickLookOverlay::onAnimationFinished()
{
    if (m_animForward) {
#ifdef HAVE_QTMULTIMEDIA
        if (m_contentType == ContentType::Video && m_videoPhase == VideoPhase::Animating && m_mediaPlayer) {
            m_videoPhase = VideoPhase::Playing;
            m_mediaPlayer->play();
        }
#endif
    } else {
        m_active = false;
        m_pixmap = QPixmap();
#ifdef HAVE_QTMULTIMEDIA
        cleanupVideo();
#endif
        hide();
        Q_EMIT previewClosed();
    }
}

void QuickLookOverlay::paintEvent(QPaintEvent *event)
{
    Q_UNUSED(event)

    advanceAnimation();

    if (m_pixmap.isNull()) {
        if (m_animating) {
            update();
        }
        return;
    }

    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    // Theme-independent colors: semi-transparent black overlay, white text
    const QColor bgColor(0, 0, 0, static_cast<int>(BgAlphaMax * m_animationProgress));
    QColor shadowColor(0, 0, 0);
    const QColor textColor(255, 255, 255, static_cast<int>(255 * m_animationProgress));
    QFont labelFont = font();
    labelFont.setBold(true);

    // Background
    painter.fillRect(rect(), bgColor);

    const QRect targetRect = scaledContentRect();

#ifdef HAVE_QTMULTIMEDIA
    // During live video playback — draw frame at full size, no scale animation
    if (m_contentType == ContentType::Video && m_videoPhase == VideoPhase::Playing) {
        // Drop shadow
        shadowColor.setAlpha(ShadowAlphaMax);
        QRectF shadowRect = QRectF(targetRect).adjusted(0, 0, ShadowOffset, ShadowOffset);
        painter.setPen(Qt::NoPen);
        painter.setBrush(shadowColor);
        painter.drawRoundedRect(shadowRect, CornerRadius, CornerRadius);

        // Video frame with rounded corners
        QPainterPath clipPath;
        clipPath.addRoundedRect(QRectF(targetRect), CornerRadius, CornerRadius);
        painter.setClipPath(clipPath);
        painter.drawPixmap(targetRect, m_pixmap);
        painter.setClipping(false);

        // Filename
        painter.setPen(textColor);
        painter.setFont(labelFont);
        const QRect textRect(0, targetRect.bottom() + TextSpacing, width(), TextHeight);
        painter.drawText(textRect, Qt::AlignHCenter | Qt::AlignTop, m_currentUrl.fileName());
        if (m_animating) {
            update();
        }
        return;
    }
#endif

    // Image / PDF / Video thumbnail with scale animation
    const QPointF center = QRectF(targetRect).center();
    const qreal scale = 0.3 + 0.7 * m_animationProgress;
    const qreal w = targetRect.width() * scale;
    const qreal h = targetRect.height() * scale;
    const QRectF drawRect(center.x() - w / 2.0, center.y() - h / 2.0, w, h);

    // Drop shadow
    const int curShadowOffset = static_cast<int>(ShadowOffset * m_animationProgress);
    shadowColor.setAlpha(static_cast<int>(ShadowAlphaMax * m_animationProgress));
    QRectF shadowRect = drawRect.adjusted(curShadowOffset, curShadowOffset, curShadowOffset, curShadowOffset);
    painter.setPen(Qt::NoPen);
    painter.setBrush(shadowColor);
    painter.drawRoundedRect(shadowRect, CornerRadius, CornerRadius);

    // Content with rounded corners + fade
    painter.setOpacity(m_animationProgress);
    QPainterPath clipPath;
    clipPath.addRoundedRect(drawRect, CornerRadius, CornerRadius);
    painter.setClipPath(clipPath);
    painter.drawPixmap(drawRect.toRect(), m_pixmap);
    painter.setClipping(false);
    painter.setOpacity(1.0);

    // Filename + status
    const QString label = m_currentUrl.fileName() + m_statusText;
    painter.setPen(textColor);
    painter.setFont(labelFont);
    const QRect textRect(0, drawRect.bottom() + TextSpacing, width(), TextHeight);
    painter.drawText(textRect, Qt::AlignHCenter | Qt::AlignTop, label);

    // Schedule next frame if animation is still running
    if (m_animating) {
        update();
    }
}

void QuickLookOverlay::mouseDoubleClickEvent(QMouseEvent *event)
{
    Q_UNUSED(event)
    hidePreview();
}

void QuickLookOverlay::keyPressEvent(QKeyEvent *event)
{
    if (event->key() == Qt::Key_Escape || event->key() == Qt::Key_Space) {
        hidePreview();
        event->accept();
        return;
    }
    QWidget::keyPressEvent(event);
}

void QuickLookOverlay::resizeEvent(QResizeEvent *event)
{
    QWidget::resizeEvent(event);
    update();
}

void QuickLookOverlay::startShowAnimation()
{
    m_animStartValue = m_animationProgress;
    m_animEndValue = 1.0;
    m_animForward = true;
    m_animating = true;
    m_animTimer.start();
    update();
}

void QuickLookOverlay::startHideAnimation()
{
    m_animStartValue = m_animationProgress;
    m_animEndValue = 0.0;
    m_animForward = false;
    m_animating = true;
    m_animTimer.start();
    update();
}

QRect QuickLookOverlay::scaledContentRect() const
{
    const int maxW = width() - 2 * ContentPadding;
    const int maxH = height() - 2 * ContentPadding - BottomExtraSpace;

    QSize contentSize;
    if (!m_pixmap.isNull()) {
        contentSize = m_pixmap.size();
    } else {
        return {};
    }

    contentSize.scale(maxW, maxH, Qt::KeepAspectRatio);

    const int x = (width() - contentSize.width()) / 2;
    const int y = (height() - contentSize.height()) / 2 - ContentVerticalShift;

    return {x, y, contentSize.width(), contentSize.height()};
}
