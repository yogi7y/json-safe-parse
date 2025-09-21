# Safe JSON Serialization for Flutter

A simple internal tool for better error messages when parsing JSON in our Flutter applications.

## The Problem

We all write code like this:

```dart
User.fromJson(Map<String, dynamic> json) {
  return User(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String,
  );
}
```

When it fails in production, we see:
```
type 'String' is not a subtype of type 'int' in type cast
```

This tells us nothing. We don't know:
- Which field failed
- Which model failed
- What the actual value was
- What the full JSON payload looked like

## The Solution

A simple parser that captures context when things go wrong:

```dart
class User {
  final int id;
  final String name;
  final String? email;
  final List<String> tags;

  User.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'User');

    return User(
      id: parser.parse<int>('id'),
      name: parser.parse<String>('name'),
      email: parser.parse<String?>('email'),
      tags: parser.parse<List<String>>('tags', fallback: []),
    );
  }
}
```

When this fails, we get:
```
ParseException: Failed to parse User.id
  Expected: int
  Actual: "12345" (String)
  Full JSON: {"id": "12345", "name": "John", "email": "john@example.com"}
```

## Parsing Scenarios We Handle

### Basic Types
- **Non-nullable primitive** - `parser.parse<int>('age')` - Throws if null or wrong type
- **Nullable primitive** - `parser.parse<String?>('bio')` - Returns null if missing, validates type if present
- **Non-nullable with fallback** - `parser.parse<String>('name', fallback: 'Anonymous')` - Uses fallback if null/wrong type
- **Boolean values** - `parser.parse<bool>('isActive')` - Expects true/false, no coercion from strings
- **Doubles** - `parser.parse<double>('price')` - Expects numeric value, not "12.99" string

### Collections
- **Non-nullable list** - `parser.parse<List<String>>('tags')` - Throws if null, expects array
- **Nullable list** - `parser.parse<List<String>?>('tags')` - Returns null if missing
- **List with fallback** - `parser.parse<List<int>>('scores', fallback: [])` - Empty list if missing/invalid
- **List of nullable items** - `parser.parse<List<String?>>('items')` - List can contain nulls
- **Nested lists** - `parser.parse<List<List<int>>>('matrix')` - Multi-dimensional arrays

### Objects
- **Nested object** - `parser.parse<Map<String, dynamic>>('address')` - For nested JSON objects
- **Nullable nested object** - `parser.parse<Map<String, dynamic>?>('metadata')` - Can be null
- **Object with fallback** - `parser.parse<Map>('config', fallback: {})` - Empty map if missing
- **List of objects** - `parser.parse<List<Map<String, dynamic>>>('users')` - Array of JSON objects

### Complex Scenarios
- **Custom parsing required** - `DateTime.parse(parser.parse<String>('createdAt'))` - Parse string then convert
- **Enum from string** - `Status.values.byName(parser.parse<String>('status'))` - Parse string then map
- **Deep nesting** - Parse object, create new parser: `UserParser(parser.parse<Map>('author'), 'User')`
- **Optional in required** - `parser.parse<String>('name', fallback: '') ?? ''` - Multiple safety layers
- **Dynamic/Object type** - `parser.parse<Object>('data')` - When type varies
- **Map types** - `parser.parse<Map<String, int>>('counts')` - Typed maps

### Error Cases
- **Missing required field** - `parser.parse<int>('id')` with no `id` in JSON - Throws with context
- **Type mismatch** - `parser.parse<int>('age')` receives `"25"` - Shows expected vs actual
- **Null in non-nullable** - `parser.parse<String>('email')` receives `null` - Clear null error
- **Wrong collection type** - `parser.parse<List>('tags')` receives object - Shows type difference
- **Invalid nested structure** - `parser.parse<Map>('user')` receives array - Full JSON in error

### Edge Cases
- **Empty strings vs null** - `parser.parse<String?>('name')` - Empty string "" is valid, different from null
- **Zero vs null** - `parser.parse<int?>('count')` - Zero is valid value, different from missing
- **Empty collections** - `parser.parse<List>('items')` - Empty array [] is valid, not null
- **Partial objects** - Some fields present, others missing - Each field validated independently
- **Mixed type lists** - `parser.parse<List<dynamic>>('mixed')` - When array has mixed types

