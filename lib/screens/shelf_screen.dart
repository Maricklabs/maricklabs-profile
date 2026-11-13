import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../data/pick_source.dart';
import '../data/shelf_api.dart';
import '../models/book.dart';
import '../models/movie.dart';
import '../models/pick.dart';

const omdbKey = String.fromEnvironment('OMDB_KEY');
const cmsName = String.fromEnvironment('CMS', defaultValue: 'strapi');
const cmsUrl = String.fromEnvironment('CMS_URL');
const cmsToken = String.fromEnvironment('CMS_TOKEN');
const cmsSpace = String.fromEnvironment('CMS_SPACE');
const cmsProject = String.fromEnvironment('CMS_PROJECT');
const cmsDataset = String.fromEnvironment(
  'CMS_DATASET',
  defaultValue: 'production',
);

class ShelfScreen extends StatefulWidget {
  const ShelfScreen({super.key});

  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  final http.Client _client = http.Client();

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booksApi = OpenLibraryApi(_client);
    final moviesApi = OmdbApi(_client, apiKey: omdbKey);
    final source = CmsPickSource(
      _client,
      cms: cmsName,
      url: cmsUrl,
      token: cmsToken,
      space: cmsSpace,
      project: cmsProject,
      dataset: cmsDataset,
    );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Shelf'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Picks'),
              Tab(text: 'Books'),
              Tab(text: 'Movies'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MyPicksScreen(source: source, client: _client),
            BooksScreen(api: booksApi),
            MoviesScreen(api: moviesApi),
          ],
        ),
      ),
    );
  }
}

class BooksScreen extends StatefulWidget {
  const BooksScreen({required this.api, super.key});

  final OpenLibraryApi api;

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  Timer? _debounce;
  Future<List<Book>>? _results;

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = text.trim();
      if (query.length < 3) {
        setState(() => _results = null);
      } else {
        final results = widget.api.search(query);
        setState(() {
          _results = results;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _onChanged,
            decoration: const InputDecoration(
              labelText: 'Search books',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: _results == null
              ? const Center(child: Text('Type at least 3 letters to search.'))
              : _BookResults(future: _results!),
        ),
      ],
    );
  }
}

class _BookResults extends StatelessWidget {
  const _BookResults({required this.future});

  final Future<List<Book>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Book>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final books = snapshot.data ?? const [];
        if (books.isEmpty) return const Center(child: Text('Nothing found.'));
        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return ListTile(
              leading: book.coverId == null
                  ? const Icon(Icons.menu_book)
                  : Image.network(
                      'https://covers.openlibrary.org/b/id/${book.coverId}-M.jpg',
                      width: 48,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      errorBuilder: (_, _, _) => const Icon(Icons.menu_book),
                    ),
              title: Text(book.title),
              subtitle: Text(
                '${book.authors.isEmpty ? 'Unknown author' : book.authors.first}'
                '${book.year == null ? '' : ' • ${book.year}'}',
              ),
              trailing: IconButton(
                tooltip: 'Copy book ID',
                icon: const Icon(Icons.copy),
                onPressed: () =>
                    _copyId(context, book.workId, 'Book ID copied'),
              ),
            );
          },
        );
      },
    );
  }
}

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({required this.api, super.key});

  final OmdbApi api;

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  Timer? _debounce;
  Future<List<Movie>>? _results;

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = text.trim();
      if (query.length < 3) {
        setState(() => _results = null);
      } else {
        final results = widget.api.search(query);
        setState(() {
          _results = results;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (omdbKey.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'OMDB_KEY is missing. Restart with --dart-define-from-file=config.local.json.',
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _onChanged,
            decoration: const InputDecoration(
              labelText: 'Search movies',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: _results == null
              ? const Center(child: Text('Type at least 3 letters to search.'))
              : _MovieResults(future: _results!),
        ),
      ],
    );
  }
}

class _MovieResults extends StatelessWidget {
  const _MovieResults({required this.future});

