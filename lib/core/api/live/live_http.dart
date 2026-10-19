import 'dart:convert';

import 'package:dio/dio.dart';

import '../api_client.dart';

/// Dio for the public data APIs, with the app's [apiTimeout].
Dio createLiveDio() => Dio(
  BaseOptions(
    connectTimeout: apiTimeout,
    sendTimeout: apiTimeout,
    receiveTimeout: apiTimeout,
    responseType: ResponseType.json,
    // GIOŚ answers 406 to a bare `application/json`: it serves JSON-LD.
    headers: {
      'Accept': 'application/json, application/ld+json;q=0.9, */*;q=0.8',
    },
  ),
);

/// GET [url] of a public data API (IMGW, GIOŚ) and return the decoded JSON
/// body. Errors become [ApiException] like in `RemoteApiClient`, except that
/// any HTTP error is `server`: a moved or blocked third-party endpoint (410,
/// 403, 406) is an outage for the app, so it falls back to cached/demo data.
Future<Object?> getJson(Dio dio, String url) async {
  final Response<Object?> response;
  try {
    response = await dio.get<Object?>(url);
  } on DioException catch (e) {
    final error = mapDioError(e);
    if (error.kind == ApiErrorKind.notFound ||
        error.kind == ApiErrorKind.badRequest) {
      throw ApiException(ApiErrorKind.server, error.message, error.statusCode);
    }
    throw error;
  }
  final data = response.data;
  if (data is! String) return data;
  try {
    return jsonDecode(data);
  } on FormatException catch (e) {
    throw ApiException(ApiErrorKind.server, 'bad response: $e');
  }
}

ApiException mapDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return ApiException(ApiErrorKind.timeout, e.message);
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode;
      return ApiException(
        switch (status) {
          404 => ApiErrorKind.notFound,
          408 || 429 => ApiErrorKind.server,
          final s? when s >= 400 && s < 500 => ApiErrorKind.badRequest,
          _ => ApiErrorKind.server,
        },
        e.message,
        status,
      );
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return ApiException(ApiErrorKind.network, e.message);
  }
}

const _plain = {
  'ą': 'a',
  'ć': 'c',
  'ę': 'e',
  'ł': 'l',
  'ń': 'n',
  'ó': 'o',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
};

/// Lower case, Polish letters without diacritics, single spaces:
/// `"Wartość  Indeksu"` → `"wartosc indeksu"`.
String normalizeKey(String value) {
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    buffer.write(_plain[char] ?? char);
  }
  return buffer.toString().trim().replaceAll(RegExp(r'[\s_]+'), ' ');
}

/// `1`, `1.5`, `"51,758"`, `" 2 "` → num; anything else → null.
num? parseNum(Object? value) {
  if (value is num) return value;
  if (value is String) {
    return num.tryParse(value.trim().replaceAll(',', '.'));
  }
  return null;
}

int? parseInt(Object? value) {
  final n = parseNum(value);
  if (n == null || !n.isFinite) return null;
  return n.round();
}

/// The value under the first key of [map] whose [normalizeKey] passes [test].
Object? findValue(Map<Object?, Object?> map, bool Function(String key) test) {
  for (final entry in map.entries) {
    final key = entry.key;
    if (key is String && test(normalizeKey(key))) return entry.value;
  }
  return null;
}

/// Non-empty trimmed string, or null. Numbers are turned into strings.
String? asText(Object? value) {
  if (value is num) return value.toString();
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}
