class Movie {
  final String title;
  final String slug;

  const Movie({
    required this.title,
    required this.slug,
  });

  /// Returns the complete URL to the movie page on the website.
  String get fullUrl {
    if (slug.startsWith('http://') || slug.startsWith('https://')) {
      return slug;
    }
    if (slug.startsWith('/')) {
      return 'https://moviesdatamil.co$slug';
    }
    return 'https://moviesdatamil.co/$slug';
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      title: (json['title'] as String? ?? '').trim(),
      slug: (json['slug'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'slug': slug,
    };
  }

  Movie copyWith({
    String? title,
    String? slug,
  }) {
    return Movie(
      title: title ?? this.title,
      slug: slug ?? this.slug,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Movie &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          slug == other.slug;

  @override
  int get hashCode => title.hashCode ^ slug.hashCode;
}

class MovieCatalogueResponse {
  final bool success;
  final String? year;
  final int page;
  final int totalPages;
  final int total;
  final List<Movie> movies;
  final String? message;
  final String? error;

  const MovieCatalogueResponse({
    required this.success,
    this.year,
    this.page = 1,
    this.totalPages = 0,
    this.total = 0,
    this.movies = const [],
    this.message,
    this.error,
  });

  factory MovieCatalogueResponse.fromJson(Map<String, dynamic> json) {
    final rawMovies = json['movies'];
    final List<Movie> parsedMovies = [];

    if (rawMovies is List) {
      for (final item in rawMovies) {
        if (item is Map<String, dynamic>) {
          parsedMovies.add(Movie.fromJson(item));
        } else if (item is Map) {
          parsedMovies.add(
            Movie.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return MovieCatalogueResponse(
      success: json['success'] as bool? ?? false,
      year: json['year'] as String?,
      page: json['page'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? (parsedMovies.isNotEmpty ? 1 : 0),
      total: json['total'] as int? ?? parsedMovies.length,
      movies: parsedMovies,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'year': year,
      'page': page,
      'totalPages': totalPages,
      'total': total,
      'movies': movies.map((m) => m.toJson()).toList(),
      'message': message,
      'error': error,
    };
  }
}

class DownloadLinkItem {
  final String title;
  final String downloadUrl;
  final String filename;
  final String quality;
  final String format;
  final bool isFastbytes;
  final String? sourcePage;

  const DownloadLinkItem({
    required this.title,
    required this.downloadUrl,
    required this.filename,
    this.quality = '',
    this.format = 'MP4',
    this.isFastbytes = false,
    this.sourcePage,
  });

  factory DownloadLinkItem.fromJson(Map<String, dynamic> json) {
    return DownloadLinkItem(
      title: json['title'] as String? ?? 'Download Link',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      filename: json['filename'] as String? ?? (json['title'] as String? ?? 'Download Link'),
      quality: json['quality'] as String? ?? '',
      format: json['format'] as String? ?? 'MP4',
      isFastbytes: json['isFastbytes'] as bool? ?? false,
      sourcePage: json['sourcePage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'downloadUrl': downloadUrl,
      'filename': filename,
      'quality': quality,
      'format': format,
      'isFastbytes': isFastbytes,
      'sourcePage': sourcePage,
    };
  }
}

class MovieDownloadLinksResponse {
  final bool success;
  final String slug;
  final int total;
  final List<DownloadLinkItem> downloads;
  final String? message;
  final String? error;

  const MovieDownloadLinksResponse({
    required this.success,
    this.slug = '',
    this.total = 0,
    this.downloads = const [],
    this.message,
    this.error,
  });

  factory MovieDownloadLinksResponse.fromJson(Map<String, dynamic> json) {
    final rawDownloads = json['downloads'];
    final List<DownloadLinkItem> items = [];

    if (rawDownloads is List) {
      for (final item in rawDownloads) {
        if (item is Map<String, dynamic>) {
          items.add(DownloadLinkItem.fromJson(item));
        } else if (item is Map) {
          items.add(
            DownloadLinkItem.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return MovieDownloadLinksResponse(
      success: json['success'] as bool? ?? false,
      slug: json['slug'] as String? ?? '',
      total: json['total'] as int? ?? items.length,
      downloads: items,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }
}



