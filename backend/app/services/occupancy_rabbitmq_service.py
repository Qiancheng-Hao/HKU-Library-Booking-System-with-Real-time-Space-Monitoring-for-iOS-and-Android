from __future__ import annotations

import base64
import json
import logging
import threading
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionLocal
from app.models.occupancy import CameraSource
from app.services.occupancy_cache_service import add_stats_event_to_window
from app.services.occupancy_cv_service import (
    build_occupancy_stats_event,
    decode_image_bytes,
    estimate_occupancy_from_frame,
    normalize_stream_url,
    save_occupancy_log,
)

logger = logging.getLogger(__name__)


def _import_pika():
    try:
        import pika
        from pika.exceptions import AMQPError
    except ImportError as exc:
        raise RuntimeError("pika is required for RabbitMQ camera capture.") from exc
    return pika, AMQPError


@dataclass(frozen=True)
class CameraStreamConfig:
    name: str
    stream_url: str
    location: str
    area: str


def _load_enabled_cameras() -> list[CameraStreamConfig]:
    with SessionLocal() as db:
        cameras = (
            db.execute(select(CameraSource).where(CameraSource.enabled.is_(True)))
            .scalars()
            .all()
        )
        return [
            CameraStreamConfig(
                name=str(camera.name),
                stream_url=str(camera.stream_url),
                location=str(camera.location),
                area=str(camera.area),
            )
            for camera in cameras
        ]


def _close_quietly(resource: Any) -> None:
    if resource is None:
        return
    if getattr(resource, "is_closed", False):
        return
    try:
        close = getattr(resource, "close", None)
        if getattr(resource, "is_open", True) and callable(close):
            close()
            return
        release = getattr(resource, "release", None)
        if callable(release):
            release()
    except Exception:
        pass


def _open_rabbitmq_channel(pika: Any, queue_name: str) -> tuple[Any, Any]:
    connection = pika.BlockingConnection(pika.URLParameters(settings.rabbitmq_url))
    channel = connection.channel()
    channel.queue_declare(queue=queue_name, durable=True)
    return connection, channel


def _sleep(stop_event: threading.Event, seconds: float) -> None:
    stop_event.wait(max(0.0, float(seconds)))


def _build_message(camera: CameraStreamConfig, frame_bytes: bytes, captured_at: datetime) -> bytes:
    payload = {
        "event_id": str(uuid.uuid4()),
        "camera_name": camera.name,
        "location": camera.location,
        "area": camera.area,
        "captured_at": captured_at.isoformat(),
        "image_base64": base64.b64encode(frame_bytes).decode("ascii"),
    }
    return json.dumps(payload).encode("utf-8")


