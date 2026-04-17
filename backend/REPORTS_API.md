# Historical Crowd Reports API

## Overview

This document describes the backend API for the historical crowd data analysis feature.

- Base path: `/api/v1/reports`
- Authentication: `Bearer Token` required
- Data source: `occupancy_area_snapshots`
- Occupancy rate unit: all returned occupancy rate values are percentages in the range `0-100`
- Timezone: report windows, trend buckets, weekday/hour grouping, and display labels use `DEFAULT_TIMEZONE` (default: `Asia/Hong_Kong`)

This API is designed for frontend visualization of:

- summary cards
- trend charts
- heatmaps
- peak-hour rankings

## Common Rules

- All endpoints use `GET`
- All endpoints require `Authorization: Bearer <token>`
- Filtering supports `location` and `area`
- If `area` is provided, `location` must also be provided
- `days` means the lookback window in days

## Common Query Parameters

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `location` | `string` | No | Library name, matched against `occupancy_area_snapshots.location` |
| `area` | `string` | No | Monitored area name, matched against `occupancy_area_snapshots.area` |
| `days` | `int` | No | Lookback window in days, range `1-365` |

## Common Response Scope

All responses include a `scope` object:

| Field | Type | Description |
| --- | --- | --- |
| `scope.location` | `string \| null` | Library filter used for this query |
| `scope.area` | `string \| null` | Area filter used for this query |
| `scope.days` | `int` | Lookback window used for this query |
| `scope.generatedAt` | `datetime` | Timestamp when the report was generated, in `DEFAULT_TIMEZONE` |
| `scope.since` | `datetime` | Start time of the reporting window, in `DEFAULT_TIMEZONE` |
| `scope.until` | `datetime` | End time of the reporting window, in `DEFAULT_TIMEZONE` |

## 1. Summary Report

### Endpoint

```http
GET /api/v1/reports/summary
```

### Purpose

Provides high-level historical insights for a selected scope.

### Query Parameters

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `location` | `string` | No | `null` | Filter by library name |
| `area` | `string` | No | `null` | Filter by monitored area |
| `days` | `int` | No | `30` | Lookback window |

### Response Fields

| Field | Type | Description |
| --- | --- | --- |
| `hasData` | `boolean` | Whether there is data under the current filter |
| `averageOccupancyRate` | `float \| null` | Average occupancy rate in percent |
| `peakOccupancyRate` | `float \| null` | Peak occupancy rate in percent |
| `totalSampleCount` | `int` | Total aggregated sample count |
| `observationCount` | `int` | Number of snapshot rows included |
| `firstObservedAt` | `datetime \| null` | Earliest observed timestamp in the window |
| `lastObservedAt` | `datetime \| null` | Latest observed timestamp in the window |
| `busiestWeekday` | `object \| null` | Busiest weekday insight |
| `busiestHour` | `object \| null` | Busiest hour insight |
| `suggestedLowTrafficHour` | `object \| null` | Suggested low-traffic hour insight |

### `busiestWeekday` Structure

| Field | Type | Description |
| --- | --- | --- |
| `weekdayIndex` | `int` | `0-6`, where `0 = Sunday` |
| `weekdayName` | `string` | Weekday name |
| `averageOccupancyRate` | `float` | Average occupancy rate for this weekday |
| `peakOccupancyRate` | `float` | Peak occupancy rate for this weekday |
| `sampleCount` | `int` | Sample count |

### `busiestHour` / `suggestedLowTrafficHour` Structure

| Field | Type | Description |
| --- | --- | --- |
| `hour` | `int` | `0-23` |
| `label` | `string` | Time window label such as `14:00-15:00` |
| `averageOccupancyRate` | `float` | Average occupancy rate for this hour |
| `peakOccupancyRate` | `float` | Peak occupancy rate for this hour |
| `sampleCount` | `int` | Sample count |

### Example Request

```http
GET /api/v1/reports/summary?location=Chi%20Wah%20Learning%20Commons&days=30
Authorization: Bearer <token>
```

### Example Response

