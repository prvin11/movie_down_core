import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/movie_model.dart';

class YearFetchParams {
  final SendPort sendPort;
  final String baseUrl;
  final String year;
  final int startPage;
  final int totalPages;

  const YearFetchParams({
    required this.sendPort,
    required this.baseUrl,
    required this.year,
    required this.startPage,
    required this.totalPages,
  });
}

/// Top-level function executed in a background Isolate to fetch all pages for a year
Future<void> _fetchYearMoviesInIsolate(YearFetchParams params) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  final allMovies = <Map<String, dynamic>>[];

  try {
    for (int p = params.startPage; p <= params.totalPages; p++) {
      try {
        final uri = Uri.parse('${params.baseUrl}/api/movies/year/${params.year}?page=$p');
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, 'Flutter-Movie-Downloader');
        final response = await request.close();

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final data = jsonDecode(responseBody);
          if (data is Map && data['success'] == true && data['movies'] is List) {
            final pageMovies = List<Map<String, dynamic>>.from(
              (data['movies'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
            );
            allMovies.addAll(pageMovies);
            params.sendPort.send({
              'type': 'page',
              'year': params.year,
              'page': p,
              'movies': pageMovies,
            });
          }
        }
      } catch (_) {
        // Silently proceed to next page if one has transient network issues
      }
    }

    params.sendPort.send({
      'type': 'done',
      'year': params.year,
      'movies': allMovies,
    });
  } catch (e) {
    params.sendPort.send({
      'type': 'error',
      'year': params.year,
      'error': e.toString(),
    });
  } finally {
    client.close();
  }
}

class MovieController extends ChangeNotifier {
  final TextEditingController yearController = TextEditingController(
    text: '2026',
  );
  final TextEditingController searchController = TextEditingController();

  static const List<String> quickYears = [
    '2026',
    '2025',
    '2024',
    '2023',
    '2022',
    '2021',
    '2020',
  ];

  String _selectedYear = '2026';
  int _currentPage = 1;
  int _totalPages = 0;
  int _totalCount = 0;
  List<Movie> _allMovies = [];
  List<Movie> _filteredMovies = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentQuery = '';

  // Background Isolate state & full year movie cache
  final Map<String, List<Movie>> _yearMoviesCache = {};
  final Set<String> _fullyLoadedYears = {};
  bool _isBackgroundLoading = false;
  Isolate? _activeIsolate;
  ReceivePort? _activeReceivePort;

  String get selectedYear => _selectedYear;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalCount => _totalCount;
  int get filteredCount => _filteredMovies.length;
  List<Movie> get movies => _filteredMovies;
  List<Movie> get allMovies => _allMovies;
  bool get isLoading => _isLoading;
  bool get isBackgroundLoading => _isBackgroundLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSearchQuery => _currentQuery.trim().isNotEmpty;
  String get currentQuery => _currentQuery;
  int get cachedYearMoviesCount => _yearMoviesCache[_selectedYear]?.length ?? _allMovies.length;

  static String get defaultBaseUrl {
    return "https://movie-down-core.112praveenb112.workers.dev";
  }

  late final Dio dio;

  MovieController({String? customBaseUrl}) {
    final baseUrl = customBaseUrl ?? defaultBaseUrl;
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
  }

