/// Pure-Dart display formatters for Medixmart Plus UI components.
abstract final class MmFormatters {
  /// Formats a numeric amount in Sri Lankan Rupees (`Rs. #,##0.00`).
  static String currencyLkr(double amount) {
    final isNegative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final remaining = intPart.length - i;
      if (i > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }

    final prefix = isNegative ? '-Rs. ' : 'Rs. ';
    return '$prefix${buffer.toString()}.$decPart';
  }

  /// Pads single-digit non-negative counts with a leading zero (e.g. `08`).
  static String twoDigitCount(int count) {
    if (count >= 0 && count < 10) {
      return '0$count';
    }
    return '$count';
  }

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats a [DateTime] in local time as `DD Mon YYYY, HH:MM`.
  static String shortDateTime(DateTime dt) {
    final local = dt.toLocal();
    final day = twoDigitCount(local.day);
    final month = _monthNames[local.month - 1];
    final year = local.year;
    final hour = twoDigitCount(local.hour);
    final minute = twoDigitCount(local.minute);
    return '$day $month $year, $hour:$minute';
  }
}
