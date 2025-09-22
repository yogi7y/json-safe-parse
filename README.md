# Safe JSON Serialization

An internal JSON parsing library that provides detailed error messages, partial data recovery, and production-ready error logging.

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

Even worse, if one user in a list has bad data, the entire list fails to parse.

## The Solution

A production-ready parser that:
- **Captures context** when things go wrong
- **Recovers partial data** from lists and maps
- **Logs errors** to your monitoring service
- **Parses custom objects** with a simple API

```dart
class User {
  final int id;
  final String name;
  final String? email;
  final List<String> tags;

  factory User.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'User');

    return User(
      id: parser.parse<int>('id'),
      name: parser.parse<String>('name'),
      email: parser.parse<String?>('email'),
      tags: parser.parseList<String>('tags'),  // Returns [] by default if missing
    );
  }
}
```

When this fails, you get actionable errors:
```
ParseException: Type mismatch for field "id" in User
  Expected: int
  Actual: String: "12345"
  JSON: {"id": "12345", "name": "John", "email": "john@example.com"}
```

## Key Features

### 1. Resilient List & Map Parsing

**Traditional parsing fails completely:**
```dart
// If one user has bad data, you get NO users
final users = (json['users'] as List)
  .map((u) => User.fromJson(u))
  .toList();  // Throws if ANY user is malformed
```

**This parser returns valid items:**
```dart
// Returns valid users, skips and logs bad ones
final users = parser.parseList<User>('users', fromJson: User.fromJson);

// Example: [valid, invalid, valid, valid] → Returns 3 valid users
// Invalid user is logged to Firebase/Sentry for monitoring
```

### 2. Production-Ready Error Logging

```dart
// Configure once at app startup
JsonParser.setDefaultLogger(FirebaseErrorLogger());

// Now all parse errors are automatically logged
final users = parser.parseList<User>('users', fromJson: User.fromJson);
// Bad items logged with full context: field, index, expected type, actual value
```

### 3. Clean API for Custom Objects

```dart
// Primitives - no change
final tags = parser.parseList<String>('tags');
final scores = parser.parseList<int>('scores');

// Custom objects - just add fromJson
final users = parser.parseList<User>('users', fromJson: User.fromJson);
final userMap = parser.parseMap<User>('userMap', fromJson: User.fromJson);
```

## Real-World Example

```dart
// API returns list of products
final json = {
  'products': [
    {'id': 1, 'name': 'iPhone', 'price': 999.99},     // Valid ✓
    {'id': '2', 'name': 'iPad', 'price': 799.99},     // Invalid id type ✗
    'not even a product',                              // Wrong type ✗
    {'id': 3, 'name': 'MacBook'},                     // Missing price ✗
    {'id': 4, 'name': 'AirPods', 'price': 199.99},    // Valid ✓
    null,                                              // Null item ✗
  ]
};

class Product {
  final int id;
  final String name;
  final double price;

  factory Product.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'Product');
    return Product(
      id: parser.parse<int>('id'),
      name: parser.parse<String>('name'),
      price: parser.parse<double>('price'),
    );
  }
}

// Parse products
final parser = JsonParser(json, 'ProductListResponse');
final products = parser.parseList<Product>('products', fromJson: Product.fromJson);

// Result: Returns 2 valid products (iPhone, AirPods)
// The 4 invalid items are skipped and logged to your error tracking service
// Your UI can display the valid products instead of crashing!
```

## Parsing Scenarios

### Basic Types
```dart
// Non-nullable (throws if missing/null)
parser.parse<int>('age')

// Nullable (returns null if missing)
parser.parse<String?>('bio')

// With fallback (uses fallback if missing/null)
parser.parse<String>('name', fallback: 'Anonymous')
```

### Lists
```dart
// Primitive lists with automatic item validation
parser.parseList<String>('tags')           // Skips non-strings
parser.parseList<int>('scores')            // Skips non-integers

// Custom object lists
parser.parseList<User>('users', fromJson: User.fromJson)

// With custom fallback
parser.parseList<String>('tags', fallback: ['default', 'tags'])
```

### Maps
```dart
// Primitive maps
parser.parseMap<int>('scores')            // Map<String, int>
parser.parseMap<String>('config')         // Map<String, String>

// Custom object maps
parser.parseMap<User>('userById', fromJson: User.fromJson)

// Automatic int to double conversion
parser.parseMap<double>('prices')         // Accepts both int and double values
```

### Nested Objects
```dart
class User {
  final int id;
  final String name;
  final Address? address;
  final List<Post> posts;

  factory User.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'User');

    // Nested object
    final addressJson = parser.parse<Map<String, dynamic>?>('address');

    return User(
      id: parser.parse<int>('id'),
      name: parser.parse<String>('name'),
      address: addressJson != null ? Address.fromJson(addressJson) : null,
      posts: parser.parseList<Post>('posts', fromJson: Post.fromJson),
    );
  }
}
```

## Error Messages

When parsing fails, you get detailed context:

```dart
// Single value error
ParseException: Type mismatch for field "age" in User
  Expected: int
  Actual: String: "thirty"
  JSON: {"id": 1, "name": "John", "age": "thirty"}

// Missing required field
ParseException: Missing required field "email" in User
  JSON: {"id": 1, "name": "John"}

// List item error (logged, not thrown)
{
  "error": "Object parsing failed",
  "field": "users",
  "model": "UserListResponse",
  "index": 2,
  "expected": "User",
  "exception": "ParseException: Missing required field 'id'"
}
```

## Implementation Details

### Fallback Behavior

```dart
// Fallback applies ONLY to missing/null values
parser.parse<int>('count', fallback: 0)

// Type mismatches still throw (this is intentional!)
// json = {'count': 'invalid'}
parser.parse<int>('count', fallback: 0)  // Throws ParseException
```

## Complete Example

```dart
import 'package:your_app/json_parser.dart';

// Define your error logger
class AppErrorLogger extends ErrorLogger {
  @override
  void logError(Object? error) {
    // Send to your monitoring service
    print('Parse error: $error');
  }
}

// Configure at startup
void main() {
  JsonParser.setDefaultLogger(AppErrorLogger());
  runApp(MyApp());
}

// Use in your models
class User {
  final int id;
  final String name;
  final String? email;
  final List<String> tags;
  final Map<String, int> scores;

  factory User.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'User');

    return User(
      id: parser.parse<int>('id'),
      name: parser.parse<String>('name'),
      email: parser.parse<String?>('email'),
      tags: parser.parseList<String>('tags'),
      scores: parser.parseMap<int>('scores'),
    );
  }
}

// Parse API responses
Future<List<User>> fetchUsers() async {
  final response = await http.get('/api/users');
  final json = jsonDecode(response.body);

  final parser = JsonParser(json, 'UserListResponse');

  // Returns valid users, logs invalid ones
  return parser.parseList<User>('data', fromJson: User.fromJson);
}