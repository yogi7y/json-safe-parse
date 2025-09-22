import 'error_logger.dart';
import 'parse_exception.dart';

/// A parser for JSON data that provides detailed error messages
class JsonParser {
  static ErrorLogger? _defaultLogger;

  /// Set a global error logger for all JsonParser instances
  static void setDefaultLogger(ErrorLogger logger) {
    _defaultLogger = logger;
  }

  final Map<String, dynamic> json;
  final String modelName;

  const JsonParser(this.json, this.modelName);

  /// Parse a field from JSON with automatic null handling based on type
  T parse<T>(String key, {T? fallback}) {
    final value = json[key];

    final isNullable = null is T;

    // Handle null/missing values - fallback applies here
    if (value == null) {
      if (isNullable) {
        return null as T;
      }
      if (fallback != null) {
        return fallback;
      }
      _throwMissingField(key);
    }

    if (value is! T) _throwTypeMismatch(key, T, value);

    return value;
  }

  /// Parse a List field with specific item type validation
  ///
  /// This method ensures that all items in the list are of type T.
  /// Use this instead of parse<List> when you need a typed list.
  ///
  /// Example:
  /// ```dart
  /// final tags = parser.parseList<String>('tags');  // Returns List<String>
  /// final scores = parser.parseList<int>('scores');  // Returns List<int>
  /// ```
  List<T> parseList<T>(String key, {List<T> fallback = const []}) {
    final value = json[key];

    // Handle null/missing values - use fallback
    if (value == null) {
      return fallback;
    }

    // Type checking - throw for non-list
    if (value is! List) {
      _throwTypeMismatch(key, List, value);
    }

    // Build result list with single iteration
    final validItems = <T>[];

    for (int i = 0; i < value.length; i++) {
      try {
        validItems.add(value[i] as T);
      } catch (e) {
        // Log error if logger is configured
        _defaultLogger?.logError({
          'error': 'Type mismatch in list',
          'field': key,
          'model': modelName,
          'index': i,
          'expected': T.toString(),
          'actual': value[i],
        });
        // Skip this item and continue
      }
    }

    return validItems;
  }

  /// Parse a Map field with specific key and value type validation
  ///
  /// This method ensures that all keys are strings and all values are of type V.
  /// Use this when you need a typed map like Map<String, int> or Map<String, String>.
  ///
  /// Example:
  /// ```dart
  /// final scores = parser.parseMap<int>('scores');  // Returns Map<String, int>
  /// final config = parser.parseMap<String>('config');  // Returns Map<String, String>
  /// ```
  Map<String, V> parseMap<V>(String key, {Map<String, V> fallback = const {}}) {
    final value = json[key];

    // Handle null/missing values - use fallback
    if (value == null) {
      return fallback;
    }

    // Type checking - throw for non-map
    if (value is! Map) {
      _throwTypeMismatch(key, Map, value);
    }

    // Build result map with single iteration
    final validEntries = <String, V>{};

    for (final entry in value.entries) {
      // Check key is String
      if (entry.key is! String) {
        _defaultLogger?.logError({
          'error': 'Invalid map key type',
          'field': key,
          'model': modelName,
          'key': entry.key,
          'keyType': entry.key.runtimeType.toString(),
        });
        continue; // Skip this entry
      }

      // Try to cast the value
      try {
        // Special handling for double type - accept int as well
        if (V == double && entry.value is int) {
          validEntries[entry.key as String] = (entry.value as int).toDouble() as V;
        } else {
          validEntries[entry.key as String] = entry.value as V;
        }
      } catch (e) {
        // Log error if logger is configured
        _defaultLogger?.logError({
          'error': 'Type mismatch in map',
          'field': key,
          'model': modelName,
          'key': entry.key,
          'expected': V.toString(),
          'actual': entry.value,
        });
        // Skip this entry and continue
      }
    }

    return validEntries;
  }

  Never _throwMissingField(String key) {
    throw ParseException(
      'Missing required field "$key" in $modelName',
      field: key,
      model: modelName,
      json: json,
    );
  }

  Never _throwTypeMismatch(String key, Type expected, dynamic actual) {
    throw ParseException(
      'Type mismatch for field "$key" in $modelName',
      field: key,
      model: modelName,
      expected: expected.toString(),
      actual: '${actual.runtimeType}: $actual',
      json: json,
    );
  }
}
