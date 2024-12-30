#!/bin/bash

# Update system and install required packages
apt-get update
apt-get install -y pptpd iptables python3 python3-pip

# Install Python dependencies
pip3 install flask

# Configure IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure PPTPD
cat > /etc/pptpd.conf << EOL
option /etc/ppp/pptpd-options
logwtmp
localip 10.0.0.1
remoteip 10.0.0.100-200
EOL

# Configure PPP options
cat > /etc/ppp/pptpd-options << EOL
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
ms-dns 8.8.8.8
ms-dns 8.8.4.4
proxyarp
nodefaultroute
lock
nobsdcomp
novj
novjccomp
nologfd
EOL

# Setup iptables rules
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables-save > /etc/iptables.rules

# Make iptables rules persistent
cat > /etc/network/if-pre-up.d/iptables << EOL
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOL

chmod +x /etc/network/if-pre-up.d/iptables

# Create Python API file
cat > /root/pptp_api.py << EOL
$(cat << 'END_PYTHON'
import os
import json
import random
import string
import subprocess
from flask import Flask, request, jsonify
from ipaddress import IPv4Address, IPv4Network

app = Flask(__name__)

# Configuration
BASE_IP = "10.0.0.0/24"
CLIENT_START = 100
PORT_RANGE = (6000, 7000)
EXCLUDED_PORTS = {80, 443, 21, 22, 25, 53}
PORT_MAPPINGS_FILE = '/root/port_mappings.json'

def get_next_ip():
    """Generate next available IP address"""
    network = IPv4Network(BASE_IP)
    used_ips = get_used_ips()
    
    for ip in network.hosts():
        if int(str(ip).split('.')[-1]) >= CLIENT_START:
            if str(ip) not in used_ips:
                return str(ip)
    raise Exception("No available IPs")

def get_random_port():
    """Generate random available port"""
    used_ports = get_used_ports()
    while True:
        port = random.randint(PORT_RANGE[0], PORT_RANGE[1])
        if port not in used_ports and port not in EXCLUDED_PORTS:
            return port

def get_used_ips():
    """Get list of used IP addresses"""
    used_ips = set()
    try:
        with open('/etc/ppp/chap-secrets', 'r') as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    parts = line.split()
                    if len(parts) >= 4:
                        used_ips.add(parts[3])
    except FileNotFoundError:
        pass
    return used_ips

def get_used_ports():
    """Get list of used ports"""
    used_ports = set()
    try:
        with open(PORT_MAPPINGS_FILE, 'r') as f:
            mappings = json.load(f)
            for mapping in mappings.values():
                used_ports.add(mapping['backend_port'])
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    return used_ports

def load_port_mappings():
    """Load port mappings from file"""
    try:
        with open(PORT_MAPPINGS_FILE, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

def save_port_mappings(mappings):
    """Save port mappings to file"""
    with open(PORT_MAPPINGS_FILE, 'w') as f:
        json.dump(mappings, f, indent=4)

@app.route('/api/client', methods=['POST'])
def add_client():
    """Add new PPTP client with port forwarding"""
    data = request.json
    username = data.get('username')
    password = data.get('password')
    destination_ip = data.get('destination_ip')  # IP tujuan (IP VPN client)
    requested_port = data.get('port')  # Port yang diminta
    
    if not all([username, password, destination_ip, requested_port]):
        return jsonify({'error': 'Missing required fields'}), 400
    
    if not isinstance(requested_port, int):
        return jsonify({'error': 'Port must be a number'}), 400
    
    try:
        client_ip = get_next_ip()
        backend_port = get_random_port()  # Generate random port (6000-7000)
        
        # Add client to chap-secrets
        with open('/etc/ppp/chap-secrets', 'a') as f:
            f.write(f'"{username}" pptpd "{password}" {client_ip}\n')
        
        # Add port forwarding rule
        subprocess.run([
            'iptables', '-t', 'nat', '-A', 'PREROUTING',
            '-p', 'tcp', '--dport', str(backend_port),
            '-j', 'DNAT', '--to', f'{destination_ip}:{requested_port}'
        ], check=True)
        
        # Save iptables rules
        subprocess.run(['iptables-save', '>', '/etc/iptables.rules'], shell=True, check=True)
        
        # Update port mappings
        mappings = load_port_mappings()
        mappings[str(requested_port)] = {
            'backend_port': backend_port,
            'username': username,
            'destination_ip': destination_ip
        }
        save_port_mappings(mappings)
        
        return jsonify({
            'username': username,
            'client_ip': client_ip,
            'requested_port': requested_port,
            'backend_port': backend_port,
            'destination_ip': destination_ip
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/client/<username>', methods=['DELETE'])
def remove_client(username):
    """Remove PPTP client and its port forwarding rules"""
    try:
        # Remove from chap-secrets
        with open('/etc/ppp/chap-secrets', 'r') as f:
            lines = f.readlines()
        with open('/etc/ppp/chap-secrets', 'w') as f:
            for line in lines:
                if not line.startswith(f'"{username}"'):
                    f.write(line)
        
        # Remove port mappings for this user
        mappings = load_port_mappings()
        new_mappings = {
            port: mapping for port, mapping in mappings.items()
            if mapping['username'] != username
        }
        save_port_mappings(new_mappings)
        
        # Rebuild iptables rules
        subprocess.run(['iptables', '-t', 'nat', '-F'], check=True)  # Clear nat rules
        subprocess.run(['iptables', '-t', 'nat', '-A', 'POSTROUTING', '-o', 'eth0', '-j', 'MASQUERADE'], check=True)
        
        # Recreate port forwarding rules
        for port, mapping in new_mappings.items():
            subprocess.run([
                'iptables', '-t', 'nat', '-A', 'PREROUTING',
                '-p', 'tcp', '--dport', str(mapping['backend_port']),
                '-j', 'DNAT', '--to', f"{mapping['destination_ip']}:{port}"
            ], check=True)
        
        subprocess.run(['iptables-save', '>', '/etc/iptables.rules'], shell=True, check=True)
        
        return jsonify({'message': 'Client removed successfully'})
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/mappings', methods=['GET'])
def get_mappings():
    """Get all port mappings"""
    try:
        mappings = load_port_mappings()
        return jsonify(mappings)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
END_PYTHON
)
EOL

# Create systemd service for API
cat > /etc/systemd/system/pptp-api.service << EOL
[Unit]
Description=PPTP API Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/bin/python3 /root/pptp_api.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

# Enable and start the service
systemctl daemon-reload
systemctl enable pptp-api
systemctl start pptp-api

echo "Installation completed! API server is running on port 5000"
echo "PPTP API service has been enabled and will auto-start on boot"