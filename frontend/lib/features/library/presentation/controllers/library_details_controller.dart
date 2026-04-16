import '../../../../core/models/library.dart';
import '../../../../core/presentation/base_async_controller.dart';
import '../../data/library_repository.dart';

class LibraryDetailsController extends BaseAsyncController {
  final LibraryRepository _libraryRepository;

  LibraryDetailsController({required LibraryRepository libraryRepository})
    : _libraryRepository = libraryRepository;

  Library? _library;
  int? _loadedLibraryId;

  Library? get library => _library;

  Future<void> load(int libraryId) async {
    if (_loadedLibraryId == libraryId && _library != null) return;
    await runGuarded(() async {
      _library = await _libraryRepository.getLibraryDetails(libraryId);
      _loadedLibraryId = libraryId;
    });
  }

  Future<void> retry(int libraryId) {
    _loadedLibraryId = null;
    return load(libraryId);
  }
}
