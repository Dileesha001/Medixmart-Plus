import 'dashboard_models.dart';

/// Alert categories defined by the Medixmart Plus `alerts` schema.
enum AlertType {
  expired('expired', 'Expired', 'Expired'),
  expiryWarning('expiry_warning', 'Expiring ≤ 7M', 'Expiring 7M'),
  lowStock('low_stock', 'Low Stock', 'Low Stock'),
  creditOverdue('credit_overdue', 'Credit Overdue', 'Credit Overdue'),
  birthday('birthday', 'Birthday', 'Birthday');

  final String queryValue;
  final String label;
  final String shortBadgeLabel;

  const AlertType(this.queryValue, this.label, this.shortBadgeLabel);

  /// Parses an API `alert_type` string into [AlertType], or `null` if unknown.
  static AlertType? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    for (final value in values) {
      if (value.queryValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// Alert severity levels returned by `GET /api/alerts`.
enum AlertSeverity {
  danger('danger', 'Danger'),
  warning('warning', 'Warning'),
  info('info', 'Info');

  final String queryValue;
  final String label;

  const AlertSeverity(this.queryValue, this.label);

  /// Parses an API `severity` string, falling back to [AlertSeverity.info].
  static AlertSeverity fromRaw(String? raw) {
    if (raw == null) return AlertSeverity.info;
    final normalized = raw.trim().toLowerCase();
    for (final value in values) {
      if (value.queryValue == normalized) {
        return value;
      }
    }
    return AlertSeverity.info;
  }
}

/// Domain model for an alert item (`GET /api/alerts`).
class AlertModel {
  final int id;
  final AlertType? alertType;
  final String rawAlertType;
  final AlertSeverity severity;
  final String title;
  final String message;
  final String? referenceTable;
  final int? referenceId;
  final bool isResolved;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  const AlertModel({
    required this.id,
    required this.alertType,
    required this.rawAlertType,
    required this.severity,
    required this.title,
    required this.message,
    this.referenceTable,
    this.referenceId,
    this.isResolved = false,
    this.resolvedAt,
    this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['alert_type'] as String? ?? '').trim();
    final rawSeverity = json['severity'] as String?;
    final rawRefTable = _nullableTrimmed(json['reference_table'] as String?);
    final rawResolvedAt = json['resolved_at'] as String?;
    final rawCreatedAt = json['created_at'] as String?;

    return AlertModel(
      id: _parseInt(json['id']),
      alertType: AlertType.tryParse(rawType),
      rawAlertType: rawType,
      severity: AlertSeverity.fromRaw(rawSeverity),
      title: (json['title'] as String? ?? '').trim(),
      message: (json['message'] as String? ?? '').trim(),
      referenceTable: rawRefTable,
      referenceId: _parseNullableInt(json['reference_id']),
      isResolved: _parseBool(json['is_resolved']),
      resolvedAt:
          rawResolvedAt != null ? DateTime.tryParse(rawResolvedAt) : null,
      createdAt: rawCreatedAt != null ? DateTime.tryParse(rawCreatedAt) : null,
    );
  }

  /// Human-readable reference label (e.g., `Batch #61`), or `null` if absent.
  String? get referenceLabel {
    if (referenceTable == null ||
        referenceTable!.isEmpty ||
        referenceId == null) {
      return null;
    }
    switch (referenceTable!.toLowerCase()) {
      case 'batches':
        return 'Batch #$referenceId';
      case 'medicines':
        return 'Medicine #$referenceId';
      case 'customers':
        return 'Customer #$referenceId';
      case 'sales':
        return 'Sale #$referenceId';
      default:
        return '$referenceTable #$referenceId';
    }
  }

  String get typeLabel => alertType?.label ?? rawAlertType;

  /// Converts this alert into a Dashboard `Recent Alerts` feed item.
  AlertItemData toDashboardAlertItem() {
    final StatusTone tone;
    switch (alertType) {
      case AlertType.expired:
        tone = StatusTone.expired;
        break;
      case AlertType.expiryWarning:
        tone = StatusTone.expiring7M;
        break;
      case AlertType.lowStock:
        tone = StatusTone.lowStock;
        break;
      case AlertType.creditOverdue:
        tone = severity == AlertSeverity.danger
            ? StatusTone.expired
            : StatusTone.lowStock;
        break;
      case AlertType.birthday:
      case null:
        tone = StatusTone.inStock;
        break;
    }

    return AlertItemData(
      title: title,
      meta: message,
      tone: tone,
      badgeLabel: alertType?.shortBadgeLabel ?? rawAlertType,
    );
  }
}

/// Active alert counter summary returned by `GET /api/alerts/summary`.
class AlertSummary {
  final int totalActive;
  final int dangerCount;
  final int warningCount;
  final int infoCount;
  final int expiredCount;
  final int expiringSoonCount;
  final int lowStockCount;

  const AlertSummary({
    required this.totalActive,
    required this.dangerCount,
    required this.warningCount,
    required this.infoCount,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.lowStockCount,
  });

  const AlertSummary.empty()
      : totalActive = 0,
        dangerCount = 0,
        warningCount = 0,
        infoCount = 0,
        expiredCount = 0,
        expiringSoonCount = 0,
        lowStockCount = 0;

  factory AlertSummary.fromJson(Map<String, dynamic> json) {
    return AlertSummary(
      totalActive: _parseInt(json['total_active']),
      dangerCount: _parseInt(json['danger_count']),
      warningCount: _parseInt(json['warning_count']),
      infoCount: _parseInt(json['info_count']),
      expiredCount: _parseInt(json['expired_count']),
      expiringSoonCount: _parseInt(json['expiring_soon_count']),
      lowStockCount: _parseInt(json['low_stock_count']),
    );
  }
}

/// Execution stats returned by `POST /api/alerts/generate-expiry`.
class ExpiryCheckResult {
  final String message;
  final int expiredAlertsCreated;
  final int warningAlertsCreated;
  final int alertsAutoResolved;

  const ExpiryCheckResult({
    required this.message,
    required this.expiredAlertsCreated,
    required this.warningAlertsCreated,
    required this.alertsAutoResolved,
  });

  int get totalChanges =>
      expiredAlertsCreated + warningAlertsCreated + alertsAutoResolved;

  factory ExpiryCheckResult.fromJson(Map<String, dynamic> data) {
    final stats = data['stats'] as Map<String, dynamic>? ?? const {};
    return ExpiryCheckResult(
      message: (data['message'] as String? ??
              'Expiry alert engine executed successfully.')
          .trim(),
      expiredAlertsCreated: _parseInt(stats['expired_alerts_created']),
      warningAlertsCreated: _parseInt(stats['warning_alerts_created']),
      alertsAutoResolved: _parseInt(stats['alerts_auto_resolved']),
    );
  }
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? fallback;
}

int? _parseNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}

bool _parseBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

String? _nullableTrimmed(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
