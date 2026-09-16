#!/usr/bin/env bash
set -e

# ==============================================================================
# POS80 Thermal Printer Automated Installer
# Target: Ubuntu / Linux Mint / Debian
# Configured for: 576 dots (~72mm), 8-212pt imageable area, auto-cutter EndOfJob
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: This installer must be run as root (or with sudo)."
  echo "    Usage: sudo ./install-pos80.sh [OPTIONAL_PRINTER_URI]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================================="
echo " Starting POS80 Driver & Queue Setup"
echo "=========================================================="

echo "[1/6] Installing dependencies (CUPS, build tools, cmake)..."
apt-get update -qq
apt-get install -y \
  cups \
  cups-client \
  build-essential \
  cmake \
  libcups2-dev \
  libcupsimage2-dev \
  git

echo "[2/6] Ensuring CUPS service is running..."
systemctl enable --now cups
systemctl restart cups

echo "[3/6] Compiling rastertozj filter and installing driver..."
rm -rf "$SCRIPT_DIR/build"
mkdir -p "$SCRIPT_DIR/build"
cd "$SCRIPT_DIR/build"

cmake ..
make -j"$(nproc 2>/dev/null || echo 1)"
make install

# Guarantee our pre-customized zj80.ppd is in place
mkdir -p /usr/share/cups/model/zjiang
cp -f "$SCRIPT_DIR/zj80.ppd" /usr/share/cups/model/zjiang/zj80.ppd
chmod 644 /usr/share/cups/model/zjiang/zj80.ppd

if [ -f "/usr/lib/cups/filter/rastertozj" ]; then
  chmod 755 /usr/lib/cups/filter/rastertozj
  chown root:root /usr/lib/cups/filter/rastertozj
fi

systemctl restart cups
cd "$SCRIPT_DIR"

echo "[4/6] Detecting connected POS80 USB printer..."
PRINTER_URI="$1"

if [ -z "$PRINTER_URI" ]; then
  # Auto-detect specifically recognized POS80 thermal printer signatures
  PRINTER_URI=$(lpinfo -v 2>/dev/null | grep -i '^direct usb://' | grep -iE 'STM32|Zjiang|AST|POS|Thermal' | head -n1 | awk '{print $2}')
fi

if [ -z "$PRINTER_URI" ]; then
  echo ""
  echo "[!] WARNING: No recognized POS80 thermal printer was automatically detected."
  echo "    Driver filter and PPD have been successfully compiled and installed."
  echo ""
  echo "    Attached USB printer devices found:"
  lpinfo -v 2>/dev/null | grep -i '^direct usb://' || echo "    (None found - ensure printer is powered on and connected)"
  echo ""
  echo "    To complete setup, run:"
  echo "      sudo ./install-pos80.sh '<PRINTER_URI>'"
  echo "    Example:"
  echo "      sudo ./install-pos80.sh 'usb://STMicroelectronics/STM32%20Virtual%20COM%20Port%20%20?serial=1A6422250000'"
  exit 0
fi

echo "    Detected Printer URI: $PRINTER_URI"

echo "[5/6] Creating & configuring 'POS80' printer queue..."
# Remove any existing POS80 queue to prevent stale/cached PPD conflicts
lpadmin -x POS80 2>/dev/null || true

# Register printer with our customized PPD
lpadmin -p POS80 -E -v "$PRINTER_URI" -P /usr/share/cups/model/zjiang/zj80.ppd

# Apply tested production settings
lpadmin -p POS80 \
  -o PageSize=X70MMY297MM \
  -o CutMedia=EndOfJob \
  -o OptionCutter=True \
  -o FeedWhere=None \
  -o FeedDist=0feed3mm \
  -o BlankSpace=False

cupsenable POS80
cupsaccept POS80
lpadmin -d POS80

systemctl restart cups

echo "[6/6] Verifying POS80 configuration..."
ACTIVE_PPD="/etc/cups/ppd/POS80.ppd"
ACTIVE_MODEL="Not found"
ACTIVE_AREA="Not found"

if [ -f "$ACTIVE_PPD" ]; then
  ACTIVE_MODEL=$(grep 'cupsModelNumber' "$ACTIVE_PPD" | tr -d '\r\n')
  ACTIVE_AREA=$(grep 'ImageableArea X70MMY297MM' "$ACTIVE_PPD" | tr -d '\r\n')
fi

echo ""
echo "=========================================================="
echo " POS80 Installation Completed Successfully!"
echo "=========================================================="
echo " Queue Name:       POS80 (System Default)"
echo " Device URI:       $PRINTER_URI"
echo " Filter:           /usr/lib/cups/filter/rastertozj"
echo " Configuration:    $ACTIVE_MODEL"
echo " Printable Area:   $ACTIVE_AREA"
echo " Paper Size:       80 x 297 mm"
echo " Auto-cutter:      Enabled (End of Job)"
echo " Blank Space:      Disabled"
echo " Extra Feed:       None"
echo "=========================================================="
echo "You can now test printing directly from Firefox or your application."
