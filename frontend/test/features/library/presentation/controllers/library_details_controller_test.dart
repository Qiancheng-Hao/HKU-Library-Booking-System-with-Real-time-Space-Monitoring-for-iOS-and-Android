import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/library.dart';
import 'package:frontend/core/network/http_api_client.dart';
import 'package:frontend/features/library/data/library_repository.dart';
import 'package:frontend/features/library/presentation/controllers/library_details_controller.dart';

void main() {
  group('LibraryDetailsController', () {
    test('load fetches details once for the same library id', () async {
      final repository = _FakeLibraryRepository();
      final controller = LibraryDetailsController(
        libraryRepository: repository,
      );

      await controller.load(1);
      await controller.load(1);

      expect(controller.library?.id, 1);
      expect(repository.loadCount, 1);
      expect(controller.hasError, isFalse);
    });

    test('load can force refresh for the same library id', () async {
      final repository = _FakeLibraryRepository();
      final controller = LibraryDetailsController(
        libraryRepository: repository,
      );

      await controller.load(1);
      await controller.load(1, forceRefresh: true);

      expect(controller.library?.id, 1);
      expect(repository.loadCount, 2);
      expect(controller.hasError, isFalse);
    });

    test('retry forces a new load after failure', () async {
      final repository = _FakeLibraryRepository();
      final controller = LibraryDetailsController(
        libraryRepository: repository,
      );

      repository.error = StateError('offline');
      await controller.load(1);

      expect(controller.hasError, isTrue);
      expect(controller.library, isNull);

      repository.error = null;
      await controller.retry(1);

      expect(controller.hasError, isFalse);
      expect(controller.library?.name, 'Library 1');
      expect(repository.loadCount, 2);
    });
  });
}

class _FakeLibraryRepository extends LibraryRepository {
  _FakeLibraryRepository() : super(HttpApiClient());

  Object? error;
  var loadCount = 0;

  @override
  Future<Library> getLibraryDetails(int id) async {
    loadCount += 1;
    final currentError = error;
    if (currentError != null) throw currentError;
    return Library(id: id, name: 'Library $id', campus: 'HKU');
  }
}
