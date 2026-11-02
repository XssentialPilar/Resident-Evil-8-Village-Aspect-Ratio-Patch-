## RE8Display 2.1.0

Independent REFramework plugin; the ZIP copies directly into the game root and contains only the plugin DLL, private configuration and required license notices. It does not replace dinput8.dll or shared settings.

- Automatic aspect/FOV correction and proportional screen-space GUI scaling use the actual output dimensions.
- The private ImGui menu opens with `;` and supports rebinding. FOV override uses degrees; the manual multiplier and 16:10 black-bar controls are removed.
- Exact shop/save driver handling covers Duke submenus and typewriter slot lists. The software cursor visual root is suppressed while native GUI input processing is retained.
- Added map dragging is deferred; map controls remain native.

Requires unmodified REFramework with plugin API 1.15 or newer. Remove the older bundled aspect patch first and disable any separate correction controlling the same camera/UI fields.

Validation: five native/ABI suites, 24 installation/recovery checks and 17 package checks pass, including 100,000 arbitrary canvas dimensions. Local runtime logs record 11 output resolutions and actual save/shop driver activation. Full visual validation on ultrawide/portrait displays and every third-party mod has not been performed; no universal no-conflict or zero-latency guarantee is made. See the source verification report for the detailed limits.