```json
{
  "scope": {
    "location": "Chi Wah Learning Commons",
    "area": null,
    "days": 30,
    "generatedAt": "2026-04-17T12:00:00Z",
    "since": "2026-03-18T12:00:00Z",
    "until": "2026-04-17T12:00:00Z"
  },
  "hasData": true,
  "averageOccupancyRate": 62.41,
  "peakOccupancyRate": 95.73,
  "totalSampleCount": 18420,
  "observationCount": 960,
  "firstObservedAt": "2026-03-18T12:10:00Z",
  "lastObservedAt": "2026-04-17T11:50:00Z",
  "busiestWeekday": {
    "weekdayIndex": 2,
    "weekdayName": "Tuesday",
    "averageOccupancyRate": 71.33,
    "peakOccupancyRate": 95.73,
    "sampleCount": 2910
  },
  "busiestHour": {
    "hour": 14,
    "label": "14:00-15:00",
    "averageOccupancyRate": 82.14,
    "peakOccupancyRate": 95.73,
    "sampleCount": 1340
  },
  "suggestedLowTrafficHour": {
    "hour": 9,
    "label": "09:00-10:00",
    "averageOccupancyRate": 31.26,
    "peakOccupancyRate": 48.91,
    "sampleCount": 910
  }
}
```

## 2. Trend Report

### Endpoint

```http
GET /api/v1/reports/trend
```

### Purpose

Provides time-series data for line charts or area charts.

### Query Parameters

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `location` | `string` | No | `null` | Filter by library name |
| `area` | `string` | No | `null` | Filter by monitored area |
| `days` | `int` | No | `7` | Lookback window |
| `bucket` | `"hour" \| "day"` | No | `"hour"` | Aggregation bucket |

### Response Fields

| Field | Type | Description |
| --- | --- | --- |
| `bucket` | `string` | The aggregation granularity used |
| `points` | `array` | Time-series points |

### `points[]` Structure

| Field | Type | Description |
| --- | --- | --- |
| `bucketStart` | `datetime` | Start timestamp of the bucket |
| `bucketLabel` | `string` | Display label for frontend |
| `averageOccupancyRate` | `float` | Average occupancy rate in percent |
| `peakOccupancyRate` | `float` | Peak occupancy rate in percent |
| `sampleCount` | `int` | Sample count |

### Example Request

```http
GET /api/v1/reports/trend?location=Chi%20Wah%20Learning%20Commons&days=7&bucket=hour
Authorization: Bearer <token>
```

### Example Response

```json
{
  "scope": {
    "location": "Chi Wah Learning Commons",
    "area": null,
    "days": 7,
    "generatedAt": "2026-04-17T12:00:00Z",
    "since": "2026-04-10T12:00:00Z",
    "until": "2026-04-17T12:00:00Z"
  },
  "bucket": "hour",
  "points": [
    {
      "bucketStart": "2026-04-17T09:00:00Z",
      "bucketLabel": "2026-04-17 09:00",
      "averageOccupancyRate": 41.25,
      "peakOccupancyRate": 50.38,
      "sampleCount": 84
    },
    {
      "bucketStart": "2026-04-17T10:00:00Z",
      "bucketLabel": "2026-04-17 10:00",
      "averageOccupancyRate": 56.82,
      "peakOccupancyRate": 66.11,
      "sampleCount": 96
    }
  ]
}
```

## 3. Heatmap Report

### Endpoint

```http
GET /api/v1/reports/heatmap
```

### Purpose

Provides `weekday x hour` data for heatmap visualization.

### Query Parameters

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `location` | `string` | No | `null` | Filter by library name |
| `area` | `string` | No | `null` | Filter by monitored area |
| `days` | `int` | No | `30` | Lookback window |

### Response Fields

| Field | Type | Description |
| --- | --- | --- |
| `cells` | `array` | Heatmap cells |

### `cells[]` Structure

| Field | Type | Description |
| --- | --- | --- |
| `weekdayIndex` | `int` | `0-6`, where `0 = Sunday` |
| `weekdayName` | `string` | Weekday name |
| `hour` | `int` | `0-23` |
| `averageOccupancyRate` | `float` | Average occupancy rate in percent |
| `peakOccupancyRate` | `float` | Peak occupancy rate in percent |
| `sampleCount` | `int` | Sample count |

