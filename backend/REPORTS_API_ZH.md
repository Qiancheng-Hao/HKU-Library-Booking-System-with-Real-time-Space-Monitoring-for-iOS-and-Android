# 历史人流分析报表接口文档

## 概述

本文档描述历史人流分析功能对应的后端接口，供前端联调和项目文档使用。

- 接口前缀：`/api/v1/reports`
- 认证方式：需要 `Bearer Token`
- 数据来源：`occupancy_area_snapshots`
- 占用率单位：接口返回的占用率均为 `0-100` 的百分比，而不是 `0-1`
- 时区：报表窗口、趋势 bucket、星期/小时分组和展示标签均使用 `DEFAULT_TIMEZONE`（默认：`Asia/Hong_Kong`）

该接口主要用于前端展示以下内容：

- 摘要卡片
- 趋势图
- 热力图
- 高峰时段排行

## 通用规则

- 所有接口均为 `GET`
- 所有接口都需要携带 `Authorization: Bearer <token>`
- 支持按 `location` 和 `area` 过滤
- 如果传入了 `area`，则必须同时传入 `location`
- `days` 表示向前回看的统计天数

## 通用查询参数

| 参数名 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `location` | `string` | 否 | 图书馆名称，对应 `occupancy_area_snapshots.location` |
| `area` | `string` | 否 | 区域名称，对应 `occupancy_area_snapshots.area` |
| `days` | `int` | 否 | 回看天数，范围 `1-365` |

## 通用返回字段 `scope`

所有接口响应中都包含一个 `scope` 对象：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `scope.location` | `string \| null` | 本次查询使用的图书馆过滤条件 |
| `scope.area` | `string \| null` | 本次查询使用的区域过滤条件 |
| `scope.days` | `int` | 本次查询使用的回看天数 |
| `scope.generatedAt` | `datetime` | 报表生成时间，使用 `DEFAULT_TIMEZONE` |
| `scope.since` | `datetime` | 统计窗口起始时间，使用 `DEFAULT_TIMEZONE` |
| `scope.until` | `datetime` | 统计窗口结束时间，使用 `DEFAULT_TIMEZONE` |

## 1. Summary Report

### 接口地址

```http
GET /api/v1/reports/summary
```

### 接口用途

返回某个统计范围内的高层摘要信息，适合用于顶部 KPI 卡片和自然语言总结。

### 查询参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `location` | `string` | 否 | `null` | 按图书馆名称过滤 |
| `area` | `string` | 否 | `null` | 按监测区域过滤 |
| `days` | `int` | 否 | `30` | 回看天数 |

### 返回字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `hasData` | `boolean` | 当前筛选条件下是否存在数据 |
| `averageOccupancyRate` | `float \| null` | 平均占用率，百分比 |
| `peakOccupancyRate` | `float \| null` | 峰值占用率，百分比 |
| `totalSampleCount` | `int` | 累计样本数 |
| `observationCount` | `int` | 纳入统计的快照记录数 |
| `firstObservedAt` | `datetime \| null` | 当前窗口内最早的观测时间 |
| `lastObservedAt` | `datetime \| null` | 当前窗口内最新的观测时间 |
| `busiestWeekday` | `object \| null` | 最繁忙星期信息 |
| `busiestHour` | `object \| null` | 最繁忙小时段信息 |
| `suggestedLowTrafficHour` | `object \| null` | 建议低峰访问小时段 |

### `busiestWeekday` 结构

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `weekdayIndex` | `int` | `0-6`，其中 `0 = Sunday` |
| `weekdayName` | `string` | 星期名称 |
| `averageOccupancyRate` | `float` | 该星期的平均占用率 |
| `peakOccupancyRate` | `float` | 该星期的峰值占用率 |
| `sampleCount` | `int` | 样本数 |

### `busiestHour` / `suggestedLowTrafficHour` 结构

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `hour` | `int` | `0-23` |
| `label` | `string` | 时间段标签，例如 `14:00-15:00` |
| `averageOccupancyRate` | `float` | 该小时段平均占用率 |
| `peakOccupancyRate` | `float` | 该小时段峰值占用率 |
| `sampleCount` | `int` | 样本数 |

### 请求示例

```http
GET /api/v1/reports/summary?location=Chi%20Wah%20Learning%20Commons&days=30
Authorization: Bearer <token>
```

### 响应示例

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

### 接口地址

