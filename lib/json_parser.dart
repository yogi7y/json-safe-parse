import 'parse_exception.dart';

/// A parser for JSON data that provides detailed error messages
class JsonParser {
  final Map<String, dynamic> json;
  final String modelName;

  const JsonParser(this.json, this.modelName);

  /// Parse a field from JSON with automatic null handling based on type
  T parse<T>(String key, {T? fallback}) {
    final value = json[key];

    // Check if T is nullable (e.g., String? vs String)
    final isNullable = null is T;

    // Handle null values
    if (value == null) {
      if (isNullable) {
        return null as T; // Valid for nullable types
      }
      if (fallback != null) {
        return fallback;
      }
      _throwMissingField(key);
    }

    // Type checking - Dart's 'is' operator handles this correctly
    if (value is T) {
      return value;
    }

    // Type mismatch - use fallback if available
    if (fallback != null) {
      return fallback;
    }

    _throwTypeMismatch(key, T, value);
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
  List<T> parseList<T>(String key, {List<T>? fallback}) {
    final value = json[key];

    // Handle null values
    if (value == null) {
      if (fallback != null) {
        return fallback;
      }
      _throwMissingField(key);
    }

    // Check if value is a List
    if (value is! List) {
      if (fallback != null) {
        return fallback;
      }
      _throwTypeMismatch(key, List, value);
    }

    // Try to cast the list to List<T>
    try {
      // This will validate each item is of type T
      return List<T>.from(value);
    } catch (e) {
      // If cast fails, try to find which item caused the problem
      if (fallback != null) {
        return fallback;
      }

      // Find the problematic item for better error reporting
      for (int i = 0; i < value.length; i++) {
        if (value[i] != null && value[i] is! T) {
          throw ParseException(
            'Type mismatch in list "$key" at index $i in $modelName',
            field: key,
            model: modelName,
            expected: 'List<$T>',
            actual: 'Item at [$i] is ${value[i].runtimeType}: ${value[i]}',
            json: json,
          );
        }
      }

      // If we couldn't find the specific item, throw generic error
      _throwTypeMismatch(key, List<T>, value);
    }
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
  Map<String, V> parseMap<V>(String key, {Map<String, V>? fallback}) {
    final value = json[key];

    // Handle null values
    if (value == null) {
      if (fallback != null) {
        return fallback;
      }
      _throwMissingField(key);
    }

    // Check if value is a Map
    if (value is! Map) {
      if (fallback != null) {
        return fallback;
      }
      _throwTypeMismatch(key, Map, value);
    }

    // Try to cast the map to Map<String, V>
    try {
      final result = <String, V>{};
      value.forEach((k, v) {
        if (k is! String) {
          throw FormatException('Map key must be String, got ${k.runtimeType}');
        }

        // Special handling for double type - accept int as well
        if (V == double && v is int) {
          result[k as String] = v.toDouble() as V;
        } else if (v != null && v is! V) {
          throw FormatException('Map value at key "$k" must be $V, got ${v.runtimeType}: $v');
        } else {
          result[k as String] = v as V;
        }
      });
      return result;
    } catch (e) {
      if (fallback != null) {
        return fallback;
      }

      // Find the problematic entry for better error reporting
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw ParseException(
            'Invalid map key type in "$key" in $modelName',
            field: key,
            model: modelName,
            expected: 'Map<String, $V>',
            actual: 'Key "${entry.key}" is ${entry.key.runtimeType}',
            json: json,
          );
        }
        if (entry.value != null && entry.value is! V) {
          throw ParseException(
            'Type mismatch in map "$key" at key "${entry.key}" in $modelName',
            field: key,
            model: modelName,
            expected: 'Map<String, $V>',
            actual: 'Value at ["${entry.key}"] is ${entry.value.runtimeType}: ${entry.value}',
            json: json,
          );
        }
      }

      _throwTypeMismatch(key, Map<String, V>, value);
    }
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
