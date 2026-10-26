# Major Features Preview 06.1 — Forward Aim and Pixel Music Garden

Released 27 October 2026 (Japan). Apple Silicon, macOS 14+.

[Download](https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.4/NULL-CHOIR-0.2.3-alpha.4-major-features-preview-06-1-Apple-Silicon.zip) · [Download page](https://null-choir.jaymoney.chatgpt.site/)

- ZIP: 289931781 bytes; SHA-256 `b65e081ea4d81c8a49728d8f465990c0aa2318b3d7a778084f4f6d699fc8a95a`.
- PCK SHA-256: `fc43c05bff0dabd9966f4ca3959fd9bd3cf5a87f92a544863058de36204e3b7c`.
- Package signing and launch qualification: The 64-bit Apple Silicon archive is Developer ID-signed, Apple-notarized and stapled; macOS Gatekeeper and isolated muted launch checks passed for this exact package.
- Export source: `4a5268e5b80bf937f5e2b0a0f8ce4ac6363ced4a`; merged source: `5e3032b0204809e994281ce7ede09f44424b6ee2`.
- Exact shared source tree: `088208959db676bfcb021df572a83ccc435e88d5`.
- Exact packaged-resource qualification: Eleven actual app/PCK checks passed, including the new Rivet/pixel-garden feature payloads and retained scene, audio and recovery contracts. The final archive passed fresh extraction, signature, ticket, Gatekeeper, ARM64/system-dependency and isolated muted startup checks. A separate local installation preserved earlier apps and did not read or change real user data.
- Public archive verification: The independently hashed final ZIP matches the actual GitHub release-asset digest and byte count. The public redirect returned HTTP 200 with the exact Content-Length. No redundant full download was performed.

## Delivered

**Forward-aiming Rivet Pistol.** The corrected native pose follows the firing axis instead of an inspection angle. All three idle/fire/recover poses are actual Blender renders from the retained editable source; the portable exporter reproduced the exact accepted atlas SHA-256 `9470e33b6c9a33127afb554a1848310c42d0cfd4bab1e05cbbe33a0495524618`. Actual HUD views retain the muzzle/crosshair registration. Native imported Texture2D pixels match the accepted source RGBA byte-for-byte. Weapon numbers, firing cadence, frame timing and hit logic are unchanged. The other five weapon designs and all eight gate assemblies remain frozen; their originals and existing source/ownership guards remain.

**Live Pixel Music Garden.** An original beetle, spring blob and antenna bird form a coherent palette-limited scene with stepped poses and crisp pixels. Decorative animation follows the actual owned Music playback clock. Real low/mid/high FFT bands and Music-bus peak supply bounded audio response; they are not detected beats, RMS or instrument estimates. No Tyrian code or assets are copied. The concept reference is construction guidance, not a static runtime image.

Existing track/volume/navigation controls, no-autoplay behavior and sole Music-player ownership remain. Normal unmuted pause holds phase and signal; mute/gain-zero clears audio response without advancing paused phase. Reduced motion immediately sets a neutral still. Hiding/closing the screen hides the actual ColorRect, stops its processing and retires its preview/analyzer; external Music ownership clears stale signal.

## Evidence and limits

Source/runtime qualification includes 55 unit tests, the complete 119-asset/140-export art contract, five affected native host tests, a real 16-frame combined UI sequence and actual native Texture2D import/pixel checks. The editable pistol source and portable exporter reproduced the exact accepted atlas; the original source and earlier art remain retained. These checks are distinct from the exact package/public-download qualifications recorded above.

This remains an incremental playable preview, not Alpha 4 or full-goal completion. No new human physical-input, audible-listening, music-fit, sustained-FPS, played-pacing or whole-campaign acceptance is claimed. Broader enemy/boss art, anatomical consequences, world staging and genuine native8K/editable chapter masters remain on the major-upgrade plan.

## Immediate rollback

[Preview 06 — Eight Living Thresholds](https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.4/NULL-CHOIR-0.2.3-alpha.4-major-features-preview-06-Apple-Silicon.zip) remains unchanged: 289,894,541 bytes; SHA-256 `79f8e2e3e90a5a987344bbbb97be4bd032e060db385ac2717ee172ee4df6ee16`; PCK SHA-256 `8d4b4c2dbf5d3289f081a666619fbb6a9d8c8cb4ec3cabddfdfe60484dfc6d60`.

Preview 05/04/03 and earlier rollback archives remain available. Existing user progress and macOS security protections are not replaced or disabled. Original code, assets and soundtrack remain governed by the project LICENSE and retained third-party notices.
