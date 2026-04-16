import '../../../../core/models/facility.dart';
import '../../../../core/models/reservation.dart';
import '../../../../core/presentation/base_async_controller.dart';
import '../../../../services/notification_service.dart';
import '../../../library/data/library_repository.dart';
import '../../../library/data/reservation_repository.dart';

typedef ReservationReminderCanceller =
    Future<void> Function(String reservationId);

/// Controller for the reservation list screen.
///
/// Owns the list of reservations, their loading state, and the data-side
/// effects of map viewing and cancellation. The screen layer stays thin —
/// it renders state, opens dialogs, and forwards user intents.
class ReservationListController extends BaseAsyncController {
  final ReservationRepository _reservationRepository;
  final LibraryRepository _libraryRepository;
  final ReservationReminderCanceller _cancelReservationReminder;

  ReservationListController({
    required ReservationRepository reservationRepository,
    required LibraryRepository libraryRepository,
    ReservationReminderCanceller? cancelReservationReminder,
  }) : _reservationRepository = reservationRepository,
       _libraryRepository = libraryRepository,
       _cancelReservationReminder =
           cancelReservationReminder ??
           NotificationService.cancelReservationReminder;

  List<Reservation> _reservations = [];

  List<Reservation> get reservations => _reservations;

  Future<void> load() async {
    final data = await runGuarded(
      () => _reservationRepository.getUserReservations(),
    );
    if (data != null) {
      _reservations = data;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  /// Fetches the library that owns [reservation] and returns the facilities
  /// matching the reservation's facility type — ready to feed into the map
  /// viewer. Throws if the reservation is missing the required library link.
  Future<List<Facility>> loadFacilityMap(Reservation reservation) async {
    final facility = reservation.facility;
    final libraryId = facility?.libraryId;
    final targetType = facility?.type;

    if (libraryId == null) {
      throw StateError('Library ID missing in reservation details');
    }

    final library = await _libraryRepository.getLibraryDetails(libraryId);
    return library.facilities.where((f) => f.type == targetType).toList();
  }

  Future<void> cancelReservation(String reservationId) async {
    await _reservationRepository.cancelReservation(reservationId);
    await _cancelReservationReminder(reservationId);
    await load();
  }
}
