// lib/features/stage21/presentation/pages/material_weight_measurement_view_page.dart
//
// FIX: Images now open in a full-screen in-app viewer (InteractiveViewer
// with pinch-to-zoom).  Only PDFs are still launched in the external browser.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/material_weight_measurement_model.dart';

class MaterialWeightMeasurementViewPage extends StatelessWidget {
  final MwmDetailModel detail;

  const MaterialWeightMeasurementViewPage({super.key, required this.detail});

  static const Color _accent = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('View Measurement',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetaCard(),
            const SizedBox(height: 12),
            _buildTotalBox(),
            const SizedBox(height: 16),
            ...detail.entries.asMap().entries.map(
                  (e) => _buildEntryBlock(context, e.key, e.value),
                ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Header meta card ────────────────────────────────────────────────────────

  Widget _buildMetaCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('WR/MWM',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const Expanded(
                child: Text(
                  'WISE REALTY — Material Weight Measurement',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              Text('No. ${detail.mwmNo}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const Divider(height: 16),
          _metaGrid([
            _MetaItem('MWM No.', detail.mwmNo),
            _MetaItem('Date', detail.measurementDateFormatted),
            _MetaItem('Created By', detail.creatorName ?? '—'),
          ]),
          if (detail.remarks != null && detail.remarks!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Remarks: ',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Expanded(
                  child: Text(detail.remarks!,
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ]),
      );

  // ── Total net box ───────────────────────────────────────────────────────────

  Widget _buildTotalBox() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _accent.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(children: [
          const Text('Total Net Material Weight (All Entries)',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            '${detail.totalNet} kg',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _accent),
          ),
          Text(
            'across ${detail.entries.length} entr${detail.entries.length == 1 ? 'y' : 'ies'}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ]),
      );

  // ── Entry block ─────────────────────────────────────────────────────────────

  Widget _buildEntryBlock(
          BuildContext ctx, int index, MwmEntryModel entry) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entry header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(6)),
                  alignment: Alignment.center,
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Text('Entry #${index + 1}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _chip('Vehicle No.', entry.vehicleNumber),
                      _chip('Challan No.', entry.challanNumber),
                      _chip('Material Type', entry.materialTypeName),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _weightCard(
                        'Loaded Wt.', entry.grossWeightFormatted, false),
                    const SizedBox(width: 8),
                    _weightCard(
                        'Empty Wt.', entry.tareWeightFormatted, false),
                    const SizedBox(width: 8),
                    _weightCard(
                        'Net Material Wt.', entry.netWeightFormatted, true),
                  ]),
                  const SizedBox(height: 14),

                  const Text('Attachments',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 10),

                  _buildPhotoSection(
                    ctx,
                    label: 'Loaded Weight Slip',
                    photos: entry.grossWeightSlipPhotos,
                  ),
                  const SizedBox(height: 10),
                  _buildPhotoSection(
                    ctx,
                    label: 'Vehicle Photo (With Material)',
                    photos: entry.vehicleWithMaterialImagePhotos,
                  ),
                  const SizedBox(height: 10),
                  _buildPhotoSection(
                    ctx,
                    label: 'Empty Weight Slip',
                    photos: entry.tareWeightSlipPhotos,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Multi-photo section ─────────────────────────────────────────────────────

  Widget _buildPhotoSection(
    BuildContext ctx, {
    required String label,
    required List<MwmPhotoItem> photos,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
          ),
          const SizedBox(width: 6),
          if (photos.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${photos.length}',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _accent),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        photos.isEmpty
            ? _notCapturedBox(label)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: photos.asMap().entries.map((e) {
                    return Padding(
                      padding: EdgeInsets.only(
                          right: e.key < photos.length - 1 ? 8 : 0),
                      child: _buildPhotoChip(
                        ctx,
                        e.value,
                        index: e.key,
                        label: photos.length > 1 ? '#${e.key + 1}' : '',
                        allPhotos: photos,
                      ),
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }

  // ── Single photo chip ───────────────────────────────────────────────────────
  //
  // FIX: Images now call _openImageViewer() (in-app full-screen).
  //      PDFs still call _launchUrl() (external browser).

  Widget _buildPhotoChip(
    BuildContext ctx,
    MwmPhotoItem photo, {
    int index = 0,
    String label = '',
    required List<MwmPhotoItem> allPhotos,
  }) {
    final hasUrl = photo.url != null && photo.url!.isNotEmpty;

    return GestureDetector(
      onTap: hasUrl
          ? () {
              if (photo.isPdf) {
                // PDFs: open externally (no in-app PDF renderer dependency needed)
                _launchUrl(photo.url!);
              } else {
                // Images: open full-screen in-app viewer
                _openImageViewer(ctx, allPhotos, index);
              }
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasUrl
                    ? _accent.withValues(alpha: 0.4)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPhotoPreview(photo),
            ),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
              ),
            ),
          if (photo.geo != null) ...[
            const SizedBox(height: 3),
            _geoBadge(ctx, photo.geo!),
          ] else
            const SizedBox(height: 3),
        ],
      ),
    );
  }

  // ── Photo thumbnail preview ─────────────────────────────────────────────────

  Widget _buildPhotoPreview(MwmPhotoItem photo) {
    final hasUrl = photo.url != null && photo.url!.isNotEmpty;

    if (!hasUrl) {
      return _iconBox(
        text: photo.path.isNotEmpty ? 'Tap to open' : 'Not captured',
        icon: photo.path.isNotEmpty
            ? Icons.open_in_new_rounded
            : Icons.camera_alt_outlined,
        color: photo.path.isNotEmpty ? _accent : const Color(0xFFB0BAC9),
      );
    }

    if (photo.isPdf) {
      return _iconBox(
        text: 'PDF\nTap to open',
        icon: Icons.picture_as_pdf_outlined,
        color: const Color(0xFFEF4444),
      );
    }

    return Image.network(
      photo.url!,
      fit: BoxFit.cover,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                  : null,
              color: _accent,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _iconBox(
        text: 'Tap to open',
        icon: Icons.open_in_new_rounded,
        color: _accent,
      ),
    );
  }

  // ── Full-screen in-app image viewer ────────────────────────────────────────
  //
  // Opens a modal page with InteractiveViewer (pinch-to-zoom, pan) showing
  // all image photos in the slot.  The user can swipe left/right to browse
  // multiple photos and tap the close button (or press Back) to dismiss.

  void _openImageViewer(
    BuildContext ctx,
    List<MwmPhotoItem> photos,
    int initialIndex,
  ) {
    // Filter to only image photos (skip PDFs if they somehow end up here)
    final imagePhotos = photos.where((p) => !p.isPdf).toList();
    if (imagePhotos.isEmpty) return;

    // Map the initialIndex to the filtered list
    final photo = photos[initialIndex];
    final startIndex = imagePhotos.indexOf(photo).clamp(0, imagePhotos.length - 1);

    Navigator.of(ctx).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullScreenImageViewer(
          photos: imagePhotos,
          initialIndex: startIndex,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  // ── Utility widgets ─────────────────────────────────────────────────────────

  Widget _notCapturedBox(String label) => Container(
        height: 70,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 20, color: Color(0xFFB0BAC9)),
              SizedBox(height: 4),
              Text(
                'Not captured',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );

  Widget _iconBox(
          {required String text,
          required IconData icon,
          required Color color}) =>
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      );

  Widget _geoBadge(BuildContext ctx, MwmGeoPoint geo) {
    final mapsUrl =
        'https://www.google.com/maps?q=${geo.lat},${geo.lng}';
    return GestureDetector(
      onTap: () => _launchUrl(mapsUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF90CAF9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined,
                size: 9, color: Color(0xFF1565C0)),
            const SizedBox(width: 2),
            Text(
              '${geo.lat.toStringAsFixed(4)}, ${geo.lng.toStringAsFixed(4)}'
              '${geo.accuracy != null ? ' ±${geo.accuracy!.round()}m' : ''}',
              style: const TextStyle(
                  fontSize: 8, color: Color(0xFF1565C0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaGrid(List<_MetaItem> items) => Row(
        children: items
            .map((m) => Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(m.value,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B))),
                    ],
                  ),
                ))
            .toList(),
      );

  Widget _chip(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value.isNotEmpty ? value : '—',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B))),
        ],
      );

  Widget _weightCard(String label, String value, bool isNet) => Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isNet
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isNet
                  ? _accent.withValues(alpha: 0.4)
                  : const Color(0xFFE2E8F0),
              width: isNet ? 1.5 : 1.0,
            ),
          ),
          child: Column(children: [
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color: isNet ? _accent : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '$value kg',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color:
                      isNet ? _accent : const Color(0xFF1E293B)),
            ),
          ]),
        ),
      );

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _MetaItem {
  final String label;
  final String value;
  const _MetaItem(this.label, this.value);
}

