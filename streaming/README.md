# Local Video Streaming

This folder contains local MediaMTX streaming fixtures for the occupancy / CV
pipeline. The Docker Compose setup starts one MediaMTX server and one ffmpeg
publisher per video file.

## Video Files

Put local demo videos in:

```text
streaming/videos/
```

Expected filenames:

```text
stream1.mp4
stream2.mp4
stream3.mp4
stream4.mp4
```

The setup uses `stream1.mp4` to `stream4.mp4`.

These four fixture videos are allowed through the root `.gitignore` so the
streaming demo works after cloning the repository. Keep them short and
privacy-safe. Add larger or extra local videos only with Git LFS or a download
script.

## Start Four Streams

From the repository root:

```bash
docker compose --profile streaming up mediamtx stream1 stream2 stream3 stream4
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
ffmpeg -re -stream_loop -1 -i streaming/videos/stream1.mp4 \
  -an -vf "scale=640:360,fps=1" -r 1 \
  -c:v libx264 -profile:v baseline -level 3.1 \
  -preset ultrafast -tune zerolatency \
  -b:v 200k -bufsize 400k -g 30 \
  -f flv rtmp://127.0.0.1:1935/stream1
```

Inside Docker, ffmpeg publishes to `rtmp://mediamtx:1935/stream1` because
`mediamtx` is the Compose service name.

## Stop Streams

```bash
docker compose --profile streaming down
```
