# Huawei MateBook D14 (2024) — Intel i5-13420H — macOS Tahoe 26.x

OpenCore EFI for **Huawei MateBook D14 2024** (MCLG-XX) running **macOS Tahoe 26.7.x** with
working **Intel UHD (48 EU) Metal acceleration**.

This is a hobby config assembled and debugged on real hardware. It boots, it renders, it plays
audio. Read the *Known issues* section before you complain about the trackpad.

OpenCore EFI - macOS Tahoe on MateBook D14 2024 (i5-13420H, UHD 48EU, Metal working). i5-12450H (12th gen) version is still untested - test at your own risk.
> **12th-gen i5-12450H: still in testing — not verified. Use by you own risk.**
>**use by you own risk, if you device got brick or broken it no my problem fix it by you self**




---

## Hardware this was tested on

| Part | Model |
|---|---|
| Laptop | Huawei MateBook D14 (2025), MCLG-XX |
| CPU | Intel Core **i5-13420H** (Raptor Lake-P, 4P + 4E, 12 threads) |
| iGPU | Intel **UHD Graphics**, `8086:A7A8`, **48 EU / 6 L3 banks** (no Iris Xe) |
| RAM | 16 GB LPDDR4X-4267 (soldered) |
| SSD | WD PC SN740 512 GB NVMe |
| Display | 1920x1200 eDP, internal only |
| Audio | Conexant/Synaptics **SN6140** codec (`14F1:1F87`) on `8086:51CA` |
| Wi-Fi / BT | Intel **AX201** |
| Trackpad | FocalTech **BLTP7840** (`FTCS1000`), I²C HID on I2C0 `8086:51E8`, addr `0x2C` |
| Fingerprint | Goodix **GXFP5130** (eSPI) — see below |
| Camera | UVC USB webcam |

**macOS:** 26.7.2 (Tahoe) · **OpenCore:** 1.0.8 (`DBG-108-2026-09-27`)

---

## Status

| Feature | State | Notes |
|---|---|---|
| Boot / install | ✅ works | Needs the BIOS settings below |
| **Metal GPU acceleration** | ✅ works | 1536 MB reported, Quartz/CA compositing, window blur |
| Internal display | ✅ works | 1920x1200, backlight keys wired |
| Internal speaker | ✅ works | SN6140 via AppleALC + SimpleHDA |
| Internal microphone | ✅ works | Verifies at driver level (48 kHz, 2ch) |
| Internal keyboard | ✅ works | VoodooPS2 |
| **Brightness / volume / mute keys** | ✅ works | Fn keys via EC → PS/2 bridge (SSDT-HWFN) |
| Battery indicator | ✅ works | SMCBatteryManager |
| Wi-Fi (AX201) | ✅ works | AirportItlwm |
| Bluetooth | 🟡 firmware loads | Pairing not exhaustively tested |
| **Trackpad** | 🟡 unreliable | Enumerates and can work, but drops out — see *Known issues* |
| HDMI out | ❌ not working | TC2/legacy issue, unresolved |
| Fingerprint | ❌ impossible | No macOS driver exists for GXFP5130 |
| Sleep / wake | ⚠️ experimental | Hybrid Raptor Lake-P; may hang on wake |
| AirDrop / Handoff / iMessage | depends on your SMBIOS | needs your own serial + working Wi-Fi |

---

## Before you boot — BIOS

Enter BIOS with **F2**, then:

- **Secure Boot: Disabled** (required)
- **Fast Boot: Disabled**
- SATA / storage mode: **AHCI** (not RAID/RST)
- Disable **Intel VMD** if the option exists
- Keep the discrete-free iGPU-only mode (there is no dGPU on this model)
- Huawei hides DVMT settings; this EFI works **without** changing DVMT — do not try to
  unlock it with RU.efi/setup_var, the VarStore is write-protected on these boards

---

## Before you boot — SMBIOS (required)

The EFI ships with **blank** SMBIOS fields on purpose. Do not use anyone else's serial
(that gets both of you flagged by Apple).

1. Download [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS)
2. Run it, choose **`MacBookPro16,2`**, generate a set
3. Open `EFI/OC/config.plist` (ProperTree / OCAuxiliaryTools) and fill
   `PlatformInfo → Generic`:

| Key | Value |
|---|---|
| `SystemSerialNumber` | your generated serial |
| `MLB` | your generated MLB |
| `SystemUUID` | your generated UUID |
| `ROM` | your MAC address (6 bytes, hex) or any valid 6-byte value |

4. Keep `SystemProductName = MacBookPro16,2`, `Automatic = true`, `UpdateSMBIOSMode = Custom`
5. Reboot and **Reset NVRAM** once (SPACE at the OpenCore picker → Reset NVRAM entry)

> The CPU shows up as "Xeon W" and the GPU as "Intel HD Graphics" in About This Mac.
> That is cosmetic only — the SMBIOS model mapping and the GPU driver's display name.
> Your actual hardware is reported correctly at the kernel level.

---

## The GPU part (this is the interesting bit)

