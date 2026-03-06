/*
 * SPDX-FileCopyrightText: 2026 Mario STJr
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "quicklookoverlay.h"

#include <QEasingCurve>
#include <QImageReader>
#include <QKeyEvent>
#include <QLabel>
#include <QMimeDatabase>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QPropertyAnimation>
#include <QResizeEvent>

QuickLookOverlay::QuickLookOverlay(QWidget *parent)
    : QWidget(parent)
    , m_animationProgress(0.0)
    , m_active(false)
    , m_animation(new QPropertyAnimation(this, "animationProgress", this))
{
    setFocusPolicy(Qt::StrongFocus);
    hide();

    m_animation->setDuration(250);
    m_animation->setEasingCurve(QEasingCurve::OutCubic);
}

QuickLookOverlay::~QuickLookOverlay() = default;

bool QuickLookOverlay::isSupportedMimeType(const QString &mimeType)
{
    static const QStringList supported = {
        QStringLiteral("image/png"),
        QStringLiteral("image/jpeg"),
        QStringLiteral("image/gif"),
        QStringLiteral("image/bmp"),
        QStringLiteral("image/webp"),
        QStringLiteral("image/svg+xml"),
        QStringLiteral("image/svg+xml-compressed"),
        QStringLiteral("image/tiff"),
        QStringLiteral("image/x-icon"),
    };
    return supported.contains(mimeType);
}

void QuickLookOverlay::showPreview(const QUrl &fileUrl)
{
    if (!fileUrl.isLocalFile()) {
        return;
    }

    const QString filePath = fileUrl.toLocalFile();
    QImageReader reader(filePath);
    reader.setAutoTransform(true);
    const QImage image = reader.read();
    if (image.isNull()) {
        return;
    }

    m_pixmap = QPixmap::fromImage(image);
    m_currentUrl = fileUrl;
    m_active = true;

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

    if (progress <= 0.0 && m_animation->direction() == QAbstractAnimation::Backward) {
        m_active = false;
        hide();
        Q_EMIT previewClosed();
    }
}

void QuickLookOverlay::paintEvent(QPaintEvent *event)
{
    Q_UNUSED(event)

    if (m_pixmap.isNull()) {
        return;
    }

    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    // Background overlay with animated opacity
    const int bgAlpha = static_cast<int>(180 * m_animationProgress);
    painter.fillRect(rect(), QColor(0, 0, 0, bgAlpha));

    // Calculate target image rect (fit to widget, with padding)
    const QRect targetRect = scaledImageRect();

    // Animate from center point to full size
    const QPointF center = QRectF(targetRect).center();
    const qreal scale = 0.3 + 0.7 * m_animationProgress;
    const qreal w = targetRect.width() * scale;
    const qreal h = targetRect.height() * scale;
    const QRectF drawRect(center.x() - w / 2.0, center.y() - h / 2.0, w, h);

    // Drop shadow
    const int shadowOffset = static_cast<int>(4 * m_animationProgress);
    const int shadowAlpha = static_cast<int>(80 * m_animationProgress);
    QRectF shadowRect = drawRect.adjusted(shadowOffset, shadowOffset, shadowOffset, shadowOffset);
    painter.setPen(Qt::NoPen);
    painter.setBrush(QColor(0, 0, 0, shadowAlpha));
    painter.drawRoundedRect(shadowRect, 6, 6);

    // Image with rounded corners
    QPainterPath clipPath;
    clipPath.addRoundedRect(drawRect, 6, 6);
    painter.setClipPath(clipPath);
    painter.drawPixmap(drawRect.toRect(), m_pixmap);
    painter.setClipping(false);

    // Filename at the bottom
    const QString filename = m_currentUrl.fileName();
    const int textAlpha = static_cast<int>(255 * m_animationProgress);
    painter.setPen(QColor(255, 255, 255, textAlpha));
    QFont font = painter.font();
    font.setPointSize(11);
    font.setBold(true);
    painter.setFont(font);

    const QRect textRect(0, drawRect.bottom() + 12, width(), 30);
    painter.drawText(textRect, Qt::AlignHCenter | Qt::AlignTop, filename);
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
    m_animation->stop();
    m_animation->setDirection(QAbstractAnimation::Forward);
    m_animation->setStartValue(0.0);
    m_animation->setEndValue(1.0);
    m_animation->start();
}

void QuickLookOverlay::startHideAnimation()
{
    m_animation->stop();
    m_animation->setDirection(QAbstractAnimation::Backward);
    m_animation->setStartValue(0.0);
    m_animation->setEndValue(1.0);
    m_animation->start();
}

QRect QuickLookOverlay::scaledImageRect() const
{
    if (m_pixmap.isNull()) {
        return {};
    }

    const int padding = 40;
    const int maxW = width() - 2 * padding;
    const int maxH = height() - 2 * padding - 50; // extra space for filename

    QSize imgSize = m_pixmap.size();
    imgSize.scale(maxW, maxH, Qt::KeepAspectRatio);

    const int x = (width() - imgSize.width()) / 2;
    const int y = (height() - imgSize.height()) / 2 - 20;

    return {x, y, imgSize.width(), imgSize.height()};
}
