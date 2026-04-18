# Video Streaming

This folder contains MediaMTX streaming setup notes for the occupancy / CV
pipeline. The Docker Compose setup starts one MediaMTX server and one ffmpeg
publisher per video source.

## Video Files

The default streaming profile reads the four demo videos from TOS, so the
repository does not need to store large `.mp4` fixtures:

```text
https://fyp.tos-cn-hongkong.volces.com/stream1.mp4
https://fyp.tos-cn-hongkong.volces.com/stream2.mp4
https://fyp.tos-cn-hongkong.volces.com/stream3.mp4
https://fyp.tos-cn-hongkong.volces.com/stream4.mp4
```

For local-only testing, place matching files in `streaming/videos/` and run
Compose with `docker-compose.local-videos.yml`. The `.mp4` files are ignored by
Git.

```text
streaming/videos/stream1.mp4
streaming/videos/stream2.mp4
streaming/videos/stream3.mp4
streaming/videos/stream4.mp4
```

If the hosted URLs are slow or unreachable from your network, download the
videos first and use the local override:

```bash
curl -L https://fyp.tos-cn-hongkong.volces.com/stream1.mp4 -o streaming/videos/stream1.mp4
curl -L https://fyp.tos-cn-hongkong.volces.com/stream2.mp4 -o streaming/videos/stream2.mp4
curl -L https://fyp.tos-cn-hongkong.volces.com/stream3.mp4 -o streaming/videos/stream3.mp4
curl -L https://fyp.tos-cn-hongkong.volces.com/stream4.mp4 -o streaming/videos/stream4.mp4
```

## Start Four Streams

From the repository root:

```bash
docker compose --profile streaming up mediamtx stream1 stream2 stream3 stream4
```

To use local video files instead of the TOS URLs:

```bash
docker compose -f docker-compose.yml -f docker-compose.local-videos.yml --profile streaming up mediamtx stream1 stream2 stream3 stream4
```

Stream URLs:

```text
rtmp://127.0.0.1:1935/stream1
rtmp://127.0.0.1:1935/stream2
rtmp://127.0.0.1:1935/stream3
rtmp://127.0.0.1:1935/stream4

rtsp://127.0.0.1:8554/stream1
rtsp://127.0.0.1:8554/stream2
rtsp://127.0.0.1:8554/stream3
rtsp://127.0.0.1:8554/stream4

http://127.0.0.1:8889/stream1
http://127.0.0.1:8889/stream2
http://127.0.0.1:8889/stream3
http://127.0.0.1:8889/stream4
```

## Match The Old Manual Command

The `stream1` service is equivalent to running MediaMTX and then pushing:

```bash
ffmpeg -re -stream_loop -1 -i https://fyp.tos-cn-hongkong.volces.com/stream1.mp4 \
  -an -vf "fps=1,scale=1280:720" -r 1 \
  -c:v libx264 -profile:v baseline -level 4.0 \
  -preset ultrafast -tune zerolatency \
  -b:v 1500k -bufsize 3000k -g 10 \
  -f flv rtmp://127.0.0.1:1935/stream1
```

Inside Docker, ffmpeg publishes to `rtmp://mediamtx:1935/stream1` because
`mediamtx` is the Compose service name.

## Stop Streams

```bash
docker compose --profile streaming down
```
