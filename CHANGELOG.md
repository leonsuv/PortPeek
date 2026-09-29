# Changelog

## 1.1.0 — 2026-09-30

- TCP listeners and unconnected bound UDP sockets, including IPv4/IPv6 addresses.
- Filter protocol, bind scope, process, PID, address or custom port label.
- Pin frequently used ports and label services such as an API or local database.
- Capture a persistent baseline; see opened/closed sockets and export the change report.
- Choose five-, fifteen- or thirty-second refresh, or freeze with manual mode.
- Inspect a selected process command, user and elapsed time through the system `ps` tool.
- Copy an address or Terminal `lsof` command; open Activity Monitor.
- Export filtered CSV/JSON snapshots or copy JSON to the clipboard.
- Read-only CLI socket inventory with protocol, port and scope filters.
- System commands time out after eight seconds; no administrator access is requested.

## 1.0.0 — 2026-09-30

First public release.

- TCP port, process name, PID, listening address and bind scope in one table.
- Search by port, process, PID or address.
- Filter loopback and all-interface listeners.
- Automatic refresh every five seconds while the window is visible, plus ⌘R.
- IPv4 and IPv6 address handling.
- Copy a selected address or the visible list as JSON.
- Open Activity Monitor for further inspection.