### Example Request

```http
GET /api/v1/reports/heatmap?location=Chi%20Wah%20Learning%20Commons&days=30
Authorization: Bearer <token>
```

### Example Response

```json
{
  "scope": {
    "location": "Chi Wah Learning Commons",
    "area": null,
    "days": 30,
    "generatedAt": "2026-04-17T12:00:00Z",
    "since": "2026-03-18T12:00:00Z",
    "until": "2026-04-17T12:00:00Z"
  },
  "cells": [
    {
      "weekdayIndex": 1,
      "weekdayName": "Monday",
      "hour": 10,
      "averageOccupancyRate": 48.73,
      "peakOccupancyRate": 62.14,
      "sampleCount": 188
    },
    {
      "weekdayIndex": 1,
      "weekdayName": "Monday",
      "hour": 11,
      "averageOccupancyRate": 63.28,
      "peakOccupancyRate": 77.95,
      "sampleCount": 205
    }
  ]
}
```

## 4. Peak Hours Report

### Endpoint

```http
GET /api/v1/reports/peak-hours
```

### Purpose

Provides the top N busiest hour windows for ranking display.

### Query Parameters

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `location` | `string` | No | `null` | Filter by library name |
| `area` | `string` | No | `null` | Filter by monitored area |
| `days` | `int` | No | `30` | Lookback window |
| `limit` | `int` | No | `5` | Maximum number of peak-hour items, range `1-24` |

### Response Fields

| Field | Type | Description |
| --- | --- | --- |
| `items` | `array` | Ranked peak-hour list |

### `items[]` Structure

| Field | Type | Description |
| --- | --- | --- |
| `rank` | `int` | Rank starting from `1` |
| `hour` | `int` | `0-23` |
| `label` | `string` | Time window label such as `14:00-15:00` |
| `averageOccupancyRate` | `float` | Average occupancy rate in percent |
| `peakOccupancyRate` | `float` | Peak occupancy rate in percent |
| `sampleCount` | `int` | Sample count |

### Example Request

```http
GET /api/v1/reports/peak-hours?location=Chi%20Wah%20Learning%20Commons&area=Level%203&days=30&limit=5
Authorization: Bearer <token>
```

### Example Response

```json
{
  "scope": {
    "location": "Chi Wah Learning Commons",
    "area": "Level 3",
    "days": 30,
    "generatedAt": "2026-04-17T12:00:00Z",
    "since": "2026-03-18T12:00:00Z",
    "until": "2026-04-17T12:00:00Z"
  },
  "items": [
    {
      "rank": 1,
      "hour": 14,
      "label": "14:00-15:00",
      "averageOccupancyRate": 88.13,
      "peakOccupancyRate": 97.42,
      "sampleCount": 320
    },
    {
      "rank": 2,
      "hour": 15,
      "label": "15:00-16:00",
      "averageOccupancyRate": 85.41,
      "peakOccupancyRate": 95.30,
      "sampleCount": 301
    }
  ]
}
```

## Error Responses

### 400 Bad Request

Occurs when `area` is provided without `location`.

```json
{
  "detail": "location is required when area is provided."
}
```

### 401 Unauthorized

Occurs when the token is missing or invalid.

```json
{
  "detail": "Not authenticated"
}
```

## Frontend Integration Notes

- `summary` is suitable for KPI cards and textual insights
- `trend` is suitable for line charts
- `heatmap` is suitable for a `7 x 24` grid visualization
- `peak-hours` is suitable for ranked time-slot lists
- For the first version, frontend can use `location` filtering only and treat `area` as an optional advanced filter

## Recommended Initial Frontend Calls

```http
GET /api/v1/reports/summary?location=<library_name>&days=30
GET /api/v1/reports/trend?location=<library_name>&days=7&bucket=hour
GET /api/v1/reports/heatmap?location=<library_name>&days=30
GET /api/v1/reports/peak-hours?location=<library_name>&days=30&limit=5
```
