import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_down_core/controllers/movie_controller.dart';
import 'package:movie_down_core/main.dart';
import 'package:movie_down_core/models/movie_model.dart';
import 'package:movie_down_core/views/movie_downloads_view.dart';


void main() {
  test('Movie model serialization and URL resolution', () {
    final movie = Movie.fromJson({
      'title': 'Vikram (2022)',
      'slug': '/tamil-2022-movies/vikram-movie-download/',
    });

    expect(movie.title, 'Vikram (2022)');
    expect(movie.slug, '/tamil-2022-movies/vikram-movie-download/');
    expect(
      movie.fullUrl,
      'https://moviesdatamil.co/tamil-2022-movies/vikram-movie-download/',
    );
  });

  test('MovieCatalogueResponse with dynamic totalPages', () {
    final response = MovieCatalogueResponse.fromJson({
      'success': true,
      'year': '2026',
      'totalPages': 17,
      'total': 336,
      'movies': [
        {
          'title': 'I Nobody (2026)',
          'slug': '/i-nobody-2026-tamil-movie/',
        }
      ]
    });

    expect(response.success, isTrue);
    expect(response.year, '2026');
    expect(response.totalPages, 17);
    expect(response.total, 336);
    expect(response.movies.length, 1);
    expect(response.movies.first.title, 'I Nobody (2026)');
  });

  testWidgets('Movie Catalogue initial UI smoke test', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame with autoFetch disabled to avoid background timers in test.
    await tester.pumpWidget(const MovieDownloaderApp(autoFetch: false));

    // Verify App Bar Title exists
    expect(find.text('Movie Downloader'), findsOneWidget);

    // Verify Year text field and quick chips exist
    expect(find.text('2026'), findsWidgets);
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('Fetch'), findsOneWidget);

    // Verify Title Search TextField exists
    expect(find.text('Filter 2026 movies by title...'), findsOneWidget);
  });

  test('MovieController search filter and quick years test', () {
    final controller = MovieController();
    expect(controller.movies.isEmpty, isTrue);
    expect(controller.totalCount, 0);
    expect(controller.selectedYear, '2026');
    expect(MovieController.quickYears.contains('2026'), isTrue);

    // Test search filter without network
    controller.filterMovies('Vikram');
    expect(controller.currentQuery, 'Vikram');
    expect(controller.hasSearchQuery, isTrue);

    controller.clearSearch();
    expect(controller.currentQuery, '');
    expect(controller.hasSearchQuery, isFalse);
  });

  test('DownloadLinkItem and MovieDownloadLinksResponse JSON parsing', () {
    final response = MovieDownloadLinksResponse.fromJson({
      'success': true,
      'slug': '/sattam-oru-iruttarai-2012-tamil-movie/',
      'total': 1,
      'downloads': [
        {
          'title': 'Download Server 1',
          'downloadUrl':
              'https://download.fastbytes.xyz/download.php?dl=c2VydmVyPWNkbjImaGFzaD02NGMzNzJkZTEwZjFhZWY5YWNiNzkzNThmZTc5NTc2YSZleHA9MTc4NzY0MTA0NyZwYXRoPVRhbWlsIDIwMTIgTW92aWVzL1NhdHRhbSBPcnUgSXJ1dHRhcmFpICgyMDEyKS9NcDQgSFEgIChTaW5nbGUgUGFydCkgLSAoMzIweDI0MCkvU2F0dGFtIE9ydSBJcnV0dGFyYWkgKDIwMTIpIFNpbmdsZSBQYXJ0ICgzMjB4MjQwKS5tcDQmc3RyZWFtPTA=',
          'filename': 'Sattam Oru Iruttarai (2012) Single Part (320x240).mp4',
          'quality': 'Mp4 HQ  (Single Part) - (320x240)',
          'isFastbytes': true,
          'format': 'MP4'
        }
      ]
    });

    expect(response.success, isTrue);
    expect(response.downloads.length, 1);
    final link = response.downloads.first;
    expect(link.isFastbytes, isTrue);
    expect(link.filename, 'Sattam Oru Iruttarai (2012) Single Part (320x240).mp4');
    expect(link.quality, 'Mp4 HQ  (Single Part) - (320x240)');
    expect(link.downloadUrl.contains('fastbytes.xyz'), isTrue);
  });

  testWidgets('MovieDownloadsView smoke test', (WidgetTester tester) async {
    const movie = Movie(
      title: 'Sattam Oru Iruttarai (2012)',
      slug: '/sattam-oru-iruttarai-2012-tamil-movie/',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MovieDownloadsView(
          movie: movie,
          autoFetch: false,
        ),
      ),
    );

    expect(find.text('Sattam Oru Iruttarai (2012)'), findsWidgets);
    expect(find.text('Open Page in Chrome'), findsOneWidget);
  });
}







