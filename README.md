# POS80 Thermal Receipt Printer Driver & Installer

Customized CUPS driver for POS80 (80mm) thermal receipt printers, pre-configured for production deployment across ticketing and POS workstations.

---

## Production Configuration Specifications

- **Printer Model:** Generic POS80 / ZJ-80 / STM32 Thermal Printer
- **Resolution:** 203 × 203 DPI
- **Head Width:** 576 dots (~72 mm printable area)
- **Imageable Area:** 8–212 pt (margins calibrated to prevent left/right clipping)
- **Default Paper Size:** `80 × 297 mm` (`X70MMY297MM`)
- **Auto-Cutter:** Enabled (`EndOfJob`)
- **Extra Feed:** None (`FeedWhere=None`)
- **Feed Distance:** 3 mm (`FeedDist=0feed3mm`, inactive while Extra Feed is None)
- **Blank Space at Page End:** False / None (`BlankSpace=False`)

---

## Quickstart: Fresh PC Installation (Ubuntu / Linux Mint / Debian)

Ensure the printer is connected via USB and turned on. Then run:

```bash
# 1. Clone this repository
git clone https://github.com/Prospect-Development-Team/pos80.git
cd pos80

# 2. Run the automated installer
sudo ./install-pos80.sh
```

The script automatically:
1. Installs all required packages (`cups`, `build-essential`, `cmake`, `libcups2-dev`, `libcupsimage2-dev`, `git`).
2. Starts and enables the CUPS service.
3. Compiles and installs the `rastertozj` CUPS filter and customized `zj80.ppd`.
4. Installs the dynamic auto-detect CUPS backend (`/usr/lib/cups/backend/pos80`).
5. Creates the `POS80` queue with device URI `pos80:/auto`, sets it as the system default, and applies tested production options.

---

## Verifying the Installation

Check printer status and default destination:
```bash
lpstat -p -d
```
Expected output:
```text
printer POS80 is idle. enabled since ...
system default destination: POS80
```

Check assigned device URI:
```bash
lpstat -v POS80
```
Expected output:
```text
device for POS80: pos80:/auto
```

Check printer options:
```bash
lpoptions -p POS80 -l | grep -E 'PageSize|CutMedia|Resolution|OptionCutter|FeedWhere|FeedDist|BlankSpace'
```
Expected output:
```text
PageSize/Media Size: X70MMY65MM X70MMY105MM X70MMY210MM *X70MMY297MM X70MMY3276MM Custom.WIDTHxHEIGHT
CutMedia/Cut Media: None EndOfPage *EndOfJob
Resolution/Resolution: *203x203dpi
OptionCutter/Cutter: False *True
FeedDist/Feed distance: *0feed3mm 1feed6mm 2feed9mm 3feed12mm 4feed15mm 5feed18mm 6feed21mm 7feed24mm 8feed27mm 9feed30mm 10feed33mm 11feed36mm 12feed39mm 13feed42mm 14feed45mm
FeedWhere/When to feed: *None AfterPage AfterJob
BlankSpace/Blank space at page's end: True *False
```

Check active PPD values:
```bash
sudo grep -E 'cupsModelNumber|ImageableArea' /etc/cups/ppd/POS80.ppd
```
Expected output:
```text
*cupsModelNumber: 576
*ImageableArea X70MMY297MM/80mm x 297mm: "8 0 212 842"
```

---

## Manual Installation (If Not Using the Script)

If you prefer installing step-by-step manually:

```bash
# 1. Install prerequisites
sudo apt update
sudo apt install -y cups cups-client build-essential cmake libcups2-dev libcupsimage2-dev git
sudo systemctl enable --now cups

# 2. Build and install filter, PPD, and dynamic backend
mkdir -p build && cd build
cmake ..
make
sudo make install
sudo cp ../zj80.ppd /usr/share/cups/model/zjiang/zj80.ppd
sudo cp ../backend-pos80 /usr/lib/cups/backend/pos80
sudo chmod 700 /usr/lib/cups/backend/pos80
sudo chown root:root /usr/lib/cups/backend/pos80
sudo systemctl restart cups

# 3. Create printer queue with dynamic auto-detect URI
sudo lpadmin -x POS80 2>/dev/null || true
sudo lpadmin -p POS80 -E -v "pos80:/auto" -P /usr/share/cups/model/zjiang/zj80.ppd

# 4. Apply default options
sudo lpadmin -p POS80 \
  -o PageSize=X70MMY297MM \
  -o CutMedia=EndOfJob \
  -o OptionCutter=True \
  -o FeedWhere=None \
  -o FeedDist=0feed3mm \
  -o BlankSpace=False

sudo cupsenable POS80
sudo cupsaccept POS80
sudo lpadmin -d POS80
sudo systemctl restart cups
```

---

## Upgrading Existing Printers

If a printer was previously configured with an older version of the driver, running `sudo ./install-pos80.sh` will automatically delete the old queue and recreate it with the updated PPD, avoiding any cached PPD conflicts.

---

## Firefox Printing Settings

When printing ticket PDFs from Firefox:
- **Destination:** `POS80`
- **Paper Size:** `80 × 297 mm`
- **Orientation:** `Portrait`
- **Margins:** `Default` or `None`
