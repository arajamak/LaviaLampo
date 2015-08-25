#!/usr/bin/python
import re, os,  time
import glob
import mysql.connector

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

query = ("SELECT devid, address, name,NOW() as datevalue FROM sensor")
cursor.execute(query)
sensors = dict()
datev=""

for row in cursor:
   sensors[str(row[1])] = str(row[0])
   datev=row[3]
   
print "Sensors from database:"
print sensors
print datev
base_dir='/sys/bus/w1/devices/'
# Devices can start also like 10-0008011225d2
# Devices can start also like 28-0000021ec696
#device_folder=glob.glob(base_dir + '28*')
device_folder=glob.glob(base_dir + '[0-9][0-9]-*')
print device_folder


def read_temp_raw(dev):
   f=open(dev, 'r')
   lines = f.readlines()
   f.close()
   return lines

for dev in device_folder:
   device_file=dev + '/w1_slave'
   #print device_file
   devid=re.match(base_dir+r"(.*)/w1_slave", device_file)
   device_id= devid.group(1)
   if(device_id not in sensors):
	print "Sensor not know skip: "+sensors[device_id]
	continue
   lines=read_temp_raw(device_file)
   #print "Dev " + dev + " lines:"
   #print lines
   if (lines[0].strip()[-3:] != 'YES'):
      lines=read_temp_raw(device_file)
   temp_line = lines[1]
   m = re.match(r"([0-9a-f]{2} ){9}t=([+-]?[0-9]+)", temp_line)
   if m.group(2) != 8500:
     temp = str(float(m.group(2)) /1000.0)
     if(sensors[device_id]):
     	print "insert with id: " + sensors[device_id]
     	print "insert with serial: " + device_id
        query = ("insert into temperatures (date,sensor,temp_c,sensor_serial) values ('"+str(datev)+"',"+sensors[device_id]+","+temp+",'"+device_id+"')")
        print query
        cursor.execute(query)
        cnx.commit()
     else:
        print "Sensor not found from database" 
       
cnx.close()
