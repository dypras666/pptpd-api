# PPTPD API

Simple API untuk mengelola PPTP VPN server dan port forwarding pada Ubuntu Server.

## Fitur

- ✨ Setup otomatis PPTP Server
- 🚀 REST API untuk manajemen VPN client
- 🔄 Port forwarding otomatis
- 🎯 Random port assignment (6000-7000)
- 🔌 Auto-start pada boot
- 🛡️ IP masquerading dan forwarding
- 🔐 MSCHAP-v2 authentication

## Flow Sistem

```
[Public] -> Server:6123 -> VPN Client:80
   ^
   |
   └── Port 6123 adalah random port yang di-generate sistem
       Ketika ada request ke port 6123, akan di-forward ke 
       VPN client port 80
```

## Requirements

- Ubuntu Server 18.04+
- Root access
- Port terbuka:
  - 1723 (PPTP)
  - 5000 (API)

## Quick Install

```bash
# Clone repository
git clone https://github.com/dypras666/pptpd-api.git
cd pptpd-api

# Install
chmod +x install.sh
./install.sh
```

## API Documentation

### 1. Tambah Client VPN & Port Forward
```bash
POST http://your-server:5000/api/client

Request:
{
    "username": "client1",
    "password": "your-password",
    "destination_ip": "10.0.0.100",  # IP VPN client
    "port": 80                       # Port aplikasi di client
}

Response:
{
    "username": "client1",
    "client_ip": "10.0.0.100",      # IP VPN yang didapat client
    "requested_port": 80,           # Port yang diminta
    "backend_port": 6123,          # Random port yang di-generate
    "destination_ip": "10.0.0.100" # IP tujuan forward
}
```

### 2. Lihat Semua Port Mapping
```bash
GET http://your-server:5000/api/mappings

Response:
{
    "80": {
        "backend_port": 6123,
        "username": "client1",
        "destination_ip": "10.0.0.100"
    },
    "8080": {
        "backend_port": 6124,
        "username": "client2",
        "destination_ip": "10.0.0.101"
    }
}
```

### 3. Hapus Client
```bash
DELETE http://your-server:5000/api/client/{username}

Response:
{
    "message": "Client removed successfully"
}
```

## Contoh Penggunaan

1. Setup VPN & Port Forward untuk Web Server:
```bash
# Tambah client VPN dengan port forward 80
curl -X POST http://your-server:5000/api/client \
-H "Content-Type: application/json" \
-d '{
    "username": "webserver1",
    "password": "strong-pass",
    "destination_ip": "10.0.0.100",
    "port": 80
}'

# Sistem akan memberikan random port (misal 6123)
# Akses web server: http://your-server:6123
```

2. Setup Multiple Port untuk Satu Client:
```bash
# Forward port 80 (HTTP)
curl -X POST http://your-server:5000/api/client \
-d '{
    "username": "client1",
    "password": "pass123",
    "destination_ip": "10.0.0.100",
    "port": 80
}'

# Forward port 443 (HTTPS)
curl -X POST http://your-server:5000/api/client \
-d '{
    "username": "client1",
    "password": "pass123",
    "destination_ip": "10.0.0.100",
    "port": 443
}'
```

## File Lokasi

- API Script: `/root/pptp_api.py`
- PPTP Config: `/etc/pptpd.conf`
- Client Config: `/etc/ppp/chap-secrets`
- Port Mappings: `/root/port_mappings.json`
- Service Config: `/etc/systemd/system/pptp-api.service`

## Manajemen Service

```bash
# Cek status
systemctl status pptp-api

# Lihat log
journalctl -u pptp-api -f

# Restart service
systemctl restart pptp-api
```

## Keamanan

1. **Port Range**:
   - Random port: 6000-7000
   - Excluded ports: 80, 443, 21, 22, 25, 53

2. **IP Range**:
   - Server: 10.0.0.1
   - Clients: 10.0.0.100 - 10.0.0.200

3. **Best Practices**:
   - Gunakan strong password
   - Batasi akses ke port 5000 (API)
   - Setup SSL/TLS untuk API
   - Regular backup port_mappings.json

## Troubleshooting

1. Cek status VPN:
```bash
systemctl status pptpd
```

2. Cek port forwarding rules:
```bash
iptables -t nat -L -n -v
```

3. Cek IP forwarding:
```bash
sysctl net.ipv4.ip_forward
```

## Contributing

Feel free to submit issues dan pull requests.

## License

MIT License

## Author

dypras666