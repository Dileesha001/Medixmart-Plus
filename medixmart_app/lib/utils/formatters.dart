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
}
