#!/usr/bin/env python3
"""Exercise the released command surface with isolated fixtures; never touch user files."""
import json, pathlib, socket, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
NAME = ROOT.name
BINARY = ROOT / "dist" / (NAME + ".app") / "Contents/MacOS" / NAME

def run(*args, code=0):
    result = subprocess.run([str(BINARY), *args], capture_output=True, text=True, timeout=45)
    assert result.returncode == code, (args, result.returncode, result.stderr)
    return result.stdout

assert run("--help").strip()
with tempfile.TemporaryDirectory(prefix=NAME + "-CLI-check-") as tmp:
    root = pathlib.Path(tmp)
    for protocol,kind in [("TCP",socket.SOCK_STREAM),("UDP",socket.SOCK_DGRAM)]:
        with socket.socket(socket.AF_INET,kind) as listener:
            listener.bind(("127.0.0.1",0));port=listener.getsockname()[1]
            if protocol=="TCP":listener.listen(1)
            report=json.loads(run("list",f"--protocol={protocol}",f"--port={port}","--scope=loopback"))
            assert any(row["transport"]==protocol and row["port"]==port for row in report["listeners"])
            assert run("list",f"--protocol={protocol}",f"--port={port}","--format=csv").startswith("Protocol,Port,PID,Process,Address")
    run("list","--port=0",code=1)
print("PASS: " + NAME + " CLI integration checks")