```http
GET /api/v1/reports/trend
```

### 接口用途

返回时间序列趋势数据，适合绘制折线图或面积图。

### 查询参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `location` | `string` | 否 | `null` | 按图书馆名称过滤 |
| `area` | `string` | 否 | `null` | 按监测区域过滤 |
| `days` | `int` | 否 | `7` | 回看天数 |
| `bucket` | `"hour" \| "day"` | 否 | `"hour"` | 趋势聚合粒度 |

### 返回字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `bucket` | `string` | 当前使用的聚合粒度 |
| `points` | `array` | 趋势点数组 |

### `points[]` 结构

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `bucketStart` | `datetime` | 该 bucket 的起始时间 |
| `bucketLabel` | `string` | 前端可直接显示的标签 |
| `averageOccupancyRate` | `float` | 平均占用率，百分比 |
| `peakOccupancyRate` | `float` | 峰值占用率，百分比 |
| `sampleCount` | `int` | 样本数 |

### 请求示例

```http
GET /api/v1/reports/trend?location=Chi%20Wah%20Learning%20Commons&days=7&bucket=hour
Authorization: Bearer <token>
```

### 响应示例

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

### 接口地址

```http
GET /api/v1/reports/heatmap
```

### 接口用途

返回 `星期 x 小时` 的热力图数据，适合绘制 `7 x 24` 的热力图。

### 查询参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `location` | `string` | 否 | `null` | 按图书馆名称过滤 |
| `area` | `string` | 否 | `null` | 按监测区域过滤 |
| `days` | `int` | 否 | `30` | 回看天数 |

### 返回字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `cells` | `array` | 热力图单元数组 |

### `cells[]` 结构

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `weekdayIndex` | `int` | `0-6`，其中 `0 = Sunday` |
| `weekdayName` | `string` | 星期名称 |
| `hour` | `int` | `0-23` |
| `averageOccupancyRate` | `float` | 平均占用率，百分比 |
| `peakOccupancyRate` | `float` | 峰值占用率，百分比 |
| `sampleCount` | `int` | 样本数 |

### 请求示例

```http
GET /api/v1/reports/heatmap?location=Chi%20Wah%20Learning%20Commons&days=30
Authorization: Bearer <token>
```

### 响应示例

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

### 接口地址

```http
GET /api/v1/reports/peak-hours
```

### 接口用途

返回最繁忙的前 N 个小时段，适合做高峰时段排行榜。

### 查询参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `location` | `string` | 否 | `null` | 按图书馆名称过滤 |
| `area` | `string` | 否 | `null` | 按监测区域过滤 |
| `days` | `int` | 否 | `30` | 回看天数 |
| `limit` | `int` | 否 | `5` | 返回的高峰时段数量，范围 `1-24` |

### 返回字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `items` | `array` | 高峰时段排行数组 |

### `items[]` 结构

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `rank` | `int` | 排名，从 `1` 开始 |
| `hour` | `int` | `0-23` |
| `label` | `string` | 时间段标签，例如 `14:00-15:00` |
| `averageOccupancyRate` | `float` | 平均占用率，百分比 |
| `peakOccupancyRate` | `float` | 峰值占用率，百分比 |
| `sampleCount` | `int` | 样本数 |

### 请求示例

```http
GET /api/v1/reports/peak-hours?location=Chi%20Wah%20Learning%20Commons&area=Level%203&days=30&limit=5
Authorization: Bearer <token>
```

### 响应示例

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

## 错误响应

### 400 Bad Request

当传入 `area` 但没有传入 `location` 时返回：

```json
{
  "detail": "location is required when area is provided."
}
```

### 401 Unauthorized

当未携带 token 或 token 无效时返回：

```json
{
  "detail": "Not authenticated"
}
```

## 前端接入建议

- `summary` 适合做概览卡片和摘要说明
- `trend` 适合做折线图
- `heatmap` 适合做 `7 x 24` 热力图
- `peak-hours` 适合做高峰时段排行榜
- 第一版前端建议先只传 `location`，把 `area` 作为高级筛选项

## 推荐的前端首版调用方式

```http
GET /api/v1/reports/summary?location=<library_name>&days=30
GET /api/v1/reports/trend?location=<library_name>&days=7&bucket=hour
GET /api/v1/reports/heatmap?location=<library_name>&days=30
GET /api/v1/reports/peak-hours?location=<library_name>&days=30&limit=5
```