## Handling Nested JSON

For nested JSON, each level creates its own parser with proper context. This keeps the implementation simple and error messages clear.

### Example JSON Structure

```json
{
  "id": 123,
  "name": "John Doe",
  "email": "john@example.com",
  "address": {
    "street": "123 Main St",
    "city": "Boston",
    "country": "USA",
    "zipCode": "02134"
  },
  "preferences": {
    "theme": "dark",
    "notifications": {
      "email": true,
      "push": false,
      "frequency": "daily"
    }
  },
  "tags": ["premium", "verified"]
}
```

### The Pattern: Each Level Gets Its Own Parser

```dart
class User {
  final int id;
  final String name;
  final Address address;
  final Preferences preferences;
  final List<String> tags;

  User.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'User');

    return User(
      id: parser.parse<int>('id'),
      name: parser.parse<String>('name'),
      // Pass nested JSON to Address constructor
      address: Address.fromJson(
        parser.parse<Map<String, dynamic>>('address')
      ),
      preferences: Preferences.fromJson(
        parser.parse<Map<String, dynamic>>('preferences')
      ),
      tags: parser.parse<List<String>>('tags'),
    );
  }
}

class Address {
  final String street;
  final String city;
  final String country;
  final String zipCode;

  Address.fromJson(Map<String, dynamic> json) {
    // Create new parser for this nested level
    final parser = JsonParser(json, 'Address');

    return Address(
      street: parser.parse<String>('street'),
      city: parser.parse<String>('city'),
      country: parser.parse<String>('country'),
      zipCode: parser.parse<String>('zipCode'),
    );
  }
}

class Preferences {
  final String theme;
  final NotificationSettings notifications;

  Preferences.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'Preferences');

    return Preferences(
      theme: parser.parse<String>('theme'),
      // Another level of nesting
      notifications: NotificationSettings.fromJson(
        parser.parse<Map<String, dynamic>>('notifications')
      ),
    );
  }
}

class NotificationSettings {
  final bool email;
  final bool push;
  final String frequency;

  NotificationSettings.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'NotificationSettings');

    return NotificationSettings(
      email: parser.parse<bool>('email'),
      push: parser.parse<bool>('push'),
      frequency: parser.parse<String>('frequency'),
    );
  }
}
```

### Handling Optional Nested Objects

```dart
class User {
  final String name;
  final Address? address;  // Optional
  final Preferences? preferences;  // Optional

  User.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'User');

    // Parse nullable nested objects
    final addressJson = parser.parse<Map<String, dynamic>?>('address');
    final prefsJson = parser.parse<Map<String, dynamic>?>('preferences');

    return User(
      name: parser.parse<String>('name'),
      // Only create if present
      address: addressJson != null ? Address.fromJson(addressJson) : null,
      preferences: prefsJson != null ? Preferences.fromJson(prefsJson) : null,
    );
  }
}
```

### Lists of Nested Objects

```dart
class Team {
  final String name;
  final List<User> members;

  Team.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'Team');

    final membersJson = parser.parse<List<Map<String, dynamic>>>('members');
    return Team(
      name: parser.parse<String>('name'),
      members: membersJson.map((u) => User.fromJson(u)).toList(),
    );
  }
}
```

### Error Messages Show Full Context

When parsing fails deep in the structure, you know exactly where:

```
ParseException: Failed to parse NotificationSettings.frequency
  Location: NotificationSettings.frequency
  Expected: String
  Actual: 123 (int)
  JSON: {"email": true, "push": false, "frequency": 123}
```

Benefits of this approach:
- **No magic** - Explicit parsing at each level
- **Clear errors** - Each model provides its own context
- **Type safe** - Compiler validates types at each level
- **Reusable** - Models work independently
- **Simple** - No complex path parsing or dot notation

## Implementation

```dart
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
        return null as T;  // Valid for nullable types
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
```

## How It Works: Detailed Walkthrough

Let's trace through exactly how our parser handles different scenarios:

