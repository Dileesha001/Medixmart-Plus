/// Pagination metadata parsed from Medixmart Plus list responses.
class PaginationMeta {
  final int page;
  final int limit;
  final int totalRecords;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.totalRecords,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  const PaginationMeta.empty({this.limit = 20})
      : page = 1,
        totalRecords = 0,
        totalPages = 1,
        hasNextPage = false,
        hasPrevPage = false;

  /// Parses flat `meta` returned by `medixmart-backend/src/utils/response.js`
  /// and gracefully falls back to nested `meta.pagination`.
  factory PaginationMeta.fromMetaJson(
    Map<String, dynamic>? meta, {
    required int itemCount,
    int defaultLimit = 20,
  }) {
    final nested = meta?['pagination'];
    final source = nested is Map<String, dynamic>
        ? nested
        : (meta ?? const <String, dynamic>{});

    final page = _parseInt(source['page'], fallback: 1);
    final limit = _parseInt(source['limit'], fallback: defaultLimit);
    final totalRecords = _parseInt(
      source['totalRecords'] ?? source['total'],
      fallback: itemCount,
    );
    final computedPages =
        limit > 0 ? ((totalRecords + limit - 1) ~/ limit) : 1;
    final totalPages = _parseInt(
      source['totalPages'],
      fallback: computedPages < 1 ? 1 : computedPages,
    );
    final hasNextPage = _parseBool(
      source['hasNextPage'] ?? source['hasNext'],
      fallback: page < totalPages,
    );
    final hasPrevPage = _parseBool(
      source['hasPrevPage'] ?? source['hasPrev'],
      fallback: page > 1,
    );

    return PaginationMeta(
      page: page < 1 ? 1 : page,
      limit: limit < 1 ? defaultLimit : limit,
      totalRecords: totalRecords < 0 ? 0 : totalRecords,
      totalPages: totalPages < 1 ? 1 : totalPages,
      hasNextPage: hasNextPage,
      hasPrevPage: hasPrevPage,
    );
  }

  static int _parseInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool _parseBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    return fallback;
  }
}

/// Generic paginated collection returned by REST list endpoints.
class PaginatedResponse<T> {
  final List<T> items;
  final PaginationMeta pagination;

  const PaginatedResponse({
    required this.items,
    required this.pagination,
  });
}
