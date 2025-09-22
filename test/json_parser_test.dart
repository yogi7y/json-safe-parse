// ignore_for_file: unnecessary_type_check

import 'package:test/test.dart';
import 'package:serialization/serialization.dart';

class TestErrorLogger extends ErrorLogger {
  final errors = <Object?>[];

  @override
  void logError(Object? error) {
    errors.add(error);
  }

  void clear() => errors.clear();
}

void main() {
  group('Basic Type Parsing', () {
    test('parses primitive types correctly', () {
      final json = {
        'name': 'John',
        'age': 30,
        'score': 95.5,
        'active': true,
      };
      final parser = JsonParser(json, 'Test');

      expect(parser.parse<String>('name'), equals('John'));
      expect(parser.parse<int>('age'), equals(30));
      expect(parser.parse<double>('score'), equals(95.5));
      expect(parser.parse<bool>('active'), isTrue);
    });

    test('handles nullable fields', () {
      final json = {'name': 'John', 'bio': null};
      final parser = JsonParser(json, 'Test');

      expect(parser.parse<String?>('bio'), isNull);
      expect(parser.parse<String?>('missing'), isNull);
      expect(parser.parse<String?>('name'), equals('John'));
    });

    test('uses fallback values only for missing fields, not type mismatches', () {
      final json = {'count': 'invalid'};
      final parser = JsonParser(json, 'Test');

      // Fallback works for missing fields
      expect(parser.parse<String>('missing', fallback: 'default'), equals('default'));

      // But type mismatch should throw even with fallback
      expect(
        () => parser.parse<int>('count', fallback: 0),
        throwsA(isA<ParseException>()),
      );

      // Nullable types still work for missing fields
      expect(parser.parse<int?>('missing'), isNull);
    });

    test('distinguishes empty values from null', () {
      final json = {
        'empty': '',
        'zero': 0,
        'false': false,
      };
      final parser = JsonParser(json, 'Test');

      expect(parser.parse<String>('empty'), equals(''));
      expect(parser.parse<int>('zero'), equals(0));
      expect(parser.parse<bool>('false'), isFalse);
    });
  });

  group('List Parsing', () {
    test('parses typed lists', () {
      final json = {
        'tags': ['dart', 'flutter'],
        'scores': [90, 85, 88],
        'empty': [],
      };
      final parser = JsonParser(json, 'Test');

      final tags = parser.parseList<String>('tags');
      expect(tags, isA<List<String>>());
      expect(tags, equals(['dart', 'flutter']));

      final scores = parser.parseList<int>('scores');
      expect(scores, equals([90, 85, 88]));

      final empty = parser.parseList<String>('empty');
      expect(empty, isEmpty);
    });

    test('handles lists with nullable items', () {
      final json = {
        'items': ['a', null, 'b'],
        'numbers': [1, null, 3, null],
      };
      final parser = JsonParser(json, 'Test');

      final items = parser.parseList<String?>('items');
      expect(items, equals(['a', null, 'b']));
      expect(items[1], isNull);

      final numbers = parser.parseList<int?>('numbers');
      expect(numbers, equals([1, null, 3, null]));
    });

    test('handles nullable lists vs lists with nullable items', () {
      final json = {
        'present': ['a', 'b'],
        'missing': null,
      };
      final parser = JsonParser(json, 'Test');

      // Now returns default empty list for missing field
      expect(parser.parseList<String>('missing'), equals([]));

      // Can use custom fallback
      final fallbackList = <String>['default'];
      expect(parser.parseList<String>('missing', fallback: fallbackList), equals(fallbackList));

      // List with nullable items can't be null but items can
      final items = parser.parseList<String?>('present');
      expect(items, equals(['a', 'b']));
    });

    test('handles mixed numeric types in lists', () {
      final json = {
        'mixed': [1, 2.5, 3], // Mix of int and double
      };
      final parser = JsonParser(json, 'Test');

      // Now skips invalid items instead of throwing
      final ints = parser.parseList<int>('mixed');
      expect(ints, equals([1, 3])); // 2.5 is skipped

      // Should work for List<num>
      final nums = parser.parseList<num>('mixed');
      expect(nums, equals([1, 2.5, 3]));
    });

    test('skips invalid items in lists', () {
      final json = {
        'mixed': ['hello', 123, true, 'world'],
      };
      final parser = JsonParser(json, 'Test');

      // Now returns valid items, skipping invalid ones
      final strings = parser.parseList<String>('mixed');
      expect(strings, equals(['hello', 'world'])); // 123 and true are skipped
    });
  });

  group('Map Parsing', () {
    test('parses typed maps', () {
      final json = {
        'stats': {'views': 100, 'likes': 50},
        'config': {'theme': 'dark', 'lang': 'en'},
        'empty': {},
      };
      final parser = JsonParser(json, 'Test');

      final stats = parser.parseMap<int>('stats');
      expect(stats, isA<Map<String, int>>());
      expect(stats['views'], equals(100));

      final config = parser.parseMap<String>('config');
      expect(config['theme'], equals('dark'));

      final empty = parser.parseMap<String>('empty');
      expect(empty, isEmpty);
    });

    test('handles maps with nullable values', () {
      final json = {
        'settings': {
          'theme': 'dark',
          'backup': null,
          'timeout': 30,
        },
      };
      final parser = JsonParser(json, 'Test');

      // Now skips null value if type doesn't allow it
      final stringSettings = parser.parseMap<String>('settings');
      expect(stringSettings['theme'], equals('dark'));
      expect(stringSettings.containsKey('backup'), isFalse); // null skipped
      expect(stringSettings.containsKey('timeout'), isFalse); // int skipped

      // But this should work with dynamic values
      final settings = parser.parseMap<dynamic>('settings');
      expect(settings['theme'], equals('dark'));
      expect(settings['backup'], isNull);
      expect(settings['timeout'], equals(30));
    });

    test('handles int to double conversion in maps', () {
      final json = {
        'scores': {'math': 95, 'english': 88.5}, // Mixed int and double
      };
      final parser = JsonParser(json, 'Test');

      // Should auto-convert int to double
      final scores = parser.parseMap<double>('scores');
      expect(scores['math'], equals(95.0));
      expect(scores['english'], equals(88.5));
    });

    test('skips invalid values in maps', () {
      final json = {
        'scores': {
          'math': '95.5',
          'english': 88.0,
          'science': 92.5,
        },
      };
      final parser = JsonParser(json, 'Test');

      // Now skips invalid values instead of throwing
      final scores = parser.parseMap<double>('scores');
      expect(scores['math'], isNull); // '95.5' string is skipped
      expect(scores['english'], equals(88.0)); // int auto-converted to double
      expect(scores['science'], equals(92.5));
    });
  });

  group('Nested Structures', () {
    test('parses nested models', () {
      final json = {
        'id': 123,
        'name': 'John Doe',
        'bio': 'Developer',
        'address': {
          'street': '123 Main St',
          'city': 'Boston',
          'metadata': {
            'building': 'A',
            'floor': '5',
          },
        },
        'tags': ['flutter', 'dart'],
        'scores': {
          'math': 95.5,
          'english': 88.0,
        },
      };

      final user = User.fromJson(json);

      expect(user.id, equals(123));
      expect(user.name, equals('John Doe'));
      expect(user.bio, equals('Developer'));
      expect(user.address.street, equals('123 Main St'));
      expect(user.address.city, equals('Boston'));
      expect(user.address.metadata?['building'], equals('A'));
      expect(user.tags, equals(['flutter', 'dart']));
      expect(user.scores['math'], equals(95.5));
    });

    test('handles list of maps', () {
      final json = {
        'items': [
          {'id': 1, 'name': 'Item 1'},
          {'id': 2, 'name': 'Item 2'},
        ],
      };
      final parser = JsonParser(json, 'Test');

      final items = parser.parseList<Map<String, dynamic>>('items');
      expect(items.length, equals(2));
      expect(items[0]['id'], equals(1));
      expect(items[1]['name'], equals('Item 2'));
    });

    test('handles map of lists', () {
      final json = {
        'groups': {
          'admin': ['user1', 'user2'],
          'guest': ['user3'],
          'empty': [],
        },
      };
      final parser = JsonParser(json, 'Test');

      // Can't directly parse as Map<String, List<String>>
      // Need to parse as Map<String, dynamic> and handle lists manually
      final groups = parser.parseMap<dynamic>('groups');
      expect(groups['admin'], equals(['user1', 'user2']));
      expect(groups['guest'], equals(['user3']));
      expect(groups['empty'], isEmpty);
    });

    test('handles deeply nested structures', () {
      final json = {
        'level1': {
          'level2': {
            'level3': {
              'value': 'deep',
              'items': [1, 2, 3],
            },
          },
        },
      };
      final parser = JsonParser(json, 'Test');

      final level1 = parser.parse<Map<String, dynamic>>('level1');
      final level2 = level1['level2'] as Map<String, dynamic>;
      final level3 = level2['level3'] as Map<String, dynamic>;
      expect(level3['value'], equals('deep'));
      expect(level3['items'], equals([1, 2, 3]));
    });
  });

  group('Error Handling', () {
    test('provides detailed context for type errors', () {
      final json = {'age': '30'};
      final parser = JsonParser(json, 'User');

      expect(
        () => parser.parse<int>('age'),
        throwsA(
          isA<ParseException>()
              .having((e) => e.field, 'field', 'age')
              .having((e) => e.model, 'model', 'User')
              .having((e) => e.expected, 'expected', 'int')
              .having((e) => e.actual, 'actual', contains('String')),
        ),
      );
    });

    test('provides detailed context for missing fields', () {
      final json = <String, dynamic>{};
      final parser = JsonParser(json, 'User');

      expect(
        () => parser.parse<String>('email'),
        throwsA(
          isA<ParseException>()
              .having((e) => e.message, 'message', contains('Missing required field'))
              .having((e) => e.field, 'field', 'email')
              .having((e) => e.model, 'model', 'User'),
        ),
      );
    });

    test('throws on type mismatches for single values, but not lists', () {
      final json = {
        'count': 'not a number',
        'valid': 42,
        'list': 'not a list',
        'items': [1, 'two', 3],
      };
      final parser = JsonParser(json, 'Test');

      // Single value type mismatch should throw even with fallback
      expect(
        () => parser.parse<int>('count', fallback: 0),
        throwsA(isA<ParseException>()),
      );

      // Fallback not used when type matches
      expect(parser.parse<int>('valid', fallback: 0), equals(42));

      // Non-list value should throw
      expect(
        () => parser.parseList<String>('list'),
        throwsA(isA<ParseException>()),
      );

      // List with mixed types returns valid items only
      final nums = parser.parseList<int>('items');
      expect(nums, equals([1, 3])); // 'two' is skipped
    });
  });

  group('Error Logging', () {
    late TestErrorLogger logger;

    setUp(() {
      logger = TestErrorLogger();
      JsonParser.setDefaultLogger(logger);
    });

    test('logs errors for invalid list items', () {
      final json = {
        'items': ['valid', 123, true, 'another'],
      };
      final parser = JsonParser(json, 'Test');

      final items = parser.parseList<String>('items');
      expect(items, equals(['valid', 'another']));

      // Check that errors were logged
      expect(logger.errors.length, equals(2));

      // Check first error (123)
      final error1 = logger.errors[0] as Map;
      expect(error1['index'], equals(1));
      expect(error1['actual'], equals(123));

      // Check second error (true)
      final error2 = logger.errors[1] as Map;
      expect(error2['index'], equals(2));
      expect(error2['actual'], equals(true));
    });

    test('logs errors for invalid map values', () {
      final json = {
        'config': {
          'timeout': 30,
          'enabled': 'yes',
          'retry': true,
          'maxAttempts': null,
        },
      };
      final parser = JsonParser(json, 'Test');

      final config = parser.parseMap<int>('config');
      expect(config.length, equals(1)); // Only 'timeout' is valid
      expect(config['timeout'], equals(30));

      // Check that errors were logged for all non-int values
      expect(logger.errors.length, equals(3));

      // Find error for 'enabled'
      final enabledError = logger.errors.firstWhere(
        (e) => (e as Map)['key'] == 'enabled',
      ) as Map;
      expect(enabledError['error'], equals('Type mismatch in map'));
      expect(enabledError['field'], equals('config'));
      expect(enabledError['model'], equals('Test'));
      expect(enabledError['expected'], equals('int'));
      expect(enabledError['actual'], equals('yes'));

      // Find error for 'retry'
      final retryError = logger.errors.firstWhere(
        (e) => (e as Map)['key'] == 'retry',
      ) as Map;
      expect(retryError['actual'], equals(true));

      // Find error for 'maxAttempts'
      final maxAttemptsError = logger.errors.firstWhere(
        (e) => (e as Map)['key'] == 'maxAttempts',
      ) as Map;
      expect(maxAttemptsError['actual'], isNull);
    });

    test('no errors logged when all items valid', () {
      final json = {
        'numbers': [1, 2, 3],
        'config': {'a': 1, 'b': 2},
      };
      final parser = JsonParser(json, 'Test');

      logger.clear();
      parser.parseList<int>('numbers');
      parser.parseMap<int>('config');

      expect(logger.errors, isEmpty);
    });
  });

  group('Custom Object Parsing', () {
    test('parses list of custom objects with fromJson', () {
      final json = {
        'users': [
          {'id': 1, 'name': 'Alice', 'age': 30},
          {'id': 2, 'name': 'Bob', 'age': 25},
          {'id': 3, 'name': 'Charlie', 'age': 35},
        ],
      };
      final parser = JsonParser(json, 'UserListResponse');

      final users = parser.parseList<SimpleUser>('users', fromJson: SimpleUser.fromJson);

      expect(users.length, equals(3));
      expect(users[0], equals(SimpleUser(id: 1, name: 'Alice', age: 30)));
      expect(users[1], equals(SimpleUser(id: 2, name: 'Bob', age: 25)));
      expect(users[2], equals(SimpleUser(id: 3, name: 'Charlie', age: 35)));
    });

    test('skips invalid objects in list', () {
      final json = {
        'users': [
          {'id': 1, 'name': 'Alice', 'age': 30}, // Valid
          {'id': 'invalid', 'name': 'Bob', 'age': 25}, // Invalid id type
          'not even a map', // Completely wrong type
          {'id': 2, 'name': 'Charlie'}, // Missing age field
          {'id': 3, 'name': 'David', 'age': 40}, // Valid
          null, // Null value
        ],
      };
      final parser = JsonParser(json, 'UserListResponse');

      // Set up logger to verify errors
      final logger = TestErrorLogger();
      JsonParser.setDefaultLogger(logger);

      final users = parser.parseList<SimpleUser>('users', fromJson: SimpleUser.fromJson);

      // Should only get Alice and David
      expect(users.length, equals(2));
      expect(users[0], equals(SimpleUser(id: 1, name: 'Alice', age: 30)));
      expect(users[1], equals(SimpleUser(id: 3, name: 'David', age: 40)));

      // Check that errors were logged
      expect(logger.errors.length, greaterThan(0));
    });

    test('parses empty list with fromJson', () {
      final json = {
        'users': [],
      };
      final parser = JsonParser(json, 'UserListResponse');

      final users = parser.parseList<SimpleUser>('users', fromJson: SimpleUser.fromJson);
      expect(users, isEmpty);
    });

    test('uses fallback for missing list with fromJson', () {
      final json = <String, dynamic>{};
      final parser = JsonParser(json, 'UserListResponse');

      final defaultUsers = [
        SimpleUser(id: 0, name: 'Default', age: 0),
      ];

      final users = parser.parseList<SimpleUser>(
        'users',
        fromJson: SimpleUser.fromJson,
        fallback: defaultUsers,
      );

      expect(users, equals(defaultUsers));
    });

    test('parses map of custom objects with fromJson', () {
      final json = {
        'userMap': {
          'alice': {'id': 1, 'name': 'Alice', 'age': 30},
          'bob': {'id': 2, 'name': 'Bob', 'age': 25},
        },
      };
      final parser = JsonParser(json, 'UserMapResponse');

      final userMap = parser.parseMap<SimpleUser>('userMap', fromJson: SimpleUser.fromJson);

      expect(userMap.length, equals(2));
      expect(userMap['alice'], equals(SimpleUser(id: 1, name: 'Alice', age: 30)));
      expect(userMap['bob'], equals(SimpleUser(id: 2, name: 'Bob', age: 25)));
    });

    test('primitive lists still work without fromJson', () {
      final json = {
        'tags': ['dart', 'flutter', 'json'],
        'scores': [90, 85, 88],
      };
      final parser = JsonParser(json, 'Test');

      // Should work exactly as before
      final tags = parser.parseList<String>('tags');
      expect(tags, equals(['dart', 'flutter', 'json']));

      final scores = parser.parseList<int>('scores');
      expect(scores, equals([90, 85, 88]));
    });
  });

  group('Edge Cases', () {
    test('handles very large numbers', () {
      final json = {
        'bigInt': 9223372036854775807, // Max int64
        'bigDouble': 1.7976931348623157e+308, // Near max double
      };
      final parser = JsonParser(json, 'Test');

      expect(parser.parse<int>('bigInt'), equals(9223372036854775807));
      expect(parser.parse<double>('bigDouble'), equals(1.7976931348623157e+308));
    });

    test('ignores extra fields in JSON', () {
      final json = {
        'id': 123,
        'name': 'Test',
        'extra1': 'ignored',
        'extra2': {'nested': 'also ignored'},
      };
      final parser = JsonParser(json, 'Test');

      // Should only parse what we ask for
      expect(parser.parse<int>('id'), equals(123));
      expect(parser.parse<String>('name'), equals('Test'));
      // Extra fields don't cause issues
    });

    test('handles special string values', () {
      final json = {
        'multiline': 'line1\nline2\nline3',
        'tabs': 'col1\tcol2\tcol3',
        'quotes': 'He said "Hello"',
        'backslash': 'path\\to\\file',
      };
      final parser = JsonParser(json, 'Test');

      expect(parser.parse<String>('multiline'), contains('\n'));
      expect(parser.parse<String>('tabs'), contains('\t'));
      expect(parser.parse<String>('quotes'), contains('"'));
      expect(parser.parse<String>('backslash'), contains('\\'));
    });

    test('handles Map<String, dynamic> directly', () {
      final json = {
        'data': {
          'string': 'text',
          'number': 123,
          'bool': true,
          'null': null,
          'list': [1, 2, 3],
          'map': {'nested': 'value'},
        },
      };
      final parser = JsonParser(json, 'Test');

      // Direct parsing as Map<String, dynamic> works without iteration
      final data = parser.parse<Map<String, dynamic>>('data');
      expect(data['string'], equals('text'));
      expect(data['number'], equals(123));
      expect(data['bool'], isTrue);
      expect(data['null'], isNull);
      expect(data['list'], equals([1, 2, 3]));
      expect(data['map'], equals({'nested': 'value'}));
    });
  });
}