// ═══════════════════════════════════════════════════════════════════════════════
// _FullScreenImageViewer
//
// A self-contained full-screen image viewer:
//  • PageView for swipe-left/right between multiple photos in a slot
//  • InteractiveViewer per page for pinch-to-zoom and pan
//  • Top overlay: current index indicator + close button
//  • Bottom overlay: geo badge if present
//  • Tapping the background also dismisses the viewer
// ═══════════════════════════════════════════════════════════════════════════════

class _FullScreenImageViewer extends StatefulWidget {
  final List<MwmPhotoItem> photos;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Swipeable image pages ─────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (ctx, i) =>
                _ImagePage(photo: widget.photos[i]),
          ),

          // ── Top bar: index indicator + close button ───────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      // Close / Back
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        tooltip: 'Close',
                      ),
                      const Spacer(),
                      // Page counter (only if more than one photo)
                      if (widget.photos.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.photos.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      const Spacer(),
                      // Placeholder to keep counter centred
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom bar: geo badge ─────────────────────────────────────
          if (photo.geo != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _GeoBar(geo: photo.geo!),
                  ),
                ),
              ),
            ),

          // ── Left / Right arrow hints (multi-photo only) ───────────────
          if (widget.photos.length > 1) ...[
            if (_currentIndex > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavArrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              ),
            if (_currentIndex < widget.photos.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavArrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Single zoomable image page ────────────────────────────────────────────

class _ImagePage extends StatefulWidget {
  final MwmPhotoItem photo;
  const _ImagePage({required this.photo});

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> {
  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformCtrl.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.photo.url;

    if (url == null || url.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 64),
            SizedBox(height: 12),
            Text('Image not available',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }

    return GestureDetector(
      // Double-tap to reset zoom
      onDoubleTap: _resetZoom,
      child: InteractiveViewer(
        transformationController: _transformCtrl,
        minScale: 0.5,
        maxScale: 6.0,
        clipBehavior: Clip.none,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 12),
                    const Text('Loading image…',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              );
            },
            errorBuilder: (ctx, error, stackTrace) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 64),
                const SizedBox(height: 12),
                const Text('Could not load image',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 16),
                // Offer to open externally as fallback
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded,
                      color: Colors.white70, size: 16),
                  label: const Text('Open in browser',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Geo coordinates bar ───────────────────────────────────────────────────

class _GeoBar extends StatelessWidget {
  final MwmGeoPoint geo;
  const _GeoBar({required this.geo});

  @override
  Widget build(BuildContext context) {
    final mapsUrl =
        'https://www.google.com/maps?q=${geo.lat},${geo.lng}';
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(mapsUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded,
                size: 14, color: Colors.lightBlueAccent),
            const SizedBox(width: 6),
            Text(
              '${geo.lat.toStringAsFixed(6)}, ${geo.lng.toStringAsFixed(6)}'
              '${geo.accuracy != null ? '  ±${geo.accuracy!.round()} m' : ''}',
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  letterSpacing: 0.3),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded,
                size: 11, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ─── Nav arrow button ──────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }
}