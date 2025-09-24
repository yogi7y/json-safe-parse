import 'dart:convert';
import 'dart:math';
import 'package:serialization/serialization.dart';

// Traditional User model with standard JSON parsing
class TraditionalUser {
  final int id;
  final String name;
  final String email;
  final int age;
  final bool isActive;
  final List<String> tags;
  final Map<String, double> scores;
  final String createdAt;

  TraditionalUser({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    required this.isActive,
    required this.tags,
    required this.scores,
    required this.createdAt,
  });

  factory TraditionalUser.fromJson(Map<String, dynamic> json) {
    // Traditional defensive parsing with fallbacks
    final tagsRaw = json['tags'] as List?;
    final scoresRaw = json['scores'] as Map?;

    return TraditionalUser(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      age: json['age'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      tags: tagsRaw != null ? tagsRaw.whereType<String>().toList() : [],
      scores: scoresRaw != null
          ? Map<String, double>.from(
              scoresRaw.map((key, value) => MapEntry(
                    key.toString(),
                    value is num ? value.toDouble() : 0.0,
                  )),
            )
          : {},
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

// Parser-based User model using JsonParser
class ParserUser {
  final int id;
  final String name;
  final String email;
  final int age;
  final bool isActive;
  final List<String> tags;
  final Map<String, double> scores;
  final String createdAt;

  ParserUser({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    required this.isActive,
    required this.tags,
    required this.scores,
    required this.createdAt,
  });

  factory ParserUser.fromJson(Map<String, dynamic> json) {
    final parser = JsonParser(json, 'ParserUser');
    return ParserUser(
      id: parser.parse<int>('id', fallback: 0),
      name: parser.parse<String>('name', fallback: ''),
      email: parser.parse<String>('email', fallback: ''),
      age: parser.parse<int>('age', fallback: 0),
      isActive: parser.parse<bool>('isActive', fallback: false),
      tags: parser.parseList<String>('tags'),
      scores: parser.parseMap<double>('scores'),
      createdAt: parser.parse<String>('createdAt', fallback: ''),
    );
  }
}

// Test data generator
class TestDataGenerator {
  static final _random = Random(42); // Fixed seed for reproducible results
  static final _names = [
    'Alice',
    'Bob',
    'Charlie',
    'Diana',
    'Eve',
    'Frank',
    'Grace',
    'Henry',
    'Ivy',
    'Jack'
  ];
  static final _tags = [
    'flutter',
    'dart',
    'mobile',
    'web',
    'backend',
    'frontend',
    'database',
    'cloud',
    'ai',
    'ml'
  ];

  static Map<String, dynamic> generateValidUser(int id) {
    final name = _names[_random.nextInt(_names.length)];
    return {
      'id': id,
      'name': '$name User$id',
      'email': '${name.toLowerCase()}$id@example.com',
      'age': 20 + _random.nextInt(40),
      'isActive': _random.nextBool(),
      'tags': List.generate(
        _random.nextInt(5) + 1,
        (_) => _tags[_random.nextInt(_tags.length)],
      ),
      'scores': {
        'math': _random.nextDouble() * 100,
        'english': _random.nextDouble() * 100,
        'science': _random.nextDouble() * 100,
      },
      'createdAt': '2024-01-${(_random.nextInt(28) + 1).toString().padLeft(2, '0')}T10:00:00Z',
    };
  }

  static Map<String, dynamic> generateUserWithErrors(int id) {
    final data = generateValidUser(id);

    // Introduce ~5% errors randomly
    final errorType = _random.nextInt(20);

    switch (errorType) {
      case 0:
        // Wrong type for id
        data['id'] = '$id';
        break;
      case 1:
        // Missing name
        data.remove('name');
        break;
      case 2:
        // Wrong type for age
        data['age'] = '${data['age']}';
        break;
      case 3:
        // Invalid tags (mixed types)
        data['tags'] = ['valid', 123, true, 'tag'];
        break;
      case 4:
        // Invalid scores (wrong value types)
        data['scores'] = {
          'math': 'ninety',
          'english': 85.5,
          'science': true,
        };
        break;
      case 5:
        // Missing email
        data.remove('email');
        break;
      case 6:
        // Wrong type for isActive
        data['isActive'] = 'yes';
        break;
      case 7:
        // Null values
        data['tags'] = null;
        data['scores'] = null;
        break;
      case 8:
        // Wrong type for entire scores
        data['scores'] = 'not a map';
        break;
      default:
        // Keep it valid (95% of cases)
        break;
    }

    return data;
  }

  static List<Map<String, dynamic>> generateDataset(int count, {bool withErrors = false}) {
    return List.generate(
      count,
      (i) => withErrors ? generateUserWithErrors(i) : generateValidUser(i),
    );
  }
}

// Performance test runner
class PerformanceTest {
  static void runTest(String label, List<Map<String, dynamic>> dataset) {
    print('\n$label (${dataset.length} items):');
    print('-' * 50);

    // Test traditional parsing
    final traditionalStart = DateTime.now();
    final traditionalUsers = <TraditionalUser>[];
    for (final json in dataset) {
      try {
        traditionalUsers.add(TraditionalUser.fromJson(json));
      } catch (e) {
        // Count failed parses
      }
    }
    final traditionalDuration = DateTime.now().difference(traditionalStart);

    // Test parser-based parsing
    final parserStart = DateTime.now();
    final parserUsers = <ParserUser>[];
    for (final json in dataset) {
      try {
        parserUsers.add(ParserUser.fromJson(json));
      } catch (e) {
        // Count failed parses
      }
    }
    final parserDuration = DateTime.now().difference(parserStart);

    // Calculate results
    final traditionalMs = traditionalDuration.inMicroseconds / 1000.0;
    final parserMs = parserDuration.inMicroseconds / 1000.0;

    print(
        'Traditional parsing: ${traditionalMs.toStringAsFixed(2)} ms (${traditionalUsers.length} successful)');
    print(
        'JsonParser parsing:  ${parserMs.toStringAsFixed(2)} ms (${parserUsers.length} successful)');

    // Memory estimation (rough)
    final jsonSize = json.encode(dataset).length;
    final sizeKb = (jsonSize / 1024).toStringAsFixed(1);
    print('Dataset size:        ~$sizeKb KB');
  }

  static void runBenchmark() {
    print('=' * 60);
    print('JSON Parsing Performance Comparison');
    print('Traditional (json["field"] as Type? ?? default) vs JsonParser');
    print('=' * 60);

    // Warm up
    print('\nWarming up...');
    for (int i = 0; i < 100; i++) {
      final warmupData = TestDataGenerator.generateDataset(10);
      warmupData.forEach(TraditionalUser.fromJson);
      warmupData.forEach(ParserUser.fromJson);
    }

    // Test with clean data
    print('\n### CLEAN DATA (all valid) ###');

    // ~1KB dataset (10 users)
    final small = TestDataGenerator.generateDataset(10, withErrors: false);
    runTest('Small dataset', small);

    // ~10KB dataset (100 users)
    final medium = TestDataGenerator.generateDataset(100, withErrors: false);
    runTest('Medium dataset', medium);

    // ~50KB dataset (500 users)
    final large = TestDataGenerator.generateDataset(500, withErrors: false);
    runTest('Large dataset', large);

    // ~1MB dataset (4000 users)
    final xlarge = TestDataGenerator.generateDataset(4000, withErrors: false);
    runTest('XLarge dataset (1MB)', xlarge);

    // Test with realistic data (10% errors)
    print('\n### REALISTIC DATA (~10% invalid fields) ###');

    // ~1KB dataset with errors
    final smallWithErrors = TestDataGenerator.generateDataset(10, withErrors: true);
    runTest('Small dataset', smallWithErrors);

    // ~10KB dataset with errors
    final mediumWithErrors = TestDataGenerator.generateDataset(100, withErrors: true);
    runTest('Medium dataset', mediumWithErrors);

    // ~50KB dataset with errors
    final largeWithErrors = TestDataGenerator.generateDataset(500, withErrors: true);
    runTest('Large dataset', largeWithErrors);

    // ~1MB dataset with errors
    final xlargeWithErrors = TestDataGenerator.generateDataset(4000, withErrors: true);
    runTest('XLarge dataset (1MB)', xlargeWithErrors);

    print('\n' + '=' * 60);
    print('Performance Test Complete');
    print('=' * 60);
  }
}

void main() {
  PerformanceTest.runBenchmark();
}
