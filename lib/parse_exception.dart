import 'dart:convert';

/// Exception thrown when JSON parsing fails with detailed context
class ParseException implements Exception {
  /// The main error message describing what went wrong
  final String message;

  /// The specific field that failed to parse (e.g., "id", "email")
  final String? field;

  /// The model/class name where parsing failed (e.g., "User", "Post")
  final String? model;

  /// The expected type as a string (e.g., "int", "String?")
  final String? expected;

  /// The actual value and type received (e.g., "String: '123'")
  final String? actual;

  /// The complete JSON payload for debugging
  final Map<String, dynamic>? json;

  /// The original error if this wraps another exception
  final Object? originalError;

  ParseException(
    this.message, {
    this.field,
    this.model,
    this.expected,
    this.actual,
    this.json,
    this.originalError,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ParseException: $message');

    if (model != null && field != null) {
      buffer.writeln('\n  Location: $model.$field');
    }

    if (expected != null && actual != null) {
      buffer.writeln('  Expected: $expected');
      buffer.writeln('  Actual: $actual');
    }

    if (json != null) {
      buffer.writeln('  JSON: ${jsonEncode(json)}');
    }

    if (originalError != null) {
      buffer.writeln('  Original error: $originalError');
    }

    return buffer.toString();
  }
}
