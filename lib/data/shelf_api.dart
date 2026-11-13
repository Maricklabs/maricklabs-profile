import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book.dart';
import '../models/movie.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenLibraryApi {
  OpenLibraryApi(this.client);

  final http.Client client;

  Future<List<Book>> search(String query) async {
    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': query,
      'fields': 'key,title,author_name,first_publish_year,cover_i',
      'limit': '20',
    });
    final json = await _getJson(client, uri, 'Open Library');
    final docs = json['docs'] as List<dynamic>? ?? const [];
    return docs.whereType<Map<String, dynamic>>().map(Book.fromJson).toList();
  }

  Future<Map<String, dynamic>> details(String workId) async {
    final uri = Uri.https('openlibrary.org', '/works/$workId.json');
    return _getJson(client, uri, 'Open Library');
  }
}

class OmdbApi {
  OmdbApi(this.client, {required this.apiKey});

  final http.Client client;
  final String apiKey;

  Future<List<Movie>> search(String query) async {
    _requireKey();
    final uri = Uri.https('www.omdbapi.com', '/', {
      'apikey': apiKey,
      's': query,
      'type': 'movie',
    });
    final json = await _getJson(client, uri, 'OMDb');
    if (json['Response'] == 'False') {
      final error = json['Error'] as String? ?? 'OMDb error';
      if (error == 'Movie not found!') return const [];
      throw ApiException(error);
    }
    final results = json['Search'] as List<dynamic>? ?? const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(Movie.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> details(String imdbId) async {
    _requireKey();
    final uri = Uri.https('www.omdbapi.com', '/', {
      'apikey': apiKey,
      'i': imdbId,
      'plot': 'short',
    });
    final json = await _getJson(client, uri, 'OMDb');
    if (json['Response'] == 'False') {
      throw ApiException(json['Error'] as String? ?? 'OMDb error');
    }
    return json;
  }

  void _requireKey() {
    if (apiKey.isEmpty) {
      throw const ApiException(
        'OMDB_KEY is missing. Run with --dart-define=OMDB_KEY=your-key.',
      );
    }
  }
}

Future<Map<String, dynamic>> _getJson(
  http.Client client,
  Uri uri,
  String service,
) async {
  final http.Response response;
  try {
    response = await client.get(uri).timeout(const Duration(seconds: 15));
  } on TimeoutException {
    throw ApiException('$service took too long to answer.');
  } on http.ClientException {
    throw ApiException('Could not connect to $service.');
  }
  if (response.statusCode != 200) {
    throw ApiException('$service returned HTTP ${response.statusCode}.');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw ApiException('$service returned an invalid response.');
  }
  return decoded;
}