Apple never shipped a driver for Raptor Lake-P. This EFI runs a community backport
(**NootedGreen**) that makes Apple's Tiger Lake (Gen12 Xe-LP) Metal driver accept this chip.

Two things make it work and both are already set:

1. **Boot args match your actual EU count.**
   ```
   ngreen-eu=48 ngreen-l3=6
   ```
   - `i5-13420H` → **48 EU / 6 L3 bank**
   - `i5-1340P`   → 80 EU / 6 L3
   - `i7-1360P`   → 96 EU / 8 L3

   **If your chip has a different EU count, change these or you get artifacts / no acceleration.**
   Get the real number from Windows: Task Manager → Performance → GPU, or GPU-Z.

2. **The GMS patch.** Huawei's BIOS encodes Graphics Memory Size in 4 MB units (`0xF0–0xFE`,
   `0xFE` = 60 MB here). An unpatched driver reads that as `GMS × 32 MB` → gigabytes → overflows
   GTT → `AppleIntelController::start` fails → fake 3 MB GPU. The NootedGreen build in this EFI
   uses the XE-GMS4 fix and reports **1536 MB**.

Full boot-args used:

```
ngreen-eu=48 ngreen-l3=6 ngreenblmax=17741 ngreengammamask=0x7fffffff
-ngreentglwithgfx -allow3d -disablegfxfirmware ngreen-dmc=adlp -ngreenv189
-ngreenkeepefi -ngreenxefix -ngreenfixbootmode ngreenSched=4 ngreenV142=3
gfxrst=1 ngreengtfreq=1400
-vi2c-force-polling amfi_get_out_of_my_way=1
-v keepsyms=1 debug=0x100 msgbuf=1048576
```

Nothing here is tuned by magic — `-v keepsyms=1 debug=0x100 msgbuf=1048576` just keeps
verbose logs around for debugging. You can drop `-v` once you are happy.

### Which kext actually accelerates the GPU

Only **`NootedGreen.kext`** (v1.0.0, `MinKernel 25.0.0`) does the work here. That is the one
kext in this pack that must never be removed or disabled.

`WhateverGreen`, `WhateverXe` and `IntelIrisXe` were **not** used in this working configuration and
were deleted before publishing. If you see those names in other Huawei/13th-gen EFIs, they are
alternative approaches — loading `WhateverGreen` alongside `NootedGreen` breaks acceleration
because both attach to the same IGPU and fight over the framebuffer.

Supporting DeviceProperties on `PciRoot(0x0)/Pci(0x2,0x0)`:

| Key | Value | Why |
|---|---|---|
| `AAPL,ig-platform-id` | `0000499a` | Tiger Lake framebuffer ID (`0x9A490000`), must match the backport |
| `device-id` | `499a0000` | presents the iGPU as `0x9A49` (TGL) instead of `0xA7A8` (RPL) |
| `complete-modeset` | `01000000` | force the modeset path the backport expects |
| `force-online` | `01000000` | panel stays "online" when the driver probes |
| `framebuffer-patch-enable` | `01000000` | enables the framebuffer patches |
| `enable-max-pixel-clock-override` | `01000000` | allows the 1920x1200 eDP clock |
| `rps-control` | `01000000` | render power states — required, or the GPU sits at its lowest clock |

### Boot-args: keep vs trim

**Keep** — acceleration does not work without these:
`ngreen-eu=48 ngreen-l3=6`, `-allow3d`, `-disablegfxfirmware`, `ngreen-dmc=adlp`,
`gfxrst=1 ngreengtfreq=1400`, `-ngreenv189 -ngreenkeepefi -ngreenxefix -ngreenfixbootmode`,
`ngreenSched=4 ngreenV142=3`, `ngreenblmax=17741 ngreengammamask=0x7fffffff`,
`-ngreentglwithgfx`.

**Can be removed later** without touching the GPU driver — purely diagnostics:
`-v keepsyms=1 debug=0x100 msgbuf=1048576`.

**Do not remove** unless you know what you are doing:
`-vi2c-force-polling` (trackpad dies without polling),
`amfi_get_out_of_my_way=1` (audio and several kexts stop working).

---

## ACPI: what each SSDT does

| File | Purpose |
|---|---|
| `SSDT-PLUG-ALT.aml` | Creates `PLUG` CPU object so XCPM loads (native power management) |
| `SSDT-RTCAWAC.aml` | RTC / AWAC fix — macOS expects legacy RTC alarm |
| `SSDT-XOSI.aml` | `_OSI` → `XOSI` shim; required, the trackpad's `_CRS` hides its I²C descriptor unless OS > Win8 |
| `SSDT-EC-USBX.aml` | Fake embedded controller + USB power properties |
| `SSDT-PNLF.aml` | Backlight control device for the internal panel |
| `SSDT-TPDX.aml` | Moves the touchpad device out of `TPD0` and under `I2C0`, force-polling, 100 kHz |
| `SSDT-HWFN.aml` | Huawei EC hotkey → PS/2 scancode bridge (brightness `e005/e006`, mute `e020`, vol `e02e/e030`) |

