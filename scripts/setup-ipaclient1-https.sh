#!/bin/bash
# Setup httpd with FreeIPA-managed SSL certificate on ipaclient1
# Run this as root on ipaclient1.int.lug after FreeIPA enrollment
set -e

DOMAIN="int.lug"
HOSTNAME="ipaclient1"
FQDN="${HOSTNAME}.${DOMAIN}"
ADMIN_PASSWORD="${1:-DemoPassword1!}"

echo "=== Installing httpd and mod_ssl ==="
dnf install -y httpd mod_ssl

echo "=== Creating index.html ==="
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>INTLUG FreeIPA Demo</title>
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        h1 {
            font-size: 3.5em;
            color: white;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            margin: 0;
        }
    </style>
</head>
<body>
    <h1>Hello INTLUG</h1>
</body>
</html>
EOF

echo "=== Authenticating as admin ==="
echo "${ADMIN_PASSWORD}" | kinit admin

echo "=== Verifying DNS record exists in FreeIPA ==="
# Check if A record exists from FreeIPA server's perspective
RECORD_CHECK=$(ipa dnsrecord-find ${DOMAIN} ${HOSTNAME} --type=A 2>/dev/null | grep "record name" || echo "not found")
if [[ "$RECORD_CHECK" == "not found" ]]; then
  echo "DNS record not yet registered, adding manually..."
  ipa dnsrecord-add ${DOMAIN} ${HOSTNAME} --a-rec=192.168.122.11
else
  echo "DNS record already exists"
fi

echo "=== Creating HTTP service in FreeIPA ==="
ipa service-add HTTP/${FQDN}

echo "=== Opening firewall ports ==="
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

echo "=== Requesting certificate with ipa-getcert ==="
mkdir -p /etc/pki/tls/private /etc/pki/tls/certs
ipa-getcert request \
  -k /etc/pki/tls/private/${HOSTNAME}.key \
  -f /etc/pki/tls/certs/${HOSTNAME}.crt \
  -K HTTP/${FQDN}

echo "=== Waiting for certificate issuance ==="
for i in {1..30}; do
  if [ -f /etc/pki/tls/certs/${HOSTNAME}.crt ]; then
    echo "Certificate issued!"
    break
  fi
  echo "Waiting... ($i/30)"
  sleep 2
done

if [ ! -f /etc/pki/tls/certs/${HOSTNAME}.crt ]; then
  echo "ERROR: Certificate not issued after 60 seconds"
  exit 1
fi

echo "=== Configuring Apache SSL ==="
sed -i "s|SSLCertificateFile .*|SSLCertificateFile /etc/pki/tls/certs/${HOSTNAME}.crt|" /etc/httpd/conf.d/ssl.conf
sed -i "s|SSLCertificateKeyFile .*|SSLCertificateKeyFile /etc/pki/tls/private/${HOSTNAME}.key|" /etc/httpd/conf.d/ssl.conf

echo "=== Starting Apache ==="
systemctl start httpd
systemctl enable httpd

echo ""
echo "=== Success! ==="
echo "Visit: https://${FQDN}"
echo "Certificate path: /etc/pki/tls/certs/${HOSTNAME}.crt"
echo "Private key path: /etc/pki/tls/private/${HOSTNAME}.key"
