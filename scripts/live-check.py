#!/usr/bin/env python3
"""Verify the actual lsof reader against a temporary loopback listener."""
from pathlib import Path
import socket
import subprocess
app = Path(__file__).resolve().parents[1] / "dist/PortPeek.app/Contents/MacOS/PortPeek"
with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    subprocess.run([str(app), f"--check-port={listener.getsockname()[1]}"], check=True)