def _parse_message(body: bytes) -> dict[str, Any]:
    payload = json.loads(body.decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("Invalid RabbitMQ frame payload.")
    return payload


def _read_event_id(payload: dict[str, Any]) -> uuid.UUID:
    raw_value = payload.get("event_id")
    if raw_value is None:
        return uuid.uuid4()
    try:
        return uuid.UUID(str(raw_value))
    except (ValueError, TypeError):
        return uuid.uuid4()


class CameraFramePublisher(threading.Thread):
    def __init__(
        self,
        *,
        camera: CameraStreamConfig,
        queue_name: str,
        stop_event: threading.Event,
    ) -> None:
        super().__init__(name=f"camera-publisher-{camera.name}", daemon=True)
        self.camera = camera
        self.queue_name = queue_name
        self.stop_event = stop_event

    def run(self) -> None:
        import cv2

        pika, AMQPError = _import_pika()
        connection = None
        channel = None
        capture = None

        while not self.stop_event.is_set():
            try:
                if capture is None or not capture.isOpened():
                    stream_url = normalize_stream_url(self.camera.stream_url)
                    logger.info(
                        "rabbitmq publisher connect camera=%s url=%s",
                        self.camera.name,
                        stream_url,
                    )
                    capture = cv2.VideoCapture(stream_url)
                    if not capture.isOpened():
                        logger.warning(
                            "rabbitmq publisher open failed camera=%s",
                            self.camera.name,
                        )
                        _close_quietly(capture)
                        capture = None
                        _close_quietly(connection)
                        connection = None
                        channel = None
                        _sleep(self.stop_event, settings.rabbitmq_reconnect_seconds)
                        continue

                ok, frame = capture.read()
                if not ok or frame is None:
                    logger.warning(
                        "rabbitmq publisher read failed camera=%s",
                        self.camera.name,
                    )
                    _close_quietly(capture)
                    capture = None
                    _close_quietly(connection)
                    connection = None
                    channel = None
                    _sleep(self.stop_event, settings.rabbitmq_reconnect_seconds)
                    continue

                encode_ok, encoded = cv2.imencode(
                    ".jpg",
                    frame,
                    [
                        int(cv2.IMWRITE_JPEG_QUALITY),
                        max(1, min(100, int(settings.rabbitmq_frame_jpeg_quality))),
                    ],
                )
                if not encode_ok:
                    logger.warning(
                        "rabbitmq publisher encode failed camera=%s",
                        self.camera.name,
                    )
                    _sleep(self.stop_event, settings.camera_capture_interval_seconds)
                    continue

                captured_at = datetime.now(timezone.utc)
                body = _build_message(self.camera, encoded.tobytes(), captured_at)
                if (
                    connection is None
                    or getattr(connection, "is_closed", True)
                    or channel is None
                    or getattr(channel, "is_closed", True)
                ):
                    _close_quietly(connection)
                    connection, channel = _open_rabbitmq_channel(
                        pika,
                        self.queue_name,
                    )
                channel.basic_publish(
                    exchange="",
                    routing_key=self.queue_name,
                    body=body,
                    properties=pika.BasicProperties(
                        delivery_mode=2,
                        content_type="application/json",
                    ),
                )
                connection.process_data_events(time_limit=0)
                _sleep(self.stop_event, settings.camera_capture_interval_seconds)
            except AMQPError as exc:
                logger.warning(
                    "rabbitmq publisher connection reset camera=%s error=%s",
                    self.camera.name,
                    exc,
                )
                _close_quietly(connection)
                connection = None
                channel = None
                _sleep(self.stop_event, settings.rabbitmq_reconnect_seconds)
            except Exception:
                logger.exception(
                    "rabbitmq publisher failed camera=%s",
                    self.camera.name,
                )
                _close_quietly(capture)
                capture = None
                _close_quietly(connection)
                connection = None
                channel = None
                _sleep(self.stop_event, settings.rabbitmq_reconnect_seconds)

        _close_quietly(capture)
        _close_quietly(connection)


class OccupancyInferenceConsumer(threading.Thread):
    def __init__(
        self,
        *,
        queue_name: str,
        stats_queue_name: str,
        stop_event: threading.Event,
    ) -> None:
        super().__init__(name="occupancy-inference-consumer", daemon=True)
        self.queue_name = queue_name
        self.stats_queue_name = stats_queue_name
        self.stop_event = stop_event

    def run(self) -> None:
        pika, AMQPError = _import_pika()

        while not self.stop_event.is_set():
            connection = None
            channel = None
            iterator = None
            try:
                connection = pika.BlockingConnection(
                    pika.URLParameters(settings.rabbitmq_url)
                )
                channel = connection.channel()
                channel.queue_declare(queue=self.queue_name, durable=True)
                channel.queue_declare(queue=self.stats_queue_name, durable=True)
                channel.basic_qos(
                    prefetch_count=max(1, int(settings.rabbitmq_prefetch_count))
                )
                iterator = channel.consume(
                    queue=self.queue_name,
                    inactivity_timeout=1,
                    auto_ack=False,
                )

                for method_frame, _, body in iterator:
                    if self.stop_event.is_set():
                        break
                    if method_frame is None or body is None:
                        continue

                    try:
                        payload = _parse_message(body)
                        event_id = _read_event_id(payload)
                        captured_at = datetime.fromisoformat(str(payload["captured_at"]))
                        if captured_at.tzinfo is None:
                            captured_at = captured_at.replace(tzinfo=timezone.utc)
                        frame = decode_image_bytes(base64.b64decode(str(payload["image_base64"])))
                        stats = estimate_occupancy_from_frame(
                            frame=frame,
                            location=str(payload["location"]),
                            area=str(payload["area"]),
                        )
                        stats_message = {
                            "event_id": str(event_id),
                            "camera_name": str(payload["camera_name"]),
                            "location": str(payload["location"]),
                            "area": str(payload["area"]),
                            "captured_at": captured_at.isoformat(),
                            "stats": {
                                "total_number_of_person": int(stats.get("total_number_of_person", 0) or 0),
                                "total_number_of_hogging_items": int(stats.get("total_number_of_hogging_items", 0) or 0),
                                "total_number_of_seats": int(stats.get("total_number_of_seats", 0) or 0),
                                "occupancy_rate": float(stats.get("occupancy_rate", -1.0) or -1.0),
                            },
                        }
                        channel.basic_publish(
                            exchange="",
                            routing_key=self.stats_queue_name,
                            body=json.dumps(stats_message).encode("utf-8"),
                            properties=pika.BasicProperties(
                                delivery_mode=2,
                                content_type="application/json",
                            ),
                        )
                        channel.basic_ack(delivery_tag=method_frame.delivery_tag)
                    except AMQPError:
                        raise
                    except Exception:
                        logger.exception("rabbitmq inference consumer processing failed")
                        try:
                            channel.basic_nack(
                                delivery_tag=method_frame.delivery_tag,
                                requeue=False,
                            )
                        except AMQPError:
                            raise
            except AMQPError:
                logger.exception("rabbitmq inference consumer connection failed")
                _sleep(self.stop_event, settings.rabbitmq_reconnect_seconds)
            except Exception:
                logger.exception("rabbitmq inference consumer loop failed")
                _sleep(self.stop_event, settings.rabbitmq_reconnect_seconds)
            finally:
                if iterator is not None:
                    try:
                        iterator.close()
                    except Exception:
                        pass
                if channel is not None and getattr(channel, "is_open", False):
                    try:
                        channel.cancel()
                    except Exception:
                        pass
                _close_quietly(connection)


class OccupancyStatsConsumer(threading.Thread):
    def __init__(self, *, queue_name: str, stop_event: threading.Event) -> None:
        super().__init__(name="occupancy-stats-consumer", daemon=True)
        self.queue_name = queue_name
        self.stop_event = stop_event

    def run(self) -> None:
        pika, AMQPError = _import_pika()

        while not self.stop_event.is_set():
            connection = None
            channel = None
            iterator = None
            try:
                connection = pika.BlockingConnection(
                    pika.URLParameters(settings.rabbitmq_url)
                )
                channel = connection.channel()
                channel.queue_declare(queue=self.queue_name, durable=True)
                channel.basic_qos(
                    prefetch_count=max(1, int(settings.rabbitmq_prefetch_count))
                )
                iterator = channel.consume(
                    queue=self.queue_name,
                    inactivity_timeout=1,
                    auto_ack=False,
                )

                for method_frame, _, body in iterator:
                    if self.stop_event.is_set():
                        break
                    if method_frame is None or body is None:
                        continue

                    try:
                        payload = _parse_message(body)
                        captured_at = datetime.fromisoformat(str(payload["captured_at"]))
                        if captured_at.tzinfo is None:
                            captured_at = captured_at.replace(tzinfo=timezone.utc)
                        stats = dict(payload["stats"])
                        event_id = _read_event_id(payload)
                        camera_name = str(payload["camera_name"])

                        with SessionLocal() as db:
                            save_occupancy_log(
                                db,
                                location=str(payload["location"]),
                                area=str(payload["area"]),
                                stats=stats,
                                source=camera_name,
                                frame_index=None,
                                captured_at=captured_at,
                                event_id=event_id,
                                camera_name=camera_name,
                            )
                            camera = (
                                db.execute(
                                    select(CameraSource).where(
                                        CameraSource.name == camera_name
                                    )
                                )
                                .scalars()
                                .first()
                            )
                            if camera is not None:
                                camera.last_captured_at = captured_at
                                db.add(camera)
                            db.commit()

                        event = build_occupancy_stats_event(
                            location=str(payload["location"]),
                            area=str(payload["area"]),
                            stats=stats,
                            camera_name=camera_name,
                            captured_at=captured_at,
                            event_id=event_id,
                        )
                        add_stats_event_to_window(event)
                        channel.basic_ack(delivery_tag=method_frame.delivery_tag)
                    except AMQPError:
                        raise
                    except Exception:
                        logger.exception("rabbitmq stats consumer processing failed")
                        try:
                            channel.basic_nack(
                                delivery_tag=method_frame.delivery_tag,
                                requeue=False,
                            )
                        except AMQPError:
                            raise
            except AMQPError:
                logger.exception("rabbitmq stats consumer connection failed")
                _sleep(self.stop_event, settings.rabbitmq_reconnect_seconds)
            except Exception:
                logger.exception("rabbitmq stats consumer loop failed")
                _sleep(self.stop_event, settings.rabbitmq_reconnect_seconds)
            finally:
                if iterator is not None:
                    try:
                        iterator.close()
                    except Exception:
                        pass
                if channel is not None and getattr(channel, "is_open", False):
                    try:
                        channel.cancel()
                    except Exception:
                        pass
                _close_quietly(connection)


class RabbitMQCameraPipeline:
    def __init__(self) -> None:
        self.stop_event = threading.Event()
        self.publishers: list[CameraFramePublisher] = []
        self.inference_consumer = OccupancyInferenceConsumer(
            queue_name=settings.rabbitmq_frame_queue,
            stats_queue_name=settings.rabbitmq_stats_queue,
            stop_event=self.stop_event,
        )
        self.stats_consumer = OccupancyStatsConsumer(
            queue_name=settings.rabbitmq_stats_queue,
            stop_event=self.stop_event,
        )

    def start(self) -> None:
        cameras = _load_enabled_cameras()
        self.inference_consumer.start()
        self.stats_consumer.start()
        self.publishers = [
            CameraFramePublisher(
                camera=camera,
                queue_name=settings.rabbitmq_frame_queue,
                stop_event=self.stop_event,
            )
            for camera in cameras
        ]
        for publisher in self.publishers:
            publisher.start()
        logger.info(
            "rabbitmq camera pipeline started publishers=%s queue=%s",
            len(self.publishers),
            settings.rabbitmq_frame_queue,
        )

    def stop(self) -> None:
        self.stop_event.set()
        for publisher in self.publishers:
            publisher.join(timeout=5)
        self.inference_consumer.join(timeout=5)
        self.stats_consumer.join(timeout=5)
