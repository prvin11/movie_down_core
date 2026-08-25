import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/movie_controller.dart';
import '../models/movie_model.dart';

class MovieDownloadsView extends StatefulWidget {
  final Movie movie;
  final MovieController? controller;
  final bool autoFetch;

  const MovieDownloadsView({
    super.key,
    required this.movie,
    this.controller,
    this.autoFetch = true,
  });

  @override
  State<MovieDownloadsView> createState() => _MovieDownloadsViewState();
}

class _MovieDownloadsViewState extends State<MovieDownloadsView> {
  late final MovieController _controller;
  late final bool _ownsController;

  bool _isLoading = true;
  String? _errorMessage;
  List<DownloadLinkItem> _downloads = [];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? MovieController();
    if (widget.autoFetch) {
      _loadDownloadLinks();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDownloadLinks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final links = await _controller.fetchDownloadLinks(widget.movie);
      if (mounted) {
        setState(() {
          _downloads = links;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not resolve download links: ${e.toString().replaceAll("Exception:", "").trim()}';
          _isLoading = false;
        });
      }
    }
  }

  /// Directly redirects the user to Chrome or default browser to download the file
  Future<void> _openInBrowserToDownload(String url, String filename) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        // Fallback to copy if launch failed
        _copyToClipboard(url, 'Download Link');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.greenAccent, width: 1),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.open_in_browser_rounded,
                  color: Colors.greenAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Redirected to Chrome / Browser to download "$filename"...',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _copyToClipboard(url, 'Download Link');
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.indigoAccent, width: 1),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label copied to clipboard',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAllLinks() {
    if (_downloads.isEmpty) return;
    final allUrls = _downloads.map((d) => d.downloadUrl).join('\n');
    _copyToClipboard(allUrls, '${_downloads.length} Download Links');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.movie.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_downloads.isNotEmpty)
            IconButton(
              tooltip: 'Copy All Links',
              icon: const Icon(Icons.copy_all_rounded, color: Colors.white70),
              onPressed: _copyAllLinks,
            ),
          IconButton(
            tooltip: 'Reload Links',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _isLoading ? null : _loadDownloadLinks,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: CustomScrollView(
              slivers: [
                // Top Info Hero Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _buildHeaderCard(),
                  ),
                ),

                // Download Links Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: _buildLinksSliver(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigoAccent.withAlpha(35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.movie_creation_outlined,
                  color: Colors.indigoAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movie.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.movie.slug,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.file_download_done_rounded,
                      color: Colors.greenAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isLoading
                          ? 'Resolving Direct Links...'
                          : '${_downloads.length} Download Links Ready',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.indigoAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                label: const Text(
                  'Open Page in Chrome',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () => _openInBrowserToDownload(
                  widget.movie.fullUrl,
                  widget.movie.title,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinksSliver() {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Resolving Direct Download Links...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Extracting direct FastBytes and CDN download links for "${widget.movie.title}"...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.blueGrey.shade300,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF7F1D1D)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFF87171),
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'Failed to Resolve Links',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDownloadLinks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Resolution'),
              ),
            ],
          ),
        ),
      );
    }

    if (_downloads.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              const Icon(
                Icons.link_off_rounded,
                size: 48,
                color: Color(0xFF64748B),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Direct Download Links Found',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The download servers for this release could not be resolved automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = _downloads[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildDownloadLinkCard(item, index + 1),
          );
        },
        childCount: _downloads.length,
      ),
    );
  }

  Widget _buildDownloadLinkCard(DownloadLinkItem item, int index) {
    final isFastbytes = item.isFastbytes || item.downloadUrl.contains('fastbytes') || item.downloadUrl.contains('uptomkv');

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openInBrowserToDownload(item.downloadUrl, item.filename),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFastbytes
                ? Colors.indigoAccent.withAlpha(120)
                : const Color(0xFF334155),
            width: isFastbytes ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Quality / Server Badges
            Row(
              children: [
                if (item.quality.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigoAccent.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.indigoAccent.withAlpha(80),
                      ),
                    ),
                    child: Text(
                      item.quality,
                      style: const TextStyle(
                        color: Colors.indigoAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isFastbytes
                        ? Colors.amberAccent.withAlpha(30)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isFastbytes
                          ? Colors.amberAccent.withAlpha(80)
                          : const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFastbytes
                            ? Icons.bolt_rounded
                            : Icons.download_done_rounded,
                        size: 13,
                        color: isFastbytes
                            ? Colors.amberAccent
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFastbytes ? 'FASTBYTES CDN' : 'DIRECT CDN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isFastbytes
                              ? Colors.amberAccent
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '#$index',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // File Title / Filename
            Text(
              item.filename,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 10),

            // URL preview box with copy icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.downloadUrl,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy Link',
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: Colors.indigoAccent,
                    ),
                    onPressed: () => _copyToClipboard(
                      item.downloadUrl,
                      'Download Link',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Big Primary Redirect Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(
                  Icons.open_in_browser_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                label: const Text(
                  'Download in Chrome / Browser',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _openInBrowserToDownload(
                  item.downloadUrl,
                  item.filename,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