### Scenario 1: Non-Nullable Field (Required)

```dart
final json = {'name': 'John', 'age': 30};
final parser = JsonParser(json, 'User');

// Successful parse
final name = parser.parse<String>('name');  // Returns 'John'
// 1. value = 'John'
// 2. isNullable = false (null is not String)
// 3. value is String? YES → return 'John'

// Missing field
final email = parser.parse<String>('email');  // Throws!
// 1. value = null
// 2. isNullable = false
// 3. fallback = null
// 4. Throws: Missing required field "email" in User

// Wrong type
final json2 = {'age': '30'};  // String instead of int
final age = parser.parse<int>('age');  // Throws!
// 1. value = '30'
// 2. value is int? NO
// 3. fallback = null
// 4. Throws: Type mismatch for field "age" in User
//    Expected: int, Actual: String: '30'
```

### Scenario 2: Nullable Field

```dart
final json = {'name': 'John'};  // No bio field
final parser = JsonParser(json, 'User');

final bio = parser.parse<String?>('bio');  // Returns null
// 1. value = null
// 2. isNullable = true (null is String?)
// 3. Return null as String?

final json2 = {'bio': 'Developer'};
final bio2 = parser.parse<String?>('bio');  // Returns 'Developer'
// 1. value = 'Developer'
// 2. value is String?? YES → return 'Developer'
```

### Scenario 3: Fallback Values

```dart
final json = {'name': 'John'};  // Missing tags
final parser = JsonParser(json, 'User');

// Fallback on missing
final tags = parser.parse<List<String>>('tags', fallback: []);  // Returns []
// 1. value = null
// 2. isNullable = false
// 3. fallback != null → return []

// Fallback on wrong type
final json2 = {'count': 'abc'};  // String instead of int
final count = parser.parse<int>('count', fallback: 0);  // Returns 0
// 1. value = 'abc'
// 2. value is int? NO
// 3. fallback != null → return 0
```

### Scenario 4: Collections

```dart
final json = {
  'tags': ['dart', 'flutter'],
  'scores': [90, 85, 88],
};
final parser = JsonParser(json, 'Data');

// List<String>
final tags = parser.parse<List<String>>('tags');  // Returns ['dart', 'flutter']
// 1. value = ['dart', 'flutter']
// 2. value is List<String>? YES (Dart checks this properly!)
// 3. Return the list

// IMPORTANT: Dart's type system validates list contents!
final json2 = {'tags': ['dart', 123]};  // Mixed types
final tags2 = parser.parse<List<String>>('tags');  // Throws!
// 1. value = ['dart', 123]
// 2. value is List<String>? NO (contains non-String)
// 3. Throws: Type mismatch
```

### Scenario 5: Nested Objects

```dart
final json = {
  'user': {
    'id': 1,
    'name': 'John',
    'address': {
      'city': 'Boston'
    }
  }
};
final parser = JsonParser(json, 'Response');

// Get nested object
final userData = parser.parse<Map<String, dynamic>>('user');
// Returns the whole user map

// Create nested parser
final userParser = JsonParser(userData, 'User');
final name = userParser.parse<String>('name');  // 'John'

// Deep nesting
final addressData = userParser.parse<Map<String, dynamic>>('address');
final addressParser = JsonParser(addressData, 'Address');
final city = addressParser.parse<String>('city');  // 'Boston'
```

### Scenario 6: Edge Cases

```dart
// Empty string vs null
final json = {'name': ''};  // Empty string
final name = parser.parse<String>('name');  // Returns '' (valid!)
final missing = parser.parse<String>('missing');  // Throws (null)

// Zero vs null
final json2 = {'count': 0};  // Zero
final count = parser.parse<int>('count');  // Returns 0 (valid!)

// Boolean false vs null
final json3 = {'active': false};
final active = parser.parse<bool>('active');  // Returns false (valid!)

// Empty collections
final json4 = {'items': []};
final items = parser.parse<List>('items');  // Returns [] (valid!)
```

### The Magic: How Dart's Type System Helps Us

The key insight is using Dart's built-in type checking:

