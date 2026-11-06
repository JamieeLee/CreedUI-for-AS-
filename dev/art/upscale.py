#!/usr/bin/env python3
"""Upscales the user's class bar pictures 4x with a super-resolution network (EDSR, through OpenCV's
dnn_superres), so the emblems, crests and rails cut from them stay sharp (1.21.7, asked for). Writes
<name>_x4.png beside each picture; cut_classes.py uses it when it is there.

Needs opencv-contrib (dnn_superres) and the EDSR_x4.pb model (from the EDSR_Tensorflow project:
raw.githubusercontent.com/Saafke/EDSR_Tensorflow/master/models/EDSR_x4.pb). It takes some minutes
on a CPU.

    python3 upscale.py <EDSR_x4.pb> source/class_bars.webp source/class_bars_first.webp
"""
import os
import sys
import time

import cv2

if not hasattr(cv2, "dnn_superres"):
    sys.exit("needs opencv-contrib (cv2.dnn_superres)")
sr = cv2.dnn_superres.DnnSuperResImpl_create()
sr.readModel(sys.argv[1])
sr.setModel("edsr", 4)
for src in sys.argv[2:]:
    t = time.time()
    out = sr.upsample(cv2.imread(src))
    dst = os.path.splitext(src)[0] + "_x4.png"
    cv2.imwrite(dst, out)
    print(dst, out.shape[1], "x", out.shape[0], round(time.time() - t), "s")
