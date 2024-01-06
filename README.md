SIGNALduino - 00_SIGNALduinoAdv.pm FHEM Module Version 3.5.x

======

Counterpart of SIGNALDuino uC, it's the code for FHEM to work with the data received from the uC


How to install
======
The Perl module can be loaded directly into your FHEM installation:

master version:
```update all https://raw.githubusercontent.com/Ralf9/SIGNALduinoAdv_FHEM/master/controls_ralf9_signalduino.txt```

Connect the Arduino via USB to your FHEM Server and define the device with it's new port:
Example: ```define SDuino SIGNALduinoAdv /dev/serial/by-id/usb-1a86_USB2.0-Serial-if00-port0@57600```
You have to adapt this to your environment.

If you made your setup with an Arduino Nano, you can use this command to load the firmware on your device:
set SDuino flash

If this fails, you may need to install avrdude on your system.
On a raspberry pi it is done via ```sudo apt-get install avrdude```

More Information
=====
Forum thread is at: https://forum.fhem.de/index.php/topic,111653.0.html
