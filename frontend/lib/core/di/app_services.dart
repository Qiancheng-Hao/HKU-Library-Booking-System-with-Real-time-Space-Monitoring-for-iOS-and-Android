import '../../features/ai_agent/data/ai_agent_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/home/data/occupancy_repository.dart';
import '../../features/library/data/library_repository.dart';
import '../../features/library/data/reservation_repository.dart';
import '../network/http_api_client.dart';

class AppServices {
  AppServices._();

  static final HttpApiClient apiClient = HttpApiClient();

  static final AuthRepository authRepository = AuthRepository(apiClient);
  static final AiAgentRepository aiAgentRepository = AiAgentRepository(
    apiClient,
  );
  static final LibraryRepository libraryRepository = LibraryRepository(
    apiClient,
  );
  static final ReservationRepository reservationRepository =
      ReservationRepository(apiClient);
  static final OccupancyRepository occupancyRepository = OccupancyRepository(
    apiClient,
  );
}
