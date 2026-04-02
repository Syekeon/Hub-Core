import re
import socket
import struct
import sys

def inet_atoi(ipv4_str):
    return struct.unpack("!I", socket.inet_aton(ipv4_str))[0]

def inet_itoa(ipv4_int):
    return socket.inet_ntoa(struct.pack("!I", ipv4_int))

def ipv4_range(ipaddr):
    ipv4_str, port_str, cidr_str = re.match(r'([\d\.]+)(:\d+)?(/\d+)?', ipaddr).groups()
    ipv4_int = inet_atoi(ipv4_str)
    cidr_str = cidr_str or ''
    cidr_int = int(cidr_str[1:]) if cidr_str else 0
    ipv4_base = ipv4_int & (0xffffffff << (32 - cidr_int))
    return [inet_itoa(ipv4_base + val) for val in range(1 << (32 - cidr_int) + 2)]

nic = sys.argv[1]
print(ipv4_range(nic)[1])
