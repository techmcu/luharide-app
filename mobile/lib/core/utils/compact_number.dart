/// Compact, UI-safe number formatting for the admin panel.
///
/// Big counts (driver KYC, total users, broadcast recipients, revenue…) must never
/// push a fixed-width stat card or a circular badge out of bounds. We shorten them
/// with Indian grouping — thousand (k), lakh (L), crore (Cr) — so the rendered text
/// stays a few characters regardless of how large the underlying number grows.
///
///   999      → "999"
///   1000     → "1k"      1100   → "1.1k"    44000  → "44k"
///   100000   → "1L"      125000 → "1.3L"
///   12000000 → "1.2Cr"
library;

String _trimDecimal(num v) {
  // One decimal place, but drop a trailing ".0" so we show "1k", not "1.0k".
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Short, never-overflowing string for a count. Null/garbage → "0".
String compactCount(num? value) {
  final n = value ?? 0;
  final abs = n.abs();
  if (abs < 1000) return '${n.toInt()}';
  if (abs < 100000) return '${_trimDecimal(n / 1000)}k';
  if (abs < 10000000) return '${_trimDecimal(n / 100000)}L';
  return '${_trimDecimal(n / 10000000)}Cr';
}

/// Compact rupee amount, e.g. ₹1.2L. Small amounts stay exact (₹450).
String compactCurrency(num? value) => '₹${compactCount(value)}';
