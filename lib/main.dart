import 'package:flutter/material.dart';
import 'controllers/movie_controller.dart';
import 'views/movie_downloader_view.dart';

void main() {
  runApp(const MovieDownloaderApp());
}

class MovieDownloaderApp extends StatelessWidget {
  final MovieController? controller;
  final bool autoFetch;

  const MovieDownloaderApp({super.key, this.controller, this.autoFetch = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigoAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: MovieDownloaderView(controller: controller, autoFetch: autoFetch),
    );
  }
}