1. **`null is T`** - Tells us if T is nullable
   - `null is String?` → true (nullable)
   - `null is String` → false (non-nullable)

2. **`value is T`** - Properly validates types including generics
   - `[1, 2] is List<int>` → true
   - `[1, 'a'] is List<int>` → false (mixed types!)
   - `{'a': 1} is Map<String, int>` → true

3. **No string manipulation** - We removed the broken `_getActualType` and `_isValidType` methods

This makes our parser simple, reliable, and type-safe!

### Important Note: JSON Decoding Lists

There's one caveat with Dart's JSON decoding and generic lists:

```dart
// When JSON is decoded, lists are List<dynamic> by default
final jsonString = '{"tags": ["dart", "flutter"]}';
final decoded = jsonDecode(jsonString);  // Returns Map<String, dynamic>

// This will fail!
final tags = parser.parse<List<String>>('tags');  // Throws type mismatch!
// Because decoded['tags'] is List<dynamic>, not List<String>

// Solution: Use List<dynamic> or cast
final tags1 = parser.parse<List<dynamic>>('tags');  // Works!
final tags2 = parser.parse<List>('tags');  // Works! (same as List<dynamic>)

// Then cast items when using them
final stringTags = tags1.cast<String>();  // Or map individually
```

This is a Dart limitation with `jsonDecode`, not our parser. In practice, when using with API clients that properly type their responses, this is rarely an issue.

## The Exception Class

```dart
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
```

## Usage Examples

### Simple Model
```dart
class User {
  final int id;
  final String name;
  final String? bio;
  final List<String> tags;

  User.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'User');

    return User(
      id: parser.parse<int>('id'),
      name: parser.parse<String>('name'),
      bio: parser.parse<String?>('bio'),
      tags: parser.parse<List<String>>('tags', fallback: []),
    );
  }
}
```

### Nested Objects
```dart
class Post {
  final int id;
  final String title;
  final User author;
  final DateTime? publishedAt;

  Post.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'Post');

    return Post(
      id: parser.parse<int>('id'),
      title: parser.parse<String>('title'),
      author: User.fromJson(
        parser.parse<Map<String, dynamic>>('author'),
      ),
      publishedAt: _parseDateTime(parser.parse<String?>('publishedAt')),
    );
  }

  static DateTime? _parseDateTime(String? value) {
    return value != null ? DateTime.parse(value) : null;
  }
}
```

### With Fallbacks
```dart
class Profile {
  final String name;
  final String? avatarUrl;
  final int followerCount;
  final List<String> interests;

  Profile.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'Profile');

    return Profile(
      name: parser.parse<String>('name', fallback: 'Unknown'),
      avatarUrl: parser.parse<String?>('avatarUrl'),
      followerCount: parser.parse<int>('followerCount', fallback: 0),
      interests: parser.parse<List<String>>('interests', fallback: []),
    );
  }
}
```

## Production Error Reporting

```dart
void parseUserResponse(Map<String, dynamic> json) {
  try {
    final user = User.fromJson(json);
    // Process user...
  } catch (e) {
    if (e is ParseException) {
      // Send to Crashlytics with full context
      FirebaseCrashlytics.instance.recordError(
        e,
        null,
        fatal: false,
        information: [
          'Field: ${e.field}',
          'Model: ${e.model}',
          'Expected: ${e.expected}',
          'Actual: ${e.actual}',
          if (e.json != null) 'JSON: ${jsonEncode(e.json)}',
        ],
      );
    }
    rethrow;
  }
}
```

## Benefits

- **Single API**: Just one `parse` method to remember
- **No repetition**: Create parser once, use for all fields
- **Clear errors**: Know exactly what failed and why
- **Full context**: See the complete JSON when debugging
- **Type safe**: Uses Dart's type system properly
- **Simple**: Just two classes, easy to understand and maintain

## What We Don't Do

- **No type coercion**: If backend sends wrong types, that's a bug to fix
- **No validation**: Keep parsing separate from business logic
- **No code generation**: Pure Dart, no build_runner needed

## Installation

Just copy these two classes into your project. That's it.

## License

Internal tool - for company use only.