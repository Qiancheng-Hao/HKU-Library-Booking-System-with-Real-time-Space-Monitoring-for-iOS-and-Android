import 'json_helpers.dart';

DateTime? _readDateTime(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = value.toString();
  final displayTime = text.replaceFirst(RegExp(r'(Z|[+-]\d{2}:?\d{2})$'), '');
  return DateTime.tryParse(displayTime) ?? DateTime.tryParse(text);
}

class ReportScope {
  final String? location;
  final String? area;
  final int days;
  final DateTime? generatedAt;
  final DateTime? since;
  final DateTime? until;

  const ReportScope({
    this.location,
    this.area,
    required this.days,
    this.generatedAt,
    this.since,
    this.until,
  });

  factory ReportScope.fromJson(JsonMap json) {
    return ReportScope(
      location: json['location']?.toString(),
      area: json['area']?.toString(),
      days: readInt(json, 'days'),
      generatedAt: _readDateTime(json, 'generatedAt'),
      since: _readDateTime(json, 'since'),
      until: _readDateTime(json, 'until'),
    );
  }
}

class ReportWeekdayInsight {
  final int weekdayIndex;
  final String weekdayName;
  final double averageOccupancyRate;
  final double peakOccupancyRate;
  final int sampleCount;

  const ReportWeekdayInsight({
    required this.weekdayIndex,
    required this.weekdayName,
    required this.averageOccupancyRate,
    required this.peakOccupancyRate,
    required this.sampleCount,
  });

  factory ReportWeekdayInsight.fromJson(JsonMap json) {
    return ReportWeekdayInsight(
      weekdayIndex: readInt(json, 'weekdayIndex'),
      weekdayName: readString(json, 'weekdayName', fallback: 'Unknown'),
      averageOccupancyRate: readDouble(json, 'averageOccupancyRate'),
      peakOccupancyRate: readDouble(json, 'peakOccupancyRate'),
      sampleCount: readInt(json, 'sampleCount'),
    );
  }
}

class ReportHourInsight {
  final int hour;
  final String label;
  final double averageOccupancyRate;
  final double peakOccupancyRate;
  final int sampleCount;

  const ReportHourInsight({
    required this.hour,
    required this.label,
    required this.averageOccupancyRate,
    required this.peakOccupancyRate,
    required this.sampleCount,
  });

  factory ReportHourInsight.fromJson(JsonMap json) {
    return ReportHourInsight(
      hour: readInt(json, 'hour'),
      label: readString(json, 'label'),
      averageOccupancyRate: readDouble(json, 'averageOccupancyRate'),
      peakOccupancyRate: readDouble(json, 'peakOccupancyRate'),
      sampleCount: readInt(json, 'sampleCount'),
    );
  }
}

class ReportSummary {
  final ReportScope scope;
  final bool hasData;
  final double? averageOccupancyRate;
  final double? peakOccupancyRate;
  final int totalSampleCount;
  final int observationCount;
  final DateTime? firstObservedAt;
  final DateTime? lastObservedAt;
  final ReportWeekdayInsight? busiestWeekday;
  final ReportHourInsight? busiestHour;
  final ReportHourInsight? suggestedLowTrafficHour;

  const ReportSummary({
    required this.scope,
    required this.hasData,
    this.averageOccupancyRate,
    this.peakOccupancyRate,
    required this.totalSampleCount,
    required this.observationCount,
    this.firstObservedAt,
    this.lastObservedAt,
    this.busiestWeekday,
    this.busiestHour,
    this.suggestedLowTrafficHour,
  });

  factory ReportSummary.fromJson(JsonMap json) {
    return ReportSummary(
      scope: ReportScope.fromJson(asJsonMap(json['scope'])),
      hasData: readBool(json, 'hasData'),
      averageOccupancyRate: readFirstNullableDouble(json, const [
        'averageOccupancyRate',
      ]),
      peakOccupancyRate: readFirstNullableDouble(json, const [
        'peakOccupancyRate',
      ]),
      totalSampleCount: readInt(json, 'totalSampleCount'),
      observationCount: readInt(json, 'observationCount'),
      firstObservedAt: _readDateTime(json, 'firstObservedAt'),
      lastObservedAt: _readDateTime(json, 'lastObservedAt'),
      busiestWeekday: json['busiestWeekday'] == null
          ? null
          : ReportWeekdayInsight.fromJson(asJsonMap(json['busiestWeekday'])),
      busiestHour: json['busiestHour'] == null
          ? null
          : ReportHourInsight.fromJson(asJsonMap(json['busiestHour'])),
      suggestedLowTrafficHour: json['suggestedLowTrafficHour'] == null
          ? null
          : ReportHourInsight.fromJson(
              asJsonMap(json['suggestedLowTrafficHour']),
            ),
    );
  }
}

class ReportTrendPoint {
  final DateTime? bucketStart;
  final String bucketLabel;
  final double averageOccupancyRate;
  final double peakOccupancyRate;
  final int sampleCount;

  const ReportTrendPoint({
    this.bucketStart,
    required this.bucketLabel,
    required this.averageOccupancyRate,
    required this.peakOccupancyRate,
    required this.sampleCount,
  });

  factory ReportTrendPoint.fromJson(JsonMap json) {
    return ReportTrendPoint(
      bucketStart: _readDateTime(json, 'bucketStart'),
      bucketLabel: readString(json, 'bucketLabel'),
      averageOccupancyRate: readDouble(json, 'averageOccupancyRate'),
      peakOccupancyRate: readDouble(json, 'peakOccupancyRate'),
      sampleCount: readInt(json, 'sampleCount'),
    );
  }
}

class ReportTrend {
  final ReportScope scope;
  final String bucket;
  final List<ReportTrendPoint> points;

  const ReportTrend({
    required this.scope,
    required this.bucket,
    required this.points,
  });

  factory ReportTrend.fromJson(JsonMap json) {
    return ReportTrend(
      scope: ReportScope.fromJson(asJsonMap(json['scope'])),
      bucket: readString(json, 'bucket', fallback: 'hour'),
      points: asJsonMapList(
        json['points'],
      ).map(ReportTrendPoint.fromJson).toList(),
    );
  }
}

class ReportHeatmapCell {
  final int weekdayIndex;
  final String weekdayName;
  final int hour;
  final double averageOccupancyRate;
  final double peakOccupancyRate;
  final int sampleCount;

  const ReportHeatmapCell({
    required this.weekdayIndex,
    required this.weekdayName,
    required this.hour,
    required this.averageOccupancyRate,
    required this.peakOccupancyRate,
    required this.sampleCount,
  });

  factory ReportHeatmapCell.fromJson(JsonMap json) {
    return ReportHeatmapCell(
      weekdayIndex: readInt(json, 'weekdayIndex'),
      weekdayName: readString(json, 'weekdayName', fallback: 'Unknown'),
      hour: readInt(json, 'hour'),
      averageOccupancyRate: readDouble(json, 'averageOccupancyRate'),
      peakOccupancyRate: readDouble(json, 'peakOccupancyRate'),
      sampleCount: readInt(json, 'sampleCount'),
    );
  }

  String get hourLabel => '${hour.toString().padLeft(2, '0')}:00';
}

class ReportHeatmap {
  final ReportScope scope;
  final List<ReportHeatmapCell> cells;

  const ReportHeatmap({required this.scope, required this.cells});

  factory ReportHeatmap.fromJson(JsonMap json) {
    return ReportHeatmap(
      scope: ReportScope.fromJson(asJsonMap(json['scope'])),
      cells: asJsonMapList(
        json['cells'],
      ).map(ReportHeatmapCell.fromJson).toList(),
    );
  }
}

class ReportPeakHourItem {
  final int rank;
  final int hour;
  final String label;
  final double averageOccupancyRate;
  final double peakOccupancyRate;
  final int sampleCount;

  const ReportPeakHourItem({
    required this.rank,
    required this.hour,
    required this.label,
    required this.averageOccupancyRate,
    required this.peakOccupancyRate,
    required this.sampleCount,
  });

  factory ReportPeakHourItem.fromJson(JsonMap json) {
    return ReportPeakHourItem(
      rank: readInt(json, 'rank'),
      hour: readInt(json, 'hour'),
      label: readString(json, 'label'),
      averageOccupancyRate: readDouble(json, 'averageOccupancyRate'),
      peakOccupancyRate: readDouble(json, 'peakOccupancyRate'),
      sampleCount: readInt(json, 'sampleCount'),
    );
  }
}

class ReportPeakHours {
  final ReportScope scope;
  final List<ReportPeakHourItem> items;

  const ReportPeakHours({required this.scope, required this.items});

  factory ReportPeakHours.fromJson(JsonMap json) {
    return ReportPeakHours(
      scope: ReportScope.fromJson(asJsonMap(json['scope'])),
      items: asJsonMapList(
        json['items'],
      ).map(ReportPeakHourItem.fromJson).toList(),
    );
  }
}

class ReportDashboard {
  final ReportSummary summary;
  final ReportTrend trend;
  final ReportHeatmap heatmap;
  final ReportPeakHours peakHours;

  const ReportDashboard({
    required this.summary,
    required this.trend,
    required this.heatmap,
    required this.peakHours,
  });
}
