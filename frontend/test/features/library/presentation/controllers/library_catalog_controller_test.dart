import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/library.dart';
import 'package:frontend/core/network/http_api_client.dart';
import 'package:frontend/features/library/data/library_repository.dart';
import 'package:frontend/features/library/presentation/controllers/library_catalog_controller.dart';

void main() {
  group('LibraryCatalogController', () {
    test('loads libraries and exposes loading state', () async {
      final completer = Completer<List<Library>>();
      final repository = _FakeLibraryRepository(librariesCompleter: completer);
      final controller = LibraryCatalogController(
        libraryRepository: repository,
      );

      final load = controller.initialize();

      expect(controller.isLoading, isTrue);
      expect(controller.libraries, isEmpty);

      completer.complete(const [
        Library(id: 1, name: 'Main Library', campus: 'HKU'),
      ]);
      await load;

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.libraries.single.name, 'Main Library');
    });

    test('captures errors and keeps previous libraries', () async {
      final repository = _FakeLibraryRepository(
        libraries: const [Library(id: 1, name: 'Main Library', campus: 'HKU')],
      );
      final controller = LibraryCatalogController(
        libraryRepository: repository,
      );

      await controller.refresh();
      repository.error = StateError('offline');

      await controller.refresh();

      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, contains('offline'));
      expect(controller.libraries.single.name, 'Main Library');
    });
  });
}

class _FakeLibraryRepository extends LibraryRepository {
  _FakeLibraryRepository({this.libraries = const [], this.librariesCompleter})
    : super(HttpApiClient());

  List<Library> libraries;
  Completer<List<Library>>? librariesCompleter;
  Object? error;

  @override
  Future<List<Library>> getLibraries() async {
    final currentError = error;
    if (currentError != null) throw currentError;
    final completer = librariesCompleter;
    if (completer != null) return completer.future;
    return libraries;
  }
}
