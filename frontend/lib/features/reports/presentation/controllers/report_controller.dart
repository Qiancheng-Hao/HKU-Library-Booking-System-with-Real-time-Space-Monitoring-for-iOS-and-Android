import 'dart:async';

import '../../../../core/models/library.dart';
import '../../../../core/models/report.dart';
import '../../../../core/network/http_api_client.dart';
import '../../../../core/presentation/base_async_controller.dart';
import '../../../library/data/library_repository.dart';
import '../../data/report_repository.dart';

class ReportController extends BaseAsyncController {
  static const int reportSummaryDays = 30;
  static const Duration trendDebounceDuration = Duration(milliseconds: 250);

  final ReportRepository _reportRepository;
  final LibraryRepository _libraryRepository;

  ReportController({
    required ReportRepository reportRepository,
    required LibraryRepository libraryRepository,
  }) : _reportRepository = reportRepository,
       _libraryRepository = libraryRepository;

  List<Library> _libraries = [];
  String? _selectedLocation;
  int _trendDays = 7;
  ReportDashboard? _dashboard;
  Timer? _trendDebounce;
  bool _isTrendLoading = false;
  String? _trendErrorMessage;
  int _trendRequestId = 0;

  List<Library> get libraries => _libraries;
  String? get selectedLocation => _selectedLocation;
  int get trendDays => _trendDays;
  ReportDashboard? get dashboard => _dashboard;
  bool get isTrendLoading => _isTrendLoading;
  String? get trendErrorMessage => _trendErrorMessage;
  bool get hasTrendError => _trendErrorMessage != null;

  Future<void> initialize() async {
    await runGuarded(() async {
      _libraries = await _libraryRepository.getLibraries();
      if (_selectedLocation == null && _libraries.isNotEmpty) {
        _selectedLocation = _libraries.first.name;
      }
      if (_selectedLocation != null) {
        _dashboard = await _loadDashboard();
      }
    });
  }

  Future<void> refresh() async {
    if (_selectedLocation == null) {
      return initialize();
    }
    await runGuarded(() async {
      _dashboard = await _loadDashboard();
    });
  }

  Future<void> selectLocation(String location) async {
    if (_selectedLocation == location) return;
    _selectedLocation = location;
    notifyListeners();
    await refresh();
  }

  Future<void> selectTrendDays(int days) async {
    final normalized = switch (days) {
      1 => 1,
      7 => 7,
      30 => 30,
      _ => 7,
    };
    if (_trendDays == normalized) return;
    _trendDays = normalized;
    _trendErrorMessage = null;
    _trendDebounce?.cancel();
    notifyListeners();
    _trendDebounce = Timer(trendDebounceDuration, () {
      unawaited(_refreshTrendOnly());
    });
  }

  Future<ReportDashboard> _loadDashboard() async {
    final location = _selectedLocation;
    final results = await Future.wait<Object>([
      _reportRepository.getSummary(location: location, days: reportSummaryDays),
      _reportRepository.getTrend(
        location: location,
        days: _trendDays,
        bucket: _trendBucket,
      ),
      _reportRepository.getHeatmap(location: location, days: reportSummaryDays),
      _reportRepository.getPeakHours(
        location: location,
        days: reportSummaryDays,
      ),
    ]);
    return ReportDashboard(
      summary: results[0] as ReportSummary,
      trend: results[1] as ReportTrend,
      heatmap: results[2] as ReportHeatmap,
      peakHours: results[3] as ReportPeakHours,
    );
  }

  Future<void> _refreshTrendOnly() async {
    if (_selectedLocation == null || _dashboard == null) {
      await refresh();
      return;
    }
    final requestId = ++_trendRequestId;
    _setTrendLoading(true);
    try {
      final trend = await _reportRepository.getTrend(
        location: _selectedLocation,
        days: _trendDays,
        bucket: _trendBucket,
      );
      if (requestId != _trendRequestId) return;
      final current = _dashboard!;
      _dashboard = ReportDashboard(
        summary: current.summary,
        trend: trend,
        heatmap: current.heatmap,
        peakHours: current.peakHours,
      );
      _trendErrorMessage = null;
    } catch (e) {
      if (requestId != _trendRequestId) return;
      _trendErrorMessage = e is ApiException ? e.message : e.toString();
    } finally {
      if (requestId == _trendRequestId) {
        _setTrendLoading(false);
      }
    }
  }

  String get _trendBucket => _trendDays == 1 ? 'hour' : 'day';

  void _setTrendLoading(bool value) {
    if (_isTrendLoading == value) return;
    _isTrendLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _trendDebounce?.cancel();
    super.dispose();
  }
}
