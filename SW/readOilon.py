#!/usr/bin/python
import RPi.GPIO as GPIO
import time
import mysql.connector

GPIO.setmode(GPIO.BOARD)
print GPIO.VERSION

db_config = {
      'user': 'valvoja',
      'password': 'valvoja',
      'host': '127.0.0.1',
      'database': 'LAVIATEMP',
      'raise_on_warnings': True,
    }
try:
   cnx = mysql.connector.connect(**db_config)
except mysql.Error as err:
   print err.errno + " database error Exiting"
   exit.sys()

cursor = cnx.cursor()

query = ("SELECT devid, name,NOW() as datevalue FROM relays")
cursor.execute(query)
relays = dict()
names = dict()
st = {'ON':1, "OFF":0}
datev=""

for row in cursor:
   relays[str(row[1])] = str(row[0])
   names[str(row[0])] = str(row[1])
   datev=row[2]
   
print "Relays from database:"
print relays

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

query = ("insert into relaysstates (relay_state,date,state) values ('"+str(datev)+"',"+str(relays['POLTIN'])+","+str(st['poltin']) )
print query
cursor.execute(query)
cnx.commit()

cnx.close()

# prtint to log file
# POLTIN:0;ALARM:0;TIME:Sat Oct 13 19:55:01 2012

