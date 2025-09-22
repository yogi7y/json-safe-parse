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
  /// For custom objects, provide a fromJson function:
  /// ```dart
  /// final tags = parser.parseList<String>('tags');  // Primitives
  /// final users = parser.parseList<User>('users', fromJson: User.fromJson);  // Objects
  /// ```
  List<T> parseList<T>(
    String key, {
    List<T> fallback = const [],
    T Function(Map<String, dynamic>)? fromJson,
  }) {
    final value = json[key];

    if (value == null) {
      return fallback;
    }

    if (value is! List) {
      _throwTypeMismatch(key, List, value);
    }

    final validItems = <T>[];

    for (int i = 0; i < value.length; i++) {
      try {
        if (fromJson != null) {
          if (value[i] is! Map<String, dynamic>) {
            _defaultLogger?.logError({
              'error': 'Expected Map for object parsing',
              'field': key,
              'model': modelName,
              'index': i,
              'expected': 'Map<String, dynamic>',
              'actual': value[i].runtimeType.toString(),
              'value': value[i],
            });
            continue;
          }
          validItems.add(fromJson(value[i] as Map<String, dynamic>));
        } else {
          validItems.add(value[i] as T);
        }
      } catch (e) {
        _defaultLogger?.logError({
          'error': fromJson != null ? 'Object parsing failed' : 'Type mismatch in list',
          'field': key,
          'model': modelName,
          'index': i,
          'expected': T.toString(),
          'actual': value[i],
          'exception': fromJson != null ? e.toString() : null,
        });
      }
    }

    return validItems;
  }

  /// Parse a Map field with specific key and value type validation
  ///
  /// This method ensures that all keys are strings and all values are of type V.
  /// Use this when you need a typed map like Map<String, int> or Map<String, String>.
  ///
  /// For custom objects as values, provide a fromJson function:
  /// ```dart
  /// final scores = parser.parseMap<int>('scores');  // Primitives
  /// final userMap = parser.parseMap<User>('users', fromJson: User.fromJson);  // Objects
  /// ```
  Map<String, V> parseMap<V>(
    String key, {
    Map<String, V> fallback = const {},
    V Function(Map<String, dynamic>)? fromJson,
  }) {
    final value = json[key];

    if (value == null) {
      return fallback;
    }

    if (value is! Map) {
      _throwTypeMismatch(key, Map, value);
    }

    final validEntries = <String, V>{};

    for (final entry in value.entries) {
      if (entry.key is! String) {
        _defaultLogger?.logError({
          'error': 'Invalid map key type',
          'field': key,
          'model': modelName,
          'key': entry.key,
          'keyType': entry.key.runtimeType.toString(),
        });
        continue;
      }

      try {
        if (fromJson != null) {
          if (entry.value is! Map<String, dynamic>) {
            _defaultLogger?.logError({
              'error': 'Expected Map for object parsing',
              'field': key,
              'model': modelName,
              'key': entry.key,
              'expected': 'Map<String, dynamic>',
              'actual': entry.value.runtimeType.toString(),
              'value': entry.value,
            });
            continue;
          }
          validEntries[entry.key as String] = fromJson(entry.value as Map<String, dynamic>);
        } else {
          if (V == double && entry.value is int) {
            validEntries[entry.key as String] = (entry.value as int).toDouble() as V;
          } else {
            validEntries[entry.key as String] = entry.value as V;
          }
        }
      } catch (e) {
        _defaultLogger?.logError({
          'error': fromJson != null ? 'Object parsing failed' : 'Type mismatch in map',
          'field': key,
          'model': modelName,
          'key': entry.key,
          'expected': V.toString(),
          'actual': entry.value,
          'exception': fromJson != null ? e.toString() : null,
        });
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