  final Future<List<Movie>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final movies = snapshot.data ?? const [];
        if (movies.isEmpty) return const Center(child: Text('Nothing found.'));
        return ListView.builder(
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            return ListTile(
              leading: movie.poster == null
                  ? const Icon(Icons.movie)
                  : Image.network(
                      movie.poster!,
                      width: 48,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      errorBuilder: (_, _, _) => const Icon(Icons.movie),
                    ),
              title: Text(movie.title),
              subtitle: Text(movie.year),
              trailing: IconButton(
                tooltip: 'Copy movie ID',
                icon: const Icon(Icons.copy),
                onPressed: () =>
                    _copyId(context, movie.imdbId, 'Movie ID copied'),
              ),
            );
          },
        );
      },
    );
  }
}

class MyPicksScreen extends StatefulWidget {
  const MyPicksScreen({required this.source, required this.client, super.key});

  final PickSource source;
  final http.Client client;

  @override
  State<MyPicksScreen> createState() => _MyPicksScreenState();
}

class _MyPicksScreenState extends State<MyPicksScreen> {
  late Future<List<Pick>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.source.fetchPicks();
  }

  Future<void> _refresh() async {
    final future = widget.source.fetchPicks();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Pick>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                SizedBox(
                  height: 300,
                  child: Center(child: Text('Error: ${snapshot.error}')),
                ),
              ],
            ),
          );
        }
        final picks = snapshot.data ?? const [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: picks.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(
                      height: 300,
                      child: Center(child: Text('No picks yet.')),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: picks.length,
                  itemBuilder: (context, index) {
                    final pick = picks[index];
                    return ListTile(
                      leading: Icon(
                        pick.kind == 'movie' ? Icons.movie : Icons.menu_book,
                      ),
                      title: Text(pick.title),
                      subtitle: Text(pick.note),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PickDetailScreen(
                            pick: pick,
                            client: widget.client,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class PickDetailScreen extends StatelessWidget {
  const PickDetailScreen({required this.pick, required this.client, super.key});

  final Pick pick;
  final http.Client client;

  @override
  Widget build(BuildContext context) {
    final future = pick.kind == 'movie'
        ? OmdbApi(client, apiKey: omdbKey).details(_movieId(pick.externalId))
        : OpenLibraryApi(client).details(_workId(pick.externalId));
    return Scaffold(
      appBar: AppBar(title: Text(pick.title)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final json = snapshot.data!;
          final isMovie = pick.kind == 'movie';
          final imageUrl = switch (isMovie) {
            true =>
              ((json['Poster'] as String?) == 'N/A'
                  ? null
                  : json['Poster'] as String?),
            false => switch (json['covers']) {
              [final int coverId, ...] =>
                'https://covers.openlibrary.org/b/id/$coverId-M.jpg',
              _ => null,
            },
          };
          final year = isMovie
              ? json['Year'] as String? ?? 'Unknown year'
              : json['first_publish_date'] as String? ?? 'Unknown year';
          final description = isMovie
              ? json['Plot'] as String? ?? 'No description yet.'
              : switch (json['description']) {
                  final String text => text,
                  {'value': final String text} => text,
                  _ => 'No description yet.',
                };
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (imageUrl != null)
                Image.network(
                  imageUrl,
                  height: 260,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                )
              else
                Icon(isMovie ? Icons.movie : Icons.menu_book, size: 96),
              const SizedBox(height: 16),
              Text(
                isMovie
                    ? json['Title'] as String? ?? pick.title
                    : json['title'] as String? ?? pick.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Year: $year'),
              const SizedBox(height: 8),
              Text('Your note: ${pick.note}'),
              const SizedBox(height: 16),
              Text(description),
            ],
          );
        },
      ),
    );
  }
}

String _workId(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'/works/([^/]+)').firstMatch(trimmed);
  return match?.group(1) ?? trimmed.split('/').last;
}

String _movieId(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'(tt\d+)', caseSensitive: false).firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}

void _copyId(BuildContext context, String id, String message) {
  Clipboard.setData(ClipboardData(text: id));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
