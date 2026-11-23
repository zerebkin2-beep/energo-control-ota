# EnergyControl OTA releases

Signed ESP32-C3 firmware releases for EnergyControl.

**No verified installable release published in this operation.** Each release requires compiled and tested `firmware.bin`, SHA-256 manifest, and signature from the private key matching the public key already installed on the device.

Separate targets: `ota-apartment` and `ota-lyceum-mobil`. Never use an unsigned build for unattended remote updates. The public lyceum website is not modified.


## HOME 0.3.28 candidate

- Target: ESP32-C3, `ota-apartment-v2`.
- Four Telegram notification styles and separate owner/group settings for power events, with an in-bot preview.
- Local build: 1,257,392 bytes. Nine host test suites passed. Hardware OTA has not been tested.
- The HOME Apps Script has matching connection-alert templates. Server style selection is configured separately until firmware-to-server synchronization is available.
- Status: unsigned candidate. The existing OTA channel and release assets have not been updated.
