# EnergyControl OTA releases

Signed ESP32-C3 firmware releases for EnergyControl. The HOME and LYCEUM channels use separate OTA manifests. Each release requires a tested BIN, its SHA-256 manifest, and a signature matching the public key installed on the device.

## HOME 0.3.29 candidate

- ESP32-C3 target, `ota-apartment-v2`. BIN size: 1,257,600 bytes. Nine host test suites passed.
- Four Telegram styles with separate settings for the owner and group. The authenticated heartbeat synchronizes both styles with the HOME connection-alert server.
- HOME Apps Script version 32 is deployed. The production heartbeat handler and connection-alert trigger completed after the update.
- The candidate is unsigned. End-to-end style synchronization and device OTA still require a device running this candidate. The OTA release assets have not been changed.
