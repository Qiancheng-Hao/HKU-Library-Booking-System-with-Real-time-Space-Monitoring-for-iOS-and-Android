from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel


ReportBucket = Literal["hour", "day"]


class ReportScope(BaseModel):
    location: str | None = None
    area: str | None = None
    days: int
    generatedAt: datetime
    since: datetime
    until: datetime


class ReportWeekdayInsight(BaseModel):
    weekdayIndex: int
    weekdayName: str
    averageOccupancyRate: float
    peakOccupancyRate: float
    sampleCount: int


class ReportHourInsight(BaseModel):
    hour: int
    label: str
    averageOccupancyRate: float
    peakOccupancyRate: float
    sampleCount: int


class ReportSummaryResponse(BaseModel):
    scope: ReportScope
    hasData: bool
    averageOccupancyRate: float | None = None
    peakOccupancyRate: float | None = None
    totalSampleCount: int = 0
    observationCount: int = 0
    firstObservedAt: datetime | None = None
    lastObservedAt: datetime | None = None
    busiestWeekday: ReportWeekdayInsight | None = None
    busiestHour: ReportHourInsight | None = None
    suggestedLowTrafficHour: ReportHourInsight | None = None


class ReportTrendPoint(BaseModel):
    bucketStart: datetime
    bucketLabel: str
    averageOccupancyRate: float
    peakOccupancyRate: float
    sampleCount: int


class ReportTrendResponse(BaseModel):
    scope: ReportScope
    bucket: ReportBucket
    points: list[ReportTrendPoint]


class ReportHeatmapCell(BaseModel):
    weekdayIndex: int
    weekdayName: str
    hour: int
    averageOccupancyRate: float
    peakOccupancyRate: float
    sampleCount: int


class ReportHeatmapResponse(BaseModel):
    scope: ReportScope
    cells: list[ReportHeatmapCell]


class ReportPeakHourItem(BaseModel):
    rank: int
    hour: int
    label: str
    averageOccupancyRate: float
    peakOccupancyRate: float
    sampleCount: int


class ReportPeakHoursResponse(BaseModel):
    scope: ReportScope
    items: list[ReportPeakHourItem]
