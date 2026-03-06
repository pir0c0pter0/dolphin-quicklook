/*
 * SPDX-FileCopyrightText: 2026 pir0c0pter0
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef QUICKLOOKOVERLAY_H
#define QUICKLOOKOVERLAY_H

#include <QWidget>
#include <QUrl>

class QLabel;
class QPropertyAnimation;

/**
 * @brief Overlay widget that provides inline Quick Look preview for image files.
 *
 * Displays an image preview with zoom-in/zoom-out animation within the
 * Dolphin file list container area. Double-clicking the preview dismisses it.
 */
class QuickLookOverlay : public QWidget
{
    Q_OBJECT
    Q_PROPERTY(qreal animationProgress READ animationProgress WRITE setAnimationProgress)

public:
    explicit QuickLookOverlay(QWidget *parent = nullptr);
    ~QuickLookOverlay() override;

    /**
     * Shows the preview for the given image file URL with a zoom-in animation.
     */
    void showPreview(const QUrl &fileUrl);

    /**
     * Hides the preview with a zoom-out animation.
     */
    void hidePreview();

    /**
     * @return true if the overlay is currently visible or animating.
     */
    bool isPreviewActive() const;

    /**
     * @return true if the given MIME type is supported for preview.
     */
    static bool isSupportedMimeType(const QString &mimeType);

    qreal animationProgress() const;
    void setAnimationProgress(qreal progress);

Q_SIGNALS:
    void previewClosed();

protected:
    void paintEvent(QPaintEvent *event) override;
    void mouseDoubleClickEvent(QMouseEvent *event) override;
    void keyPressEvent(QKeyEvent *event) override;
    void resizeEvent(QResizeEvent *event) override;

private:
    void startShowAnimation();
    void startHideAnimation();
    QRect scaledImageRect() const;

    QPixmap m_pixmap;
    QUrl m_currentUrl;
    qreal m_animationProgress;
    bool m_active;

    QPropertyAnimation *m_animation;
};

#endif // QUICKLOOKOVERLAY_H
