import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class MovieVideoPlayerView extends StatefulWidget {
  final String title;
  final String streamUrl;
  final String? quality;
  final String? filename;

  const MovieVideoPlayerView({
    super.key,
    required this.title,
    required this.streamUrl,
    this.quality,
    this.filename,
  });

  @override
  State<MovieVideoPlayerView> createState() => _MovieVideoPlayerViewState();
}

class _MovieVideoPlayerViewState extends State<MovieVideoPlayerView> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isInitializing = true;
      _initError = null;
    });

    try {
      final uri = Uri.parse(widget.streamUrl);
      _videoPlayerController = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://play.onestream.today/',
        },
      );


      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio > 0
            ? _videoPlayerController!.value.aspectRatio
            : 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.indigoAccent,
          handleColor: Colors.amberAccent,
          backgroundColor: const Color(0xFF334155),
          bufferedColor: const Color(0xFF64748B),
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFF87171),
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Playback Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry'),
                        onPressed: _initializePlayer,
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                        label: const Text('Open in Browser'),
                        onPressed: _openInBrowser,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.streamUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _copyToClipboard(widget.streamUrl, 'Stream URL');
      }
    } catch (_) {
      if (mounted) {
        _copyToClipboard(widget.streamUrl, 'Stream URL');
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

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
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
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Open in Browser',
            icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white70),
            onPressed: _openInBrowser,
          ),
          IconButton(
            tooltip: 'Copy Stream URL',
            icon: const Icon(Icons.copy_rounded, color: Colors.white70),
            onPressed: () => _copyToClipboard(widget.streamUrl, 'Stream URL'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video Player Container
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: _buildPlayerContent(),
                ),
              ),

              // Details & Stream Controls
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.filename ?? widget.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (widget.quality != null &&
                                      widget.quality!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.indigoAccent.withAlpha(40),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.indigoAccent
                                              .withAlpha(80),
                                        ),
                                      ),
                                      child: Text(
                                        widget.quality!,
                                        style: const TextStyle(
                                          color: Colors.indigoAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purpleAccent.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.purpleAccent.withAlpha(80),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_circle_outline_rounded,
                                          size: 13,
                                          color: Colors.purpleAccent,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'ONLINE STREAM',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purpleAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // URL Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stream Source URL',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    widget.streamUrl,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy Stream URL',
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 16,
                                    color: Colors.indigoAccent,
                                  ),
                                  onPressed: () => _copyToClipboard(
                                    widget.streamUrl,
                                    'Stream URL',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigoAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.open_in_browser_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Open in Browser',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _openInBrowser,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                color: Color(0xFF334155),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.download_rounded,
                              size: 18,
                              color: Colors.amberAccent,
                            ),
                            label: const Text(
                              'Download Video',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _openInBrowser,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Buffering Video Stream...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: Color(0xFFF87171),
                size: 40,
              ),
              const SizedBox(height: 10),
              const Text(
                'Could not load in-app stream',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    onPressed: _initializePlayer,
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                    label: const Text('Open in Browser'),
                    onPressed: _openInBrowser,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return const SizedBox.shrink();
  }
}
