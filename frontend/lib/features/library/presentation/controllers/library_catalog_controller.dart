import '../../../../core/models/library.dart';
import '../../../../core/presentation/base_async_controller.dart';
import '../../data/library_repository.dart';

class LibraryCatalogController extends BaseAsyncController {
  final LibraryRepository _libraryRepository;

  LibraryCatalogController({required LibraryRepository libraryRepository})
    : _libraryRepository = libraryRepository;

  List<Library> _libraries = [];

  List<Library> get libraries => _libraries;

  Future<void> initialize() {
    return refresh();
  }

  Future<void> refresh() async {
    await runGuarded(() async {
      _libraries = await _libraryRepository.getLibraries();
    });
  }
}
