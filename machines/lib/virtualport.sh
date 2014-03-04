#!/bin/sh

# virtualport.sh
#
# Create a virtual serial port on given port
# virtualport.sh <PORT>
#
# e.g.: virtualport.sh /dev/tty9
#
# On another terminal, run screen /dev/tty9 to interact with this port


socat -d - PTY,link=/dev/tty9