`config.plist → ACPI → Patch` also contains the matching renames, including
`_Q0A/_Q0B/_Q0D/_Q0E/_Q0F → XQ0A…XQ0F` so the Huawei EC handlers don't double-fire.

---

## Kexts

| Kext | Role |
|---|---|
| Lilu | patching framework |
| VirtualSMC + SMCProcessor + SMCBatteryManager | SMC emulation, CPU sensors, battery |
| NootedGreen | **GPU acceleration backport** |
| AppleALC + SimpleHDA | audio (macOS 26 dropped AppleHDA; SimpleHDA replaces it) |
| VoodooPS2Controller (+Keyboard, +Mouse) | internal keyboard |
| VoodooI2C (+Services, +GPIO, +Input) + VoodooI2CHID | trackpad stack |
| BrightnessKeys | maps PS/2 brightness scancodes to display brightness |
| ECEnabler | reads battery EC fields wider than 8-bit |
| AirportItlwm | Intel Wi-Fi |
| IntelBluetoothFirmware + IntelBTPatcher + BlueToolFixup | Intel Bluetooth |

---

## Known issues

**Trackpad drops out.** The pad is a FocalTech BLTP7840 on a shared I²C bus. The GPIO interrupt
never reaches `VoodooGPIO` on this board, so this EFI forces polling (`-vi2c-force-polling`).
Polling plus occasional "lost arbitration" errors (I2C `TX_ABRT_SOURCE` bit 12) make the pointer
stutter or stop until the next reboot. Moving the bus down to 100 kHz (already done in
`SSDT-TPDX`) helps but does not eliminate it. **This is a genuine limitation, not a missing kext
flag.** If you find a fix, open an issue.

**Fingerprint sensor is dead weight.** It is a Goodix GXFP5130 on eSPI. macOS ties Touch ID to
the Secure Enclave / T2. There is no driver and no consumer for this chip — the "Add fingerprint"
UI will never appear. Nothing to fix here.

**HDMI.** Legacy TC2 path, not wired up in the backported driver. Internal display only.

**Sleep/wake.** Unstable on hybrid Raptor Lake-P. If you need reliability, disable sleep.

**Slight UI jank.** The backport's EU scheduling and command submission are not fully polished.
CPU power management is fine (XCPM active, no throttle — verify with `pmset -g therm`:
`CPU_Speed_Limit = 100`). Don't chase this with `CPUFriend`; a mismatched P-state provider on
Raptor Lake-P makes it worse.

**Microphone in apps.** `amfi_get_out_of_my_way=1` suppresses the TCC permission prompts, so some
apps show no mic row in Settings → Privacy. Grant manually if an app stays silent.

**USB ports.** This EFI deliberately ships **without** a custom USB map (`USBToolBox`/`UTBDefault`
were removed). The firmware's default map is used. If your USB ports sleep wrong or a port goes
dead after boot, add your own map with USBToolBox — but be aware a *wrong* map is worse than
no map, which is why it is not baked in here.

**Verbose boot is on** (`-v keepsyms=1`). Leave it on until everything works, then remove
`-v keepsyms=1 debug=0x100` from boot-args for a clean boot.

---

## Installation outline

1. Build a macOS 26 installer USB (AnyMac / `createinstallmedia` on another Mac).
2. Mount the USB EFI partition, copy this `EFI` folder onto it (merge `BOOT` and `OC`).
3. Fill in SMBIOS **before** first boot (see above) — this EFI ships with the fields blank on purpose.
4. Boot the USB, run the installer.
5. After install, copy the same `EFI` to the **internal** ESP (`diskutil list` → the EFI partition).
6. Reset NVRAM once after the first successful boot.

---

## Credits

This EFI stands on other people's work. If you fork it, keep the credits.

- **OpenCore** & **Lilu**, **VirtualSMC**, **AppleALC**, **WhateverGreen**, **VoodooPS2**, **VoodooI2C**, **AirportItlwm**, **IntelBluetoothFirmware** — Acidanthera and contributors
- **NootedGreen** — StezzaPilot, plus the GMS4 / XE-GMS4 patching work in the wider community
- **SimpleHDA** — the macOS 26 audio replacement path
- **olaf11071107** — [Hackintosh-Huawei-Matebook-D16-2024](https://github.com/olaf11071107/Hackintosh-Huawei-Matebook-D16-2024-iGPU-i5-13th-Gen), the closest sibling machine and the source of the TPDX / HWFN approach
- **bafcz** — [Raptor Lake HX EFI](https://github.com/bafcz/Hackintosh_LegionY9000P-IRX8_RaptorLake-HX) for 12th–14th gen trackpad interrupt research
- **JulioNectar** — [XPS13Plus IrisXe Tahoe](https://github.com/JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe) for the Tahoe-era Iris Xe stack

Different licenses apply to the bundled kexts and bootloader (mostly GPL-2.0 / APSL). This
configuration file set is shared as-is, **no warranty** — flashing an EFI can render a machine
unbootable. Keep a USB with a working EFI before you touch the internal ESP.
