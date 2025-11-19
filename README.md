# HKU Library Booking Backend

后端采用 **FastAPI + PostgreSQL + SQLAlchemy**，当前完成：

- 图书馆与设施的建模及建表（包含未来座位占用率相关表）
- 图书馆列表与详情（含设施信息）接口
- 设施日程查询（按时间段展示预约状态）
- 设施预约与取消预约接口

座位实时占用率模块已完成数据库设计，后续可在此基础上补充数据采集与接口。

## 目录结构

```
backend/
  app/
    core/        # 配置、数据库连接
    models/      # SQLAlchemy ORM 模型
    routers/     # FastAPI 路由
    schemas/     # Pydantic 响应/请求模型
    services/    # 业务逻辑
    main.py      # FastAPI 入口
  scripts/
    seed_data.py # 示例数据脚本
  requirements.txt
  env.example
```

## 环境准备

1. 创建虚拟环境并安装依赖

   ```bash
   cd backend
   python -m venv .venv
   .venv\Scripts\activate   # Windows
   pip install -r requirements.txt
   ```

2. 配置数据库

   - 在 PostgreSQL 中创建数据库（默认名称 `hku_library`）。
   - 复制 `backend/env.example` 为 `backend/.env` 并按需修改 `DATABASE_URL`。

3. 运行开发服务器

   ```bash
   uvicorn app.main:app --reload --app-dir backend
   ```

   API 文档：<http://127.0.0.1:8000/docs>

4. （可选）导入示例数据

   ```bash
   cd backend
   python -m scripts.seed_data
   ```

## 主要数据表

| 表名 | 说明 |
| ---- | ---- |
| `libraries` | 图书馆基础信息 |
| `facilities` | 可预约设施（自习室、座位等） |
| `users` | 预约用户信息（按邮箱唯一） |
| `reservations` | 预约记录，含状态、时间段 |
| `library_occupancy_snapshots` | 座位实时占用快照 |
| `library_occupancy_statistics` | 周期占用率统计（小时/天/周） |

## 已实现 API（`/api/v1` 前缀）

| 方法 | 路径 | 功能 |
| ---- | ---- | ---- |
| GET | `/libraries` | 图书馆列表（含设施数量） |
| GET | `/libraries/{id}` | 图书馆详情与设施信息 |
| GET | `/facilities/{id}/timeslots?date=YYYY-MM-DD` | 指定日期全部时间段及预约状态 |
| POST | `/reservations` | 提交预约（自动创建/更新用户信息） |
| DELETE | `/reservations/{uuid}` | 取消预约 |

示例预约请求：

```json
{
  "facility_id": 1,
  "reservation_date": "2025-11-20",
  "start_time": "10:00",
  "end_time": "12:00",
  "user_full_name": "Student A",
  "user_email": "studenta@example.com",
  "notes": "Group study"
}
```

## 后续计划（座位占用率模块）

- 编写定时任务或实时采集服务，将每 5 分钟的座位使用情况写入 `library_occupancy_snapshots`
- 基于快照生成周期性统计（小时 / 天 / 周），落库到 `library_occupancy_statistics`
- 对外提供实时与历史占用率查询接口

完成以上步骤后，即可支持移动端实时查看座位情况及趋势。需要更多帮助时可继续提出具体需求。*** End Patch