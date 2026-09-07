import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/movie_controller.dart';
import '../models/movie_model.dart';
import 'movie_downloads_view.dart';

class MovieDownloaderView extends StatefulWidget {
  final MovieController? controller;
  final bool autoFetch;

  const MovieDownloaderView({
    super.key,
    this.controller,
    this.autoFetch = true,
  });

  @override
  State<MovieDownloaderView> createState() => _MovieDownloaderViewState();
}

class _MovieDownloaderViewState extends State<MovieDownloaderView> {
  late final MovieController _controller;
  late final bool _ownsController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? MovieController();
    // Automatically fetch catalogue on load if requested
    if (widget.autoFetch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.fetchMoviesForYear(_controller.selectedYear, page: 1);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onPageSelected(int page) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _controller.goToPage(page);
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
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
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

  void _showMovieDetails(Movie movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.movie_rounded,
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
                            movie.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tamil ${_controller.selectedYear} Release',
                            style: const TextStyle(
                              color: Colors.indigoAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Slug container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full URL Path',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        movie.fullUrl,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF475569)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy URL'),
                        onPressed: () {
                          Navigator.pop(context);
                          _copyToClipboard(movie.fullUrl, 'Full URL');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('View Details'),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MovieDownloadsView(movie: movie),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigoAccent.withAlpha(38),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.movie_filter_rounded,
                color: Colors.indigoAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Movie Downloader',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tamil Catalogue (${_controller.selectedYear})',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.totalCount > 0) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigoAccent.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.indigoAccent.withAlpha(90),
                      ),
                    ),
                    child: Text(
                      _controller.hasSearchQuery
                          ? '${_controller.filteredCount} found in ${_controller.selectedYear}'
                          : (_controller.totalPages > 1
                              ? 'Page ${_controller.currentPage}/${_controller.totalPages} (${_controller.filteredCount} items)'
                              : '${_controller.filteredCount} Movies'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigoAccent,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            tooltip: 'Refresh Catalogue',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => _controller.fetchMoviesForYear(
              _controller.selectedYear,
              page: _controller.currentPage,
              isRefresh: true,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              children: [
                // --- Year Input & Quick Chips ---
                _buildYearHeaderCard(),

                // --- Title Filter Input Box ---
                _buildTitleSearchBar(),

                // --- Main Content Area ---
                Expanded(child: _buildBody()),

                // --- Bottom Pagination Bar (hidden during active search) ---
                if (_controller.totalPages > 1 && !_controller.hasSearchQuery)
                  _buildPaginationBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildYearHeaderCard() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Year Input Row
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _controller.yearController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _controller.searchCurrentYear(),
                        decoration: InputDecoration(
                          hintText: 'Enter Year (e.g. 2026, 2025)...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.calendar_month_rounded,
                            color: Colors.indigoAccent,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Colors.indigoAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _controller.isLoading
                          ? null
                          : () => _controller.searchCurrentYear(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: const Icon(Icons.travel_explore_rounded, size: 18),
                      label: const Text(
                        'Fetch',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Quick Year Chips
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: MovieController.quickYears.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final year = MovieController.quickYears[index];
                    final isSelected = _controller.selectedYear == year;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _controller.isLoading
                          ? null
                          : () => _controller.fetchMoviesForYear(year),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.indigoAccent
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.indigoAccent
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            year,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSearchBar() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: TextField(
            controller: _controller.searchController,
            onChanged: (text) => _controller.filterMovies(text),
            textInputAction: TextInputAction.search,
            onSubmitted: (text) => _controller.filterMovies(text),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Filter ${_controller.selectedYear} movies by title...',
              hintStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
              suffixIcon: _controller.hasSearchQuery
                  ? IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                      onPressed: () => _controller.clearSearch(),
                    )
                  : (_controller.isBackgroundLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.indigoAccent,
                              ),
                            ),
                          ),
                        )
                      : null),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Colors.indigoAccent,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return _buildLoadingView();
    }

    if (_controller.errorMessage != null) {
      return _buildErrorView();
    }

    if (_controller.movies.isEmpty) {
      return _buildEmptyView();
    }

    return _buildMovieListView();
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _controller.hasSearchQuery
                  ? 'Searching "${_controller.currentQuery}"...'
                  : 'Fetching Tamil ${_controller.selectedYear} Movies...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _controller.hasSearchQuery
                  ? 'Scanning through movie pages using backend search...'
                  : 'Loading Page ${_controller.currentPage} of ${_controller.totalPages > 0 ? _controller.totalPages : 1}...',
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

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7F1D1D)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFF87171),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to Load ${_controller.selectedYear} Catalogue',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _controller.errorMessage ?? 'An unexpected error occurred.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _controller.fetchMoviesForYear(
                    _controller.selectedYear,
                    page: _controller.currentPage,
                    isRefresh: true,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final isSearching = _controller.hasSearchQuery;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.movie_creation_outlined,
              size: 54,
              color: const Color(0xFF64748B),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'No movies found for "${_controller.currentQuery}"'
                  : 'No movies available for year ${_controller.selectedYear}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try searching with a different movie title or keyword.'
                  : 'Try selecting another year from the chips above.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
            if (isSearching) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _controller.clearSearch();
                  _controller.fetchMoviesForYear(
                    _controller.selectedYear,
                    page: 1,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigoAccent,
                  side: const BorderSide(color: Colors.indigoAccent),
                ),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMovieListView() {
    final movies = _controller.movies;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: RefreshIndicator(
          color: Colors.indigoAccent,
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () => _controller.fetchMoviesForYear(
            _controller.selectedYear,
            page: _controller.currentPage,
            isRefresh: true,
          ),
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: movies.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final movie = movies[index];
              final itemNumber = _controller.hasSearchQuery
                  ? index + 1
                  : (_controller.currentPage - 1) * 20 + index + 1;
              return _buildMovieCard(movie, itemNumber);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar() {
    final total = _controller.totalPages;
    final current = _controller.currentPage;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF334155).withAlpha(150),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Row(
            children: [
              // Prev Button
              InkWell(
                onTap: current > 1 && !_controller.isLoading
                    ? () => _onPageSelected(current - 1)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: current > 1
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF0F172A).withAlpha(80),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: current > 1
                          ? const Color(0xFF334155)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: current > 1 ? Colors.white : Colors.white24,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Prev',
                        style: TextStyle(
                          color: current > 1 ? Colors.white : Colors.white24,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Scrollable Page Numbers
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: total,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final pageNum = idx + 1;
                      final isSelected = pageNum == current;
                      return InkWell(
                        onTap: isSelected || _controller.isLoading
                            ? null
                            : () => _onPageSelected(pageNum),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.indigoAccent
                                : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.indigoAccent
                                  : const Color(0xFF334155),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.indigoAccent.withAlpha(90),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$pageNum',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFCBD5E1),
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Next Button
              InkWell(
                onTap: current < total && !_controller.isLoading
                    ? () => _onPageSelected(current + 1)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: current < total
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF0F172A).withAlpha(80),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: current < total
                          ? const Color(0xFF334155)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          color: current < total ? Colors.white : Colors.white24,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: current < total ? Colors.white : Colors.white24,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieCard(Movie movie, int index) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showMovieDetails(movie),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                // Index Badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.indigoAccent.withAlpha(60),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.indigoAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title and Slug Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              child: Text(
                                movie.slug,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Quick Actions
                IconButton(
                  tooltip: 'Copy Link',
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  onPressed: () => _copyToClipboard(movie.fullUrl, 'Movie URL'),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


