# 🏠 Home Lab SSL Certificate Setup

Quick and easy guide to create your own Certificate Authority and secure all `*.at.home` services with SSL.

---

## 🚀 Quick Start

### 1️⃣ Generate Certificates

```bash
chmod +x 0_create_home_certificate_authority.sh
./0_create_home_certificate_authority.sh
```

This creates a `home-lab-certs/` folder with all necessary files.

---

## 📦 What You Get

| File | Purpose | Action |
|------|---------|--------|
| `IC-CA.crt` | 🔐 Your Certificate Authority | Import to **all devices** |
| `IC-CA.key` | 🔑 CA Private Key | **KEEP SECRET!** |
| `at.home.crt` | 📜 Wildcard Certificate | Upload to Nginx |
| `at.home.key` | 🔑 Certificate Private Key | Upload to Nginx |
| `at.home-fullchain.crt` | 📜 Full Chain (optional) | Some services need this |

---

## 📲 Install CA on Devices

> ⚠️ **Important:** Only install `IC-CA.crt`, NOT the service certificates!

### 🪟 Windows

1. Double-click `IC-CA.crt`
2. Click **Install Certificate**
3. Select **Local Machine** → Next
4. Choose **Place all certificates in the following store**
5. Click **Browse** → Select **Trusted Root Certification Authorities**
6. Click **Next** → **Finish**

### 🐧 Linux (Ubuntu/Debian)

```bash
sudo cp IC-CA.crt /usr/local/share/ca-certificates/home-lab-ca.crt
sudo update-ca-certificates
```

### 🐧 Linux (RHEL/CentOS/Fedora)

```bash
sudo cp IC-CA.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

### 🍎 macOS

1. Double-click `IC-CA.crt`
2. **Keychain Access** opens
3. Select **System** keychain
4. Find your certificate (Home Lab Root CA)
5. Double-click it → Expand **Trust** section
6. Set **When using this certificate:** to **Always Trust**
7. Close and enter your password

### 📱 Android

1. Copy `IC-CA.crt` to your phone
2. **Settings** → **Security** → **Encryption & credentials**
3. **Install a certificate** → **CA certificate**
4. Select `IC-CA.crt`
5. Name it "Home Lab CA"

### 📱 iOS

1. Email `IC-CA.crt` to yourself or use AirDrop
2. Tap the file → **Install Profile**
3. **Settings** → **General** → **About** → **Certificate Trust Settings**
4. Enable full trust for "Home Lab Root CA"

### 🦊 Firefox (if needed separately)

1. **Settings** → **Privacy & Security**
2. **Certificates** → **View Certificates**
3. **Authorities** tab → **Import**
4. Select `IC-CA.crt`
5. ✅ Check **Trust this CA to identify websites**

---

## 🌐 Setup Nginx Proxy Manager

### 1️⃣ Upload Certificate

1. **SSL Certificates** → **Add SSL Certificate**
2. **Custom**
3. Name: `Home Lab Wildcard`
4. Upload **Certificate Key:** `at.home.key`
5. Upload **Certificate:** `at.home.crt`
6. **Save**

### 2️⃣ Use in Proxy Hosts

For **every** `*.at.home` service:
1. Create/Edit Proxy Host
2. **SSL** tab → Select **Home Lab Wildcard**
3. ✅ **Force SSL**
4. ✅ **HTTP/2 Support**
5. ✅ **HSTS Enabled** (optional but recommended)
6. **Save**

---

## ✅ Verify It Works

1. Visit `https://pbs.at.home` (or any service)
2. Check the padlock 🔒 in browser
3. Should show **Secure** with no warnings
4. Certificate should be issued by "Home Lab Root CA"

---

## 🔄 Renewing Certificates

Your CA is valid for **10 years**, service certificate for **825 days (~2.3 years)**.

### When to renew:
- ⏰ Before service certificate expires (check in ~2 years)
- 🆕 When you want to change domains

### How to renew:

**Keep using the same CA** (so devices don't need reconfiguration):

```bash
cd home-lab-certs

# Generate new service certificate
openssl genrsa -out at.home-new.key 2048

openssl req -new -key at.home-new.key -out at.home.csr \
  -subj "/C=UA/ST=Poltava/L=Kremenchuk/O=Home Lab/CN=*.at.home"

cat > san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.at.home
DNS.2 = at.home
EOF

openssl x509 -req -in at.home.csr \
  -CA IC-CA.crt -CAkey IC-CA.key -CAcreateserial \
  -out at.home-new.crt -days 825 -sha256 \
  -extfile san.cnf -extensions v3_req

# Replace old files
mv at.home-new.key at.home.key
mv at.home-new.crt at.home.crt
rm at.home.csr san.cnf IC-CA.srl

# Upload new files to Nginx Proxy Manager
```

---

## 🔒 Security Best Practices

### ✅ DO:
- 🔐 Keep `IC-CA.key` **extremely secure** (offline backup recommended)
- 📁 Store certificates in a secure location
- 🔄 Renew service certificates before expiration
- 📋 Document where CA is installed

### ❌ DON'T:
- 🚫 Share `IC-CA.key` with anyone
- 🚫 Commit `IC-CA.key` to Git
- 🚫 Use this CA for public-facing services
- 🚫 Lose `IC-CA.key` (you'll need it for renewals)

---

## 🆘 Troubleshooting

### ❌ Browser shows "Not Secure"
- Verify CA is installed in **Trusted Root Certification Authorities** (not Personal/Other)
- Restart browser after CA installation
- Check certificate in browser - should show "Home Lab Root CA" as issuer

### ❌ Firefox doesn't trust certificate
- Firefox uses its own certificate store
- Must import CA separately in Firefox (see instructions above)

### ❌ Mobile device shows warning
- iOS: Enable trust in **Certificate Trust Settings** (Settings → General → About)
- Android: Verify CA installed as **CA certificate**, not user certificate

### ❌ Certificate expired
- Renew service certificate (see Renewing section above)
- CA valid for 10 years, service cert for ~2.3 years

### ❌ Lost `IC-CA.key`
- You'll need to start over and reinstall CA on all devices
- **Backup this file!**

---

## 📚 Additional Info

### Supported Services
This wildcard certificate works with:
- ✅ `pbs.at.home`
- ✅ `portainer.at.home`
- ✅ `who.at.home`, `where.at.home`
- ✅ **ANY** `*.at.home` subdomain

### Certificate Details
- **CA Valid:** 10 years (3650 days)
- **Service Cert Valid:** 825 days (~2.3 years)
- **Algorithm:** RSA 4096 (CA), RSA 2048 (service)
- **Hash:** SHA-256
- **Wildcard:** `*.at.home` + `at.home`

### Why 825 days?
- Apple/iOS requires certificates ≤ 825 days
- Following industry best practices
- Encourages regular renewal

---

## 🎉 You're Done!

Your home lab now has:
- 🔐 Proper SSL encryption
- ✅ No browser warnings
- 🌐 Works on all devices
- 🔄 Easy to manage and renew

Enjoy your secure home lab! 🏠✨