@TestOn('vm')

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:ferry_generator2/ferry_generator2.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

const _package = 'ferry_generator2';
const _schemaPath = '$_package|lib/schema.graphql';
const _queryPath = '$_package|lib/items.graphql';
final _varPath = generatedDartAssetIdForInput(
  _package,
  _queryPath,
  '.var.gql.dart',
);

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
  test('builder accepts variables nested in custom scalar literals', () async {
    const document = r'''
query Items($id: ID!, $ids: [String!]!) {
  items(where: { nested: [{ id: $id }, { id_in: $ids }] }) {
    id
  }
}
''';

    final builder = graphqlBuilder(
      BuilderOptions({
        'schema': {
          'file': _schemaPath,
          'add_typenames': false,
        },
      }),
    );

    final result = await testBuilder(
      builder,
      {
        _schemaPath: _schema,
        _queryPath: document,
      },
      rootPackage: _package,
      generateFor: {_queryPath},
    );

    expect(result.succeeded, isTrue, reason: result.errors.join('\n'));

    final sources = extractGeneratedDartSources(result.readerWriter, _package);
    final libraries = await resolveGeneratedLibraries(
      sources,
      {_varPath},
      rootPackage: _package,
    );
    final varsLibrary = libraries[_varPath]!;

    await _expectLibraryNoErrors(varsLibrary);

    final vars = _classByName(varsLibrary, 'GItemsVars');
    _expectNonNullDartType(_fieldType(vars, 'id'), 'String');
    _expectListType(
      _fieldType(vars, 'ids'),
      elementName: 'String',
      elementNullable: false,
      listNullable: false,
    );
  });
}

Future<void> _expectLibraryNoErrors(LibraryElement library) async {
  final sourcePath = library.firstFragment.source.fullName;
  final result = await library.session.getErrors(sourcePath);
  if (result is! ErrorsResult) return;
  final errors = result.diagnostics
      .where(
        (diagnostic) =>
            diagnostic.diagnosticCode.severity == DiagnosticSeverity.ERROR,
      )
      .toList();
  expect(errors, isEmpty, reason: errors.join('\n'));
}

ClassElement _classByName(LibraryElement library, String name) {
  return library.classes.firstWhere((element) => element.name == name);
}

DartType _fieldType(ClassElement element, String name) {
  final field = element.getField(name);
  if (field == null) {
    throw StateError('Missing field $name on ${element.name}');
  }
  return field.type;
}

void _expectNonNullDartType(DartType type, String name) {
  expect(type.nullabilitySuffix, NullabilitySuffix.none);
  final interfaceType = type as InterfaceType;
  expect(interfaceType.element.name, name);
}

void _expectListType(
  DartType type, {
  required String elementName,
  required bool elementNullable,
  required bool listNullable,
}) {
  final listType = type as InterfaceType;
  expect(listType.element.name, 'List');
  expect(
    listType.nullabilitySuffix,
    listNullable ? NullabilitySuffix.question : NullabilitySuffix.none,
  );

  final elementType = listType.typeArguments.single;
  final elementInterface = elementType as InterfaceType;
  expect(elementInterface.element.name, elementName);
  expect(
    elementType.nullabilitySuffix,
    elementNullable ? NullabilitySuffix.question : NullabilitySuffix.none,
  );
}
