import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/movie_model.dart';

class MovieController extends ChangeNotifier {
  final TextEditingController yearController = TextEditingController(text: '2026');
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
  int _totalPages = 0;
  int _totalCount = 0;
  List<Movie> _allMovies = [];
  List<Movie> _filteredMovies = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentQuery = '';

  String get selectedYear => _selectedYear;
  int get totalPages => _totalPages;
  int get totalCount => _totalCount;
  int get filteredCount => _filteredMovies.length;
  List<Movie> get movies => _filteredMovies;
  List<Movie> get allMovies => _allMovies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSearchQuery => _currentQuery.trim().isNotEmpty;
  String get currentQuery => _currentQuery;

  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    return 'http://localhost:3000';
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

  /// Fetches movies for the specified 4-digit release year
  Future<void> fetchMoviesForYear(String year, {bool isRefresh = false}) async {
    final cleanYear = year.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleanYear)) {
      _errorMessage = 'Please enter a valid 4-digit year (e.g. 2026).';
      notifyListeners();
      return;
    }

    _selectedYear = cleanYear;
    if (yearController.text != cleanYear) {
      yearController.text = cleanYear;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await dio.get('/api/movies/year/$cleanYear');
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
        _totalCount = catalogueResponse.total > 0
            ? catalogueResponse.total
            : _allMovies.length;
        _applyFilter(_currentQuery);
      } else {
        _allMovies = [];
        _filteredMovies = [];
        _totalPages = 0;
        _totalCount = 0;
        _errorMessage =
            catalogueResponse.message ?? 'Failed to load movie catalogue for $cleanYear';
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
            'Request timed out. The server is scraping multiple pages for year $cleanYear, please try again.';
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

  /// Convenience wrapper to search using the text in the year input box
  Future<void> searchCurrentYear() {
    return fetchMoviesForYear(yearController.text);
  }

  /// Backwards compatibility helper
  Future<void> fetchTamil2022Movies({bool isRefresh = false}) {
    return fetchMoviesForYear('2022', isRefresh: isRefresh);
  }

  /// Filters movies locally based on the search query
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
      _filteredMovies = _allMovies
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
    yearController.dispose();
    searchController.dispose();
    super.dispose();
  }
}



