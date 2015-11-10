#!/usr/bin/python
import RPi.GPIO as GPIO
import time

GPIO.setmode(GPIO.BOARD)
print GPIO.VERSION

#set powersubly pin
# use + V directly from raspberry
data = 11
# set oilon pin
oilon = 13
# set warm resistor pin
resistor = 15

# Set data high to pin 11
GPIO.setup(data, GPIO.OUT)
# Read oilon from pin 13
GPIO.setup(oilon, GPIO.IN, pull_up_down=GPIO.PUD_UP)
# Read vastus from pin 15
GPIO.setup(resistor, GPIO.IN, pull_up_down=GPIO.PUD_UP)

poltin = 'OFF'
vastus = 'OFF'
# set data high
GPIO.output(data, True) 
time.sleep(2)
if (GPIO.input(oilon) == 0):
   poltin='ON' 
 
if (GPIO.input(resistor) == 0):
   vastus == 'ON' 

# set data low
GPIO.output(data, 0) 
GPIO.cleanup()

# Print result
print "OILON: " + poltin
print "VASTUS: " + vastus

# prtint to log file
# POLTIN:0;ALARM:0;TIME:Sat Oct 13 19:55:01 2012

