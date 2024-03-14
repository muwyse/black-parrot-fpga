# SPDX-License-Identifier: BSD-3-Clause

import RPi.GPIO as GPIO
import time

GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)

GPIO.setup(17, GPIO.OUT)
GPIO.output(17, False)
print("Button Pressed")
time.sleep(0.4)

GPIO.setup(17, GPIO.IN)
print("Button Released")
