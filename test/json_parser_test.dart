// ignore_for_file: unnecessary_type_check

import 'package:test/test.dart';
import 'package:serialization/serialization.dart';

void main() {
  group('JsonParser Core', () {
    test('parse basic types (String, int, double, bool)', () {
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

    test('parse nullable types', () {
      final json = {'name': 'John', 'bio': null};
      final parser = JsonParser(json, 'Test');

      expect(parser.parse<String?>('bio'), isNull);
      expect(parser.parse<String?>('missing'), isNull);
      expect(parser.parse<String?>('name'), equals('John'));
    });

    test('use fallback values', () {
      final json = {'count': 'invalid'};
      final parser = JsonParser(json, 'Test');

      expect(parser.parse<String>('missing', fallback: 'default'), equals('default'));
      expect(parser.parse<int>('count', fallback: 0), equals(0));
    });

    test('parseList for typed lists', () {
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

    test('parseMap for typed maps', () {
      final json = {
        'stats': {'views': 100, 'likes': 50},
        'config': {'theme': 'dark', 'lang': 'en'},
      };
      final parser = JsonParser(json, 'Test');

      final stats = parser.parseMap<int>('stats');
      expect(stats, isA<Map<String, int>>());
      expect(stats['views'], equals(100));

      final config = parser.parseMap<String>('config');
      expect(config['theme'], equals('dark'));
    });

    test('throw ParseException with context for errors', () {
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

      expect(
        () => parser.parse<String>('email'),
        throwsA(
          isA<ParseException>()
              .having((e) => e.message, 'message', contains('Missing required field')),
        ),
      );
    });

    test('parse nested models', () {
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

    test('handle edge cases', () {
      final json = {
        'empty': '',
        'zero': 0,
        'false': false,
        'emptyList': [],
        'emptyMap': {},
      };
      final parser = JsonParser(json, 'Test');

      // Empty values are valid, not null
      expect(parser.parse<String>('empty'), equals(''));
      expect(parser.parse<int>('zero'), equals(0));
      expect(parser.parse<bool>('false'), isFalse);
      expect(parser.parse<List>('emptyList'), isEmpty);
      expect(parser.parse<Map>('emptyMap'), isEmpty);
    });

    test('parseList validates item types', () {
      final json = {
        'mixed': ['hello', 123, true],
      };
      final parser = JsonParser(json, 'Test');

      expect(
        () => parser.parseList<String>('mixed'),
        throwsA(
          isA<ParseException>().having((e) => e.message, 'message', contains('at index 1')),
        ),
      );
    });

    test('parseMap validates value types', () {
      final json = {
        'scores': {
          'math': '95.5',
          'english': 88.0,
        },
      };
      final parser = JsonParser(json, 'Test');

      expect(
        () => parser.parseMap<double>('scores'),
        throwsA(
          isA<ParseException>()
              .having((e) => e.message, 'message', contains('Type mismatch in map')),
        ),
      );
    });
  });
}

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
