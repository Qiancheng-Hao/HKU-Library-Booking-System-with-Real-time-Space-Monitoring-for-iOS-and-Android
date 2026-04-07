from __future__ import annotations

import base64
import json
import logging
import threading
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionLocal
from app.models.occupancy import CameraSource
from app.services.occupancy_cv_service import (
    decode_image_bytes,
    estimate_occupancy_from_frame,
    normalize_stream_url,
    save_occupancy_log,
)

logger = logging.getLogger(__name__)


def _import_pika():
    try:
        import pika
        from pika.exceptions import AMQPConnectionError
    except ImportError as exc:
        raise RuntimeError("pika is required for RabbitMQ camera capture.") from exc
    return pika, AMQPConnectionError


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
    try:
        resource.close()
    except Exception:
        pass


def _sleep(stop_event: threading.Event, seconds: float) -> None:
    stop_event.wait(max(0.0, float(seconds)))


def _build_message(camera: CameraStreamConfig, frame_bytes: bytes, captured_at: datetime) -> bytes:
    payload = {
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

        pika, AMQPConnectionError = _import_pika()
        connection = None
        channel = None
        capture = None

        while not self.stop_event.is_set():
            try:
                if connection is None or connection.is_closed:
                    connection = pika.BlockingConnection(
                        pika.URLParameters(settings.rabbitmq_url)
                    )
                    channel = connection.channel()
                    channel.queue_declare(queue=self.queue_name, durable=True)

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
                channel.basic_publish(
                    exchange="",
                    routing_key=self.queue_name,
                    body=body,
                    properties=pika.BasicProperties(
                        delivery_mode=2,
                        content_type="application/json",
                    ),
                )
                _sleep(self.stop_event, settings.camera_capture_interval_seconds)
            except AMQPConnectionError:
                logger.exception(
                    "rabbitmq publisher connection failed camera=%s",
                    self.camera.name,
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
    def __init__(self, *, queue_name: str, stop_event: threading.Event) -> None:
        super().__init__(name="occupancy-inference-consumer", daemon=True)
        self.queue_name = queue_name
        self.stop_event = stop_event

    def run(self) -> None:
        pika, AMQPConnectionError = _import_pika()

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

                messages_buffer = []
                last_flush_time = datetime.now()
                batch_size = 5
                flush_interval_seconds = 2.0

                for method_frame, _, body in iterator:
                    if self.stop_event.is_set():
                        break
                        
                    if method_frame is not None:
                        messages_buffer.append((method_frame, body))
                        
                    now = datetime.now()
                    if len(messages_buffer) >= batch_size or (messages_buffer and (now - last_flush_time).total_seconds() >= flush_interval_seconds):
                        try:
                            with SessionLocal() as db:
                                for mf, b in messages_buffer:
                                    payload = _parse_message(b)
                                    captured_at = datetime.fromisoformat(str(payload["captured_at"]))
                                    if captured_at.tzinfo is None:
                                        captured_at = captured_at.replace(tzinfo=timezone.utc)

                                    frame = decode_image_bytes(base64.b64decode(str(payload["image_base64"])))
                                    stats = estimate_occupancy_from_frame(
                                        frame=frame,
                                        location=str(payload["location"]),
                                        area=str(payload["area"]),
                                    )

                                    save_occupancy_log(
                                        db,
                                        location=str(payload["location"]),
                                        area=str(payload["area"]),
                                        stats=stats,
                                        source=str(payload["camera_name"]),
                                        frame_index=None,
                                        captured_at=captured_at,
                                    )
                                    camera = (
                                        db.execute(
                                            select(CameraSource).where(
                                                CameraSource.name == str(payload["camera_name"])
                                            )
                                        )
                                        .scalars()
                                        .first()
                                    )
                                    if camera is not None:
                                        camera.last_captured_at = captured_at
                                        db.add(camera)
                                db.commit()

                            # 批量 ack
                            for mf, _ in messages_buffer:
                                channel.basic_ack(delivery_tag=mf.delivery_tag)

                        except Exception:
                            logger.exception("rabbitmq inference consumer batch processing failed")
                            # 批量 nack，并丢弃这批（或者选择 requeue）
                            for mf, _ in messages_buffer:
                                channel.basic_nack(delivery_tag=mf.delivery_tag, requeue=False)
                        finally:
                            messages_buffer.clear()
                            last_flush_time = datetime.now()
            except AMQPConnectionError:
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


class RabbitMQCameraPipeline:
    def __init__(self) -> None:
        self.stop_event = threading.Event()
        self.publishers: list[CameraFramePublisher] = []
        self.consumer = OccupancyInferenceConsumer(
            queue_name=settings.rabbitmq_frame_queue,
            stop_event=self.stop_event,
        )

    def start(self) -> None:
        cameras = _load_enabled_cameras()
        self.consumer.start()
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
        self.consumer.join(timeout=5)