// Simple test model for object parsing tests
class SimpleUser {
  final int id;
  final String name;
  final int age;

  SimpleUser({required this.id, required this.name, required this.age});

  factory SimpleUser.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'SimpleUser');
    return SimpleUser(
      id: parser.parse<int>('id'),
      name: parser.parse<String>('name'),
      age: parser.parse<int>('age'),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimpleUser && other.id == id && other.name == name && other.age == age;
  }

  @override
  int get hashCode => Object.hash(id, name, age);
}

// Simple test models
class Address {
  final String street;
  final String city;
  final Map<String, String>? metadata;

  Address({required this.street, required this.city, this.metadata});

  factory Address.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'Address');
    return Address(
      street: parser.parse<String>('street'),
      city: parser.parse<String>('city'),
      metadata: json['metadata'] != null ? parser.parseMap<String>('metadata') : null,
    );
  }
}

class User {
  final int id;
  final String name;
  final String? bio;
  final Address address;
  final List<String> tags;
  final Map<String, double> scores;

  User({
    required this.id,
    required this.name,
    this.bio,
    required this.address,
    required this.tags,
    required this.scores,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'User');
    return User(
      id: parser.parse<int>('id'),
      name: parser.parse<String>('name'),
      bio: parser.parse<String?>('bio'),
      address: Address.fromJson(
        parser.parse<Map<String, dynamic>>('address'),
      ),
      tags: parser.parseList<String>('tags'),
      scores: parser.parseMap<double>('scores'),
    );
  }
}
