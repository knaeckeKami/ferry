import 'package:ferry_generator2/src/schema/schema.dart';
import 'package:ferry_generator2/src/selection/selection_resolver.dart';
import 'package:ferry_generator2/src/selection/validation.dart';
import 'package:gql/language.dart';
import 'package:test/test.dart';

const _schema = r'''
schema {
  query: Query
}

scalar JSON

type Item {
  id: ID!
}

type Query {
  items(where: JSON): [Item!]!
}
''';

void main() {
  test('custom scalar object literal variables count as used', () {
    _validate(r'''
query Items($id: ID!, $ids: [String!]) {
  items(where: { id: $id, id_in: $ids }) {
    id
  }
}
''');
  });

  test('custom scalar list literal variables count as used', () {
    _validate(r'''
query Items($id: ID!, $ids: [String!]) {
  items(where: [$id, $ids]) {
    id
  }
}
''');
  });

  test('custom scalar nested object and list literal variables count as used',
      () {
    _validate(r'''
query Items($id: ID!, $ids: [String!]) {
  items(where: { nested: [{ id: $id }, { id_in: $ids }] }) {
    id
  }
}
''');
  });

  test('undefined variable inside custom scalar literal fails', () {
    _expectValidationFailure(
      r'''
query Items {
  items(where: { id: $id }) {
    id
  }
}
''',
      'Variable id is used but not defined in operation Items',
    );
  });

  test('unused variable definition still fails with custom scalar literals',
      () {
    _expectValidationFailure(
      r'''
query Items($id: ID!, $unused: ID) {
  items(where: { id: $id }) {
    id
  }
}
''',
      'Variable unused is defined but not used in operation Items',
    );
  });

  test('direct custom scalar variable validates normally', () {
    _validate(r'''
query Items($where: JSON) {
  items(where: $where) {
    id
  }
}
''');
  });

  test('direct custom scalar variable still checks variable type', () {
    _expectValidationFailure(
      r'''
query Items($where: String) {
  items(where: $where) {
    id
  }
}
''',
      'Variable where is not compatible with expected type JSON',
    );
  });
}

void _validate(String source) {
  final schema = SchemaIndex.fromDocuments([parseString(_schema)]);
  final document = parseString(source);
  DocumentValidator(
    schema: schema,
    documentIndex: DocumentIndex(document),
  ).validate(document);
}

void _expectValidationFailure(String source, String message) {
  expect(
    () => _validate(source),
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains(message),
      ),
    ),
  );
}
