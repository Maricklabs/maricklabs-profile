import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pick.dart';
import 'shelf_api.dart';

abstract interface class PickSource {
  Future<List<Pick>> fetchPicks();
}

class CmsPickSource implements PickSource {
  CmsPickSource(
    this.client, {
    required this.cms,
    this.url = '',
    this.token = '',
    this.space = '',
    this.project = '',
    this.dataset = 'production',
  });

  final http.Client client;
  final String cms;
  final String url;
  final String token;
  final String space;
  final String project;
  final String dataset;

  @override
  Future<List<Pick>> fetchPicks() async {
    if (cms == 'strapi' && url.trim().isEmpty) {
      throw const ApiException(
        'CMS_URL is missing. Run with --dart-define=CMS_URL=http://localhost:1337.',
      );
    }
    final request = _request();
    final http.Response response;
    try {
      response = await client
          .get(request.uri, headers: request.headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException('$cms took too long to answer.');
    } on http.ClientException {
      throw ApiException('Could not connect to $cms.');
    }
    if (response.statusCode != 200) {
      throw ApiException('$cms returned HTTP ${response.statusCode}.');
    }
    final Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        '$cms returned HTML or invalid JSON. Check the CMS URL and API path.',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw ApiException('$cms returned an invalid response.');
    }
    final items = switch (cms) {
      'strapi' => json['data'] as List<dynamic>? ?? [],
      'contentful' => json['items'] as List<dynamic>? ?? [],
      'sanity' => json['result'] as List<dynamic>? ?? [],
      _ => throw const ApiException(
        'Set CMS to strapi, contentful, or sanity.',
      ),
    };
    return items.whereType<Map<String, dynamic>>().map(_pickFromJson).toList();
  }

  _CmsRequest _request() {
    return switch (cms) {
      'strapi' => _CmsRequest(
        Uri.parse('$url/api/picks')
            .replace(queryParameters: {'pagination[pageSize]': '100'}),
        {if (token.isNotEmpty) 'Authorization': 'Bearer $token'},
      ),
      'contentful' => _CmsRequest(
        Uri.https(
          'cdn.contentful.com',
          '/spaces/$space/environments/master/entries',
          {'content_type': 'pick', 'limit': '100'},
        ),
        {'Authorization': token},
      ),
      'sanity' => _CmsRequest(
        Uri.https(
          '$project.apicdn.sanity.io',
          '/v2025-02-19/data/query/$dataset',
          {
            'query':
                '*[_type == "pick"] | order(title asc) '
                '{title, kind, externalId, note}',
          },
        ),
        {if (token.isNotEmpty) 'Authorization': 'Bearer $token'},
      ),
      _ => throw const ApiException(
        'Set CMS to strapi, contentful, or sanity.',
      ),
    };
  }

  Pick _pickFromJson(Map<String, dynamic> json) {
    final fields = cms == 'contentful'
        ? (json['fields'] as Map<String, dynamic>? ?? const {})
        : json;
    return Pick(
      title: fields['title'] as String? ?? 'Untitled pick',
      kind: (fields['kind'] as String? ?? 'book').trim().toLowerCase(),
      externalId: fields['externalId'] as String? ?? '',
      note: fields['note'] as String? ?? '',
    );
  }
}

class _CmsRequest {
  const _CmsRequest(this.uri, this.headers);

  final Uri uri;
  final Map<String, String> headers;
}
