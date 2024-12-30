# PPTPD API

Simple API for managing PPTP VPN server clients and port forwarding on Ubuntu Server.

## Features

- Automatic PPTPD installation and configuration
- REST API for managing VPN clients
- Automatic IP assignment (10.0.0.100+)
- Dynamic port forwarding (range 6000-7000)
- Auto-start on boot
- IP masquerading and forwarding
- Secure MSCHAP-v2 authentication

## Requirements

- Ubuntu Server 18.04 or later
- Root access
- Open ports: 1723 (PPTP), 5000 (API)

## Quick Install

```bash
# Clone repository
git clone https://github.com/dypras666/pptpd-api.git
cd pptpd-api

# Make installer executable
chmod +x install.sh

# Run installer
./install.sh
```

## API Documentation

### Add New Client
```bash
POST http://your-server:5000/api/client

Request Body:
{
    "username": "client1",
    "password": "strong-password",
    "callback_ip": "192.168.1.100"
}

Response:
{
    "username": "client1",
    "client_ip": "10.0.0.100",
    "forward_port": "6001",
    "callback_ip": "192.168.1.100"
}
```

### Remove Client
```bash
DELETE http://your-server:5000/api/client/{username}

Response:
{
    "message": "Client removed successfully"
}
```

## Service Management

### Check API Service Status
```bash
systemctl status pptp-api
```

### View API Logs
```bash
journalctl -u pptp-api -f
```

### Restart API Service
```bash
systemctl restart pptp-api
```

## File Locations

- API Script: `/root/pptp_api.py`
- PPTP Config: `/etc/pptpd.conf`
- PPP Options: `/etc/ppp/pptpd-options`
- Clients Config: `/etc/ppp/chap-secrets`
- IPTables Rules: `/etc/iptables.rules`
- Service Config: `/etc/systemd/system/pptp-api.service`

## Security Notes

1. The API server runs on port 5000 by default. Make sure to:
   - Use a firewall to restrict access
   - Set up SSL/TLS for API communication
   - Change default port if needed

2. Client IPs start from 10.0.0.100 and increment automatically

3. Port forwarding:
   - Uses range 6000-7000
   - Excludes system ports (80, 443, etc.)
   - Randomly assigned to avoid conflicts

## Contributing

Feel free to submit issues and pull requests.

## License

MIT License

## Author

sedotphp

## Support

For issues and feature requests, please use the GitHub issue tracker.