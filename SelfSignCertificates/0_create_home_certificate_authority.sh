#!/bin/bash

# 🏠 Home Lab Certificate Authority Generator
# Creates a CA and wildcard certificate for *.at.home

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🏠 Home Lab Certificate Authority Generator${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Create output directory
OUTPUT_DIR="home-lab-certs"
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo -e "${YELLOW}📂 Working directory: $(pwd)${NC}"
echo ""

# Step 1: Generate CA private key
echo -e "${GREEN}🔐 Step 1/4: Generating CA private key...${NC}"
openssl genrsa -out IC-CA.key 4096 2>/dev/null
echo -e "${GREEN}✅ CA private key created: IC-CA.key${NC}"
echo ""

# Step 2: Generate CA certificate
echo -e "${GREEN}📜 Step 2/4: Generating CA certificate...${NC}"
openssl req -x509 -new -nodes -key IC-CA.key \
  -sha256 -days 3650 -out IC-CA.crt \
  -subj "/C=UA/ST=Poltava/L=Kremenchuk/O=Home Lab/CN=Home Lab Root CA" 2>/dev/null
echo -e "${GREEN}✅ CA certificate created: IC-CA.crt (valid for 10 years)${NC}"
echo ""

# Step 3: Generate service private key
echo -e "${GREEN}🔑 Step 3/4: Generating wildcard certificate private key...${NC}"
openssl genrsa -out at.home.key 2048 2>/dev/null
echo -e "${GREEN}✅ Service private key created: at.home.key${NC}"
echo ""

# Step 4: Generate certificate signing request
echo -e "${GREEN}📝 Step 4/4: Generating and signing wildcard certificate...${NC}"

# Create CSR
openssl req -new -key at.home.key -out at.home.csr \
  -subj "/C=UA/ST=Poltava/L=Kremenchuk/O=Home Lab/CN=*.at.home" 2>/dev/null

# Create SAN configuration
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

# Sign the certificate with CA
openssl x509 -req -in at.home.csr \
  -CA IC-CA.crt -CAkey IC-CA.key -CAcreateserial \
  -out at.home.crt -days 825 -sha256 \
  -extfile san.cnf -extensions v3_req 2>/dev/null

echo -e "${GREEN}✅ Wildcard certificate created: at.home.crt (valid for 825 days)${NC}"
echo ""

# Cleanup temporary files
rm -f at.home.csr san.cnf IC-CA.srl

# Create certificate bundle (some services need this)
cat at.home.crt IC-CA.crt > at.home-fullchain.crt
echo -e "${GREEN}✅ Full chain certificate created: at.home-fullchain.crt${NC}"
echo ""

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 SUCCESS! All certificates generated!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📁 Generated files:${NC}"
echo -e "  ${BLUE}IC-CA.crt${NC}              - Import this to all your devices (Windows, Linux, Mac, phones)"
echo -e "  ${BLUE}at.home.crt${NC}           - Certificate for Nginx Proxy Manager"
echo -e "  ${BLUE}at.home.key${NC}           - Private key for Nginx Proxy Manager"
echo -e "  ${BLUE}at.home-fullchain.crt${NC} - Full chain (if needed by some services)"
echo ""

echo -e "${RED}⚠️  SECURITY WARNING:${NC}"
echo -e "  ${RED}IC-CA.key${NC} - Keep this file SECURE and PRIVATE! Anyone with this can create trusted certificates!"
echo ""

echo -e "${GREEN}📖 Next steps:${NC}"
echo -e "  1️⃣  Import ${BLUE}IC-CA.crt${NC} to all your devices (see README.md)"
echo -e "  2️⃣  Upload ${BLUE}at.home.crt${NC} and ${BLUE}at.home.key${NC} to Nginx Proxy Manager"
echo -e "  3️⃣  Use the certificate for all your *.at.home services"
echo ""

echo -e "${YELLOW}💾 All files saved in: $(pwd)${NC}"
echo ""