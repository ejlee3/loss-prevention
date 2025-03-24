#!/bin/bash
#
# Copyright (C) 2024 Intel Corporation.
#
# SPDX-License-Identifier: Apache-2.0
#

INPUT_VIDEO_FILE_1="${INPUT_VIDEO_FILE_1:=1192116-sd_640_360_30fps.mp4}"
INPUT_VIDEO_FILE_2="${INPUT_VIDEO_FILE_2:=1192116-sd_640_360_30fps.mp4}"
INPUT_VIDEO_FILE_3="${INPUT_VIDEO_FILE_3:=1192116-sd_640_360_30fps.mp4}"
INPUT_VIDEO_FILE_4="${INPUT_VIDEO_FILE_4:=1192116-sd_640_360_30fps.mp4}"

GPU_DECODE_BIN="vapostproc ! video/x-raw(memory:VAMemory)"

# lp path
DETECTION_MODEL="/home/pipeline-server/models/object_detection/yolov8s/FP32/yolov8s.xml"
# dlstreamer path
# DETECTION_MODEL="/home/dlstreamer/intel/dl_streamer/models/public/yolov8s/FP16/yolov8s.xml"

OUTPUT_VIDEO_FILE_1="/tmp/results/multi_stream_CPU_1.mp4"
OUTPUT_VIDEO_FILE_2="/tmp/results/multi_stream_CPU_2.mp4"
OUTPUT_VIDEO_FILE_3="/tmp/results/multi_stream_CPU_3.mp4"
OUTPUT_VIDEO_FILE_4="/tmp/results/multi_stream_CPU_4.mp4"

#GST_DEBUG=1 GST_TRACERS="latency_tracer(flags=pipeline,interval=100)" gst-launch-1.0 rtsp://localhost:8554/camera_0 ! rtph264depay  ! decodebin force-sw-decoders=1 ! gvaattachroi mode=1 file-path=/home/pipeline-server/pipelines/roi.json ! gvadetect batch-size=0 model-instance-id=odmodel name=detection model=models/object_detection/yolov8s/FP32/yolov8s.xml device=CPU  inference-region=1 object-class=BASKET,BAGGING threshold=0.6 ! gvapython module=/home/pipeline-server/extensions/object_filter.py class=ObjectDetectionFilter kwarg="{\"class_ids\": \"46,39,47\", \"rois\": \"BASKET,BAGGING\"}" !  gvatrack ! gvametaaggregate name=aggregate ! gvametaconvert name=metaconvert add-empty-results=true ! gvapython module=/home/pipeline-server/extensions/gva_roi_metadata.py class=RoiMetadata kwarg="{\"rois\": \"BASKET,BAGGING\"}" ! gvametapublish method=mqtt file-format=2 address=127.0.0.1:1883 mqtt-client-id=yolov8 topic=event/detection ! queue ! gvametapublish name=destination file-format=2 file-path=/tmp/results/r20250319185452020611819_gst0.jsonl ! fpsdisplaysink video-sink=fakesink sync=true --verbose 2>&1 | tee >/tmp/results/gst-launch_20250319185452020611819_gst0.log >\(stdbuf -oL sed -n -e 's/^.*current: //p' | stdbuf -oL cut -d , -f 1 > /tmp/results/pipeline20250319185452020611819_gst0.log)


# Multi stream render mode optimized on GPU
# GST_DEBUG=1 GST_TRACERS="latency_tracer(flags=pipeline,interval=100)" gst-launch-1.0 \
# filesrc location="$INPUT_VIDEO_FILE_1" ! parsebin ! vah264dec ! video/x-raw\(memory:VAMemory\) ! \
# gvadetect model="$DETECTION_MODEL" model-proc=/opt/intel/dlstreamer/samples/gstreamer/model_proc/public/yolo-v8.json device=GPU pre-process-backend=va-surface-sharing nireq=4 model-instance-id=inf1 ! queue ! \
# gvawatermark ! gvafpscounter ! gvametaconvert ! queue ! videoconvert ! fpsdisplaysink video-sink=autovideosink sync=true --verbose \
# filesrc location="$INPUT_VIDEO_FILE_2" ! parsebin ! vah264dec ! video/x-raw\(memory:VAMemory\) ! \
# gvadetect model="$DETECTION_MODEL" model-proc=/opt/intel/dlstreamer/samples/gstreamer/model_proc/public/yolo-v8.json device=GPU pre-process-backend=va-surface-sharing nireq=4 model-instance-id=inf1 ! queue !  \
# gvawatermark ! gvafpscounter ! gvametaconvert ! queue ! videoconvert ! fpsdisplaysink video-sink=autovideosink sync=true --verbose \
# filesrc location="$INPUT_VIDEO_FILE_3" ! parsebin ! vah264dec ! video/x-raw\(memory:VAMemory\) ! \
# gvadetect model="$DETECTION_MODEL" model-proc=/opt/intel/dlstreamer/samples/gstreamer/model_proc/public/yolo-v8.json device=GPU pre-process-backend=va-surface-sharing nireq=4 model-instance-id=inf1 ! queue !  \
# gvawatermark ! gvafpscounter ! gvametaconvert ! queue ! videoconvert ! fpsdisplaysink video-sink=autovideosink sync=true --verbose


# Multi stream RTSP input render mode on GPU
gst-launch-1.0 \
$INPUT_VIDEO_FILE_1 ! rtph264depay ! parsebin ! vah264dec ! vapostproc ! video/x-raw\(memory:VAMemory\) ! \
gvadetect model="$DETECTION_MODEL"  device=GPU pre-process-backend=va batch_size=4 ! \
gvawatermark ! gvafpscounter ! videoconvert ! fpsdisplaysink video-sink=xvimagesink sync=false \
$INPUT_VIDEO_FILE_2 ! rtph264depay ! parsebin ! vah264dec ! vapostproc ! video/x-raw\(memory:VAMemory\) ! \
gvadetect model="$DETECTION_MODEL"  device=GPU pre-process-backend=va batch_size=4 ! \
gvawatermark ! gvafpscounter ! videoconvert ! fpsdisplaysink video-sink=xvimagesink sync=false \
$INPUT_VIDEO_FILE_3 ! rtph264depay ! parsebin ! vah264dec ! vapostproc ! video/x-raw\(memory:VAMemory\) ! \
gvadetect model="$DETECTION_MODEL"  device=GPU pre-process-backend=va batch_size=4 ! \
gvawatermark ! gvafpscounter ! videoconvert ! fpsdisplaysink video-sink=xvimagesink sync=false
