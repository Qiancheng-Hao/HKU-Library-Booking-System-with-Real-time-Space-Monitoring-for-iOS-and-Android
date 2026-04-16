import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/facility.dart';
import 'package:frontend/core/models/library.dart';
import 'package:frontend/core/models/reservation.dart';
import 'package:frontend/core/network/http_api_client.dart';
import 'package:frontend/features/library/data/library_repository.dart';
import 'package:frontend/features/library/data/reservation_repository.dart';
import 'package:frontend/features/reservations/presentation/controllers/reservation_list_controller.dart';

void main() {
  group('ReservationListController', () {
    test('load stores reservations', () async {
      final reservation = _reservation(id: '1');
      final controller = ReservationListController(
        reservationRepository: _FakeReservationRepository(
          reservations: [reservation],
        ),
        libraryRepository: _FakeLibraryRepository(),
      );

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.reservations, [reservation]);
    });

    test('load captures errors and keeps previous reservations', () async {
      final repository = _FakeReservationRepository(
        reservations: [_reservation(id: '1')],
      );
      final controller = ReservationListController(
        reservationRepository: repository,
        libraryRepository: _FakeLibraryRepository(),
      );

      await controller.load();
      repository.error = StateError('offline');
      await controller.load();

      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, contains('offline'));
      expect(controller.reservations.single.id, '1');
    });

    test(
      'loadFacilityMap filters facilities by reservation facility type',
      () async {
        final controller = ReservationListController(
          reservationRepository: _FakeReservationRepository(),
          libraryRepository: _FakeLibraryRepository(
            library: Library(
              id: 2,
              name: 'Main Library',
              campus: 'HKU',
              facilities: [
                _facility(id: 10, type: 'Study Room'),
                _facility(id: 11, type: 'Study Table'),
                _facility(id: 12, type: 'Study Room'),
              ],
            ),
          ),
        );

        final facilities = await controller.loadFacilityMap(
          _reservation(
            facility: _facility(id: 99, type: 'Study Room', libraryId: 2),
          ),
        );

        expect(facilities.map((f) => f.id), [10, 12]);
      },
    );

    test('loadFacilityMap throws when library id is missing', () async {
      final controller = ReservationListController(
        reservationRepository: _FakeReservationRepository(),
        libraryRepository: _FakeLibraryRepository(),
      );

      expect(
        () => controller.loadFacilityMap(
          _reservation(facility: _facility(id: 1, libraryId: null)),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'cancelReservation cancels reminder and reloads reservations',
      () async {
        final repository = _FakeReservationRepository(
          reservations: [_reservation(id: 'before')],
        );
        String? cancelledReminderId;
        final controller = ReservationListController(
          reservationRepository: repository,
          libraryRepository: _FakeLibraryRepository(),
          cancelReservationReminder: (id) async {
            cancelledReminderId = id;
          },
        );

        await controller.load();
        repository.reservations = [_reservation(id: 'after')];
        await controller.cancelReservation('before');

        expect(repository.cancelledReservationId, 'before');
        expect(cancelledReminderId, 'before');
        expect(controller.reservations.single.id, 'after');
      },
    );
  });
}

Reservation _reservation({String id = '1', Facility? facility}) {
  return Reservation.fromJson({
    'id': id,
    'reservation_date': '2026-04-16',
    'start_time': '09:00:00',
    'end_time': '10:00:00',
    'status': 'confirmed',
    if (facility != null)
      'facility': {
        'id': facility.id,
        'name': facility.name,
        'type': facility.type,
        if (facility.libraryId != null) 'library_id': facility.libraryId,
      },
  });
}

Facility _facility({
  required int id,
  String type = 'Study Room',
  int? libraryId = 2,
}) {
  return Facility(
    id: id,
    name: 'Facility $id',
    type: type,
    libraryId: libraryId,
    floor: 1,
    xCoordinate: 0,
    yCoordinate: 0,
    width: 0,
    height: 0,
  );
}

class _FakeReservationRepository extends ReservationRepository {
  _FakeReservationRepository({this.reservations = const []})
    : super(HttpApiClient());

  List<Reservation> reservations;
  Object? error;
  String? cancelledReservationId;

  @override
  Future<List<Reservation>> getUserReservations() async {
    final currentError = error;
    if (currentError != null) throw currentError;
    return reservations;
  }

  @override
  Future<void> cancelReservation(String reservationId) async {
    cancelledReservationId = reservationId;
  }
}

class _FakeLibraryRepository extends LibraryRepository {
  _FakeLibraryRepository({
    this.library = const Library(id: 1, name: 'Library', campus: 'HKU'),
  }) : super(HttpApiClient());

  final Library library;

  @override
  Future<Library> getLibraryDetails(int id) async => library;
}