  /// Fetches movies for the specified 4-digit release year and page number
  Future<void> fetchMoviesForYear(
    String year, {
    int page = 1,
    bool isRefresh = false,
  }) async {
    final cleanYear = year.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleanYear)) {
      _errorMessage = 'Please enter a valid 4-digit year (e.g. 2026).';
      notifyListeners();
      return;
    }

    final yearChanged = _selectedYear != cleanYear;
    _selectedYear = cleanYear;
    _currentPage = page;
    if (yearController.text != cleanYear) {
      yearController.text = cleanYear;
    }

    // Cancel any active isolate if the year has changed
    if (yearChanged) {
      _cancelActiveIsolate();
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{'page': page};
      if (isRefresh) {
        queryParams['refresh'] = 'true';
      }

      final response = await dio.get(
        '/api/movies/year/$cleanYear',
        queryParameters: queryParams,
      );
      final data = response.data;

      MovieCatalogueResponse catalogueResponse;
      if (data is Map<String, dynamic>) {
        catalogueResponse = MovieCatalogueResponse.fromJson(data);
      } else if (data is Map) {
        catalogueResponse = MovieCatalogueResponse.fromJson(
          Map<String, dynamic>.from(data),
        );
      } else {
        throw Exception('Unexpected server response format');
      }

      if (catalogueResponse.success) {
        _allMovies = catalogueResponse.movies;
        _totalPages = catalogueResponse.totalPages;
        _currentPage = catalogueResponse.page;
        _totalCount = catalogueResponse.total > 0
            ? catalogueResponse.total
            : _allMovies.length;

        if (isRefresh) {
          _yearMoviesCache.remove(cleanYear);
          _fullyLoadedYears.remove(cleanYear);
        }

        // Initialize cache with page movies
        _yearMoviesCache.putIfAbsent(cleanYear, () => []);
        final cachedList = _yearMoviesCache[cleanYear]!;
        for (final m in _allMovies) {
          if (!cachedList.any((e) => e.slug == m.slug)) {
            cachedList.add(m);
          }
        }

        _applyFilter(_currentQuery);

        // Spawn isolate to fetch all remaining pages in background
        if (_totalPages > 1 && !_fullyLoadedYears.contains(cleanYear)) {
          _startBackgroundYearFetch(cleanYear, _totalPages);
        }
      } else {
        _allMovies = [];
        _filteredMovies = [];
        _totalPages = 0;
        _totalCount = 0;
        _errorMessage =
            catalogueResponse.message ??
            'Failed to load movie catalogue for $cleanYear';
      }
    } on DioException catch (e) {
      debugPrint('DIO ERROR: ${e.message}');
      debugPrint('STATUS CODE: ${e.response?.statusCode}');
      debugPrint('RESPONSE: ${e.response?.data}');

      _allMovies = [];
      _filteredMovies = [];
      _totalPages = 0;
      _totalCount = 0;

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _errorMessage =
            'Request timed out fetching page $page for year $cleanYear, please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        _errorMessage =
            'Could not connect to server at ${dio.options.baseUrl}. Ensure backend server is running on port 3000.';
      } else {
        _errorMessage =
            e.response?.data?['message']?.toString() ??
            e.message ??
            'Error fetching catalogue for $cleanYear.';
      }
    } catch (e) {
      debugPrint('ERROR: $e');
      _allMovies = [];
      _filteredMovies = [];
      _totalPages = 0;
      _totalCount = 0;
      _errorMessage = 'Something went wrong: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Spawns a background isolate to fetch all pages of the selected year
  void _startBackgroundYearFetch(String year, int totalPages) async {
    _cancelActiveIsolate();

    if (_fullyLoadedYears.contains(year)) return;

    _isBackgroundLoading = true;
    notifyListeners();

    final receivePort = ReceivePort();
    _activeReceivePort = receivePort;

    try {
      final isolate = await Isolate.spawn(
        _fetchYearMoviesInIsolate,
        YearFetchParams(
          sendPort: receivePort.sendPort,
          baseUrl: dio.options.baseUrl,
          year: year,
          startPage: 1,
          totalPages: totalPages,
        ),
      );
      _activeIsolate = isolate;

      receivePort.listen(
        (msg) {
          if (msg is Map) {
            final msgYear = msg['year'] as String?;
            if (msgYear != _selectedYear) return;

            if (msg['type'] == 'page' && msg['movies'] is List) {
              final raw = msg['movies'] as List;
              _yearMoviesCache.putIfAbsent(year, () => []);
              final cachedList = _yearMoviesCache[year]!;

              for (final item in raw) {
                if (item is Map<String, dynamic>) {
                  final movie = Movie.fromJson(item);
                  if (!cachedList.any((m) => m.slug == movie.slug)) {
                    cachedList.add(movie);
                  }
                }
              }

              if (_currentQuery.isNotEmpty) {
                _applyFilter(_currentQuery);
              }
              notifyListeners();
            } else if (msg['type'] == 'done') {
              _fullyLoadedYears.add(year);
              _isBackgroundLoading = false;
              if (_currentQuery.isNotEmpty) {
                _applyFilter(_currentQuery);
              }
              notifyListeners();
              _cancelActiveIsolate();
            } else if (msg['type'] == 'error') {
              _isBackgroundLoading = false;
              notifyListeners();
              _cancelActiveIsolate();
            }
          }
        },
        onError: (err) {
          debugPrint('Isolate error: $err');
          _isBackgroundLoading = false;
          notifyListeners();
          _cancelActiveIsolate();
        },
        onDone: () {
          _isBackgroundLoading = false;
        },
      );
    } catch (e) {
      debugPrint('Failed to spawn background isolate: $e');
      _isBackgroundLoading = false;
      notifyListeners();
    }
  }

  void _cancelActiveIsolate() {
    _activeIsolate?.kill(priority: Isolate.immediate);
    _activeIsolate = null;
    _activeReceivePort?.close();
    _activeReceivePort = null;
    _isBackgroundLoading = false;
  }

  /// Navigates to a specific page number
  Future<void> goToPage(int page) async {
    if (page < 1 || (_totalPages > 0 && page > _totalPages)) return;
    if (page == _currentPage && !_isLoading) return;
    await fetchMoviesForYear(_selectedYear, page: page);
  }

  /// Navigates to the next page if available
  Future<void> nextPage() {
    if (_currentPage < _totalPages) {
      return goToPage(_currentPage + 1);
    }
    return Future.value();
  }

  /// Navigates to the previous page if available
  Future<void> previousPage() {
    if (_currentPage > 1) {
      return goToPage(_currentPage - 1);
    }
    return Future.value();
  }

  /// Convenience wrapper to search using the text in the year input box
  Future<void> searchCurrentYear() {
    return fetchMoviesForYear(yearController.text, page: 1);
  }

  /// Backwards compatibility helper
  Future<void> fetchTamil2022Movies({bool isRefresh = false}) {
    return fetchMoviesForYear('2022', page: 1, isRefresh: isRefresh);
  }

  /// Filters movies across the entire year based on the search query
  void filterMovies(String query) {
    _currentQuery = query;
    _applyFilter(query);
    notifyListeners();
  }

  void _applyFilter(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      _filteredMovies = List.from(_allMovies);
    } else {
      // Search across the full cached year catalogue collected by the isolate
      final pool = _yearMoviesCache[_selectedYear] ?? _allMovies;
      _filteredMovies = pool
          .where((movie) => movie.title.toLowerCase().contains(cleanQuery))
          .toList();
    }
  }

  void clearSearch() {
    searchController.clear();
    _currentQuery = '';
    _applyFilter('');
    notifyListeners();
  }

  /// Deeply resolves all direct Fastbytes / mp4 download links for a specific movie
  Future<List<DownloadLinkItem>> fetchDownloadLinks(Movie movie) async {
    try {
      final response = await dio.get(
        '/api/movies/download-links',
        queryParameters: {'slug': movie.slug},
      );
      final data = response.data;
      MovieDownloadLinksResponse downloadResponse;
      if (data is Map<String, dynamic>) {
        downloadResponse = MovieDownloadLinksResponse.fromJson(data);
      } else if (data is Map) {
        downloadResponse = MovieDownloadLinksResponse.fromJson(
          Map<String, dynamic>.from(data),
        );
      } else {
        throw Exception('Unexpected server response format');
      }

      return downloadResponse.downloads;
    } catch (e) {
      debugPrint('Error fetching download links: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _cancelActiveIsolate();
    yearController.dispose();
    searchController.dispose();
    super.dispose();
  }
}
