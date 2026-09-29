# PortPeek 1.0.0

A native Mac utility that connects local TCP listening ports to their owning processes. Find the development server occupying a port, inspect its bind address, and copy a clean snapshot.

- TCP port, process name, PID, listening address and bind scope in one table.
- Search by port, process, PID or address.
- Filter loopback and all-interface listeners.
- Automatic refresh every five seconds while the window is visible, plus ⌘R.
- IPv4 and IPv6 address handling.
- Copy a selected address or the visible list as JSON.
- Open Activity Monitor for further inspection.

Includes native Light/Dark/System appearance, a custom app icon, documentation and example screenshots.

**Download:** unzip `PortPeek-1.0.0-macos.zip` and move `PortPeek.app` to Applications. Apple Silicon only; deployment target macOS 13+, tested locally on macOS 27. Ad-hoc signed, not notarized; macOS may require approval in Privacy & Security. `SHA256SUMS.txt` verifies the ZIP.

Functional tests and signature validation run during the release build.
