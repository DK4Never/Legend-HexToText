#!/usr/bin/env bash
set -e

cat > CyberHexTool.py <<'PY'
#!/usr/bin/env python3

import re
import difflib
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, scrolledtext

CYBER_BG = "#050816"
PANEL_BG = "#0b1026"
TEXT_BG = "#020617"
CYAN = "#22d3ee"
GREEN = "#39ff14"
PINK = "#ff2bd6"
WHITE = "#e5e7eb"
YELLOW = "#facc15"
RED = "#fb7185"

PLC_KEYWORDS = [
    "PLC", "HMI", "MODBUS", "PROFINET", "PROFIBUS", "ADS", "TwinCAT",
    "Siemens", "Beckhoff", "Recipe", "Counter", "Alarm", "Error",
    "Fault", "Motor", "Valve", "Sensor", "Input", "Output", "Speed",
    "Encoder", "Servo", "Drive", "Temperature", "Pressure", "Batch",
    "Shift", "Runtime", "Downtime", "Reject", "Carton", "Packet"
]

VERSION_PATTERNS = [
    r"\bV\d+(\.\d+)+\b",
    r"\bVersion[:\s]*[A-Za-z0-9._-]+",
    r"\bBuild[:\s]*[A-Za-z0-9._-]+",
    r"\bRevision[:\s]*[A-Za-z0-9._-]+",
    r"\bCODED\s+[0-9.]+",
    r"\bFirmware[:\s]*[A-Za-z0-9._-]+"
]


def read_bytes(path):
    return Path(path).read_bytes()


def detect_file_type(path):
    p = Path(path)
    raw = p.read_bytes()[:4096]
    text = raw.decode("utf-8", errors="ignore").strip()

    if text.startswith(":") and re.search(r"^:[0-9A-Fa-f]{8,}", text, re.M):
        return "Intel HEX Firmware"

    if re.search(r"^S[0-9][0-9A-Fa-f]+", text, re.M):
        return "Motorola S-Record Firmware"

    if text.startswith("<?xml") or "<Tc" in text or "<Project" in text:
        return "XML / Possible TwinCAT Project Artifact"

    if text.startswith("{") or text.startswith("["):
        return "JSON / Config Data"

    if b"\x00" in raw:
        return "Raw Binary"

    return "Plain Text / Unknown"


def intel_hex_to_binary(hex_text):
    binary = bytearray()
    upper_base = 0

    for line in hex_text.splitlines():
        line = line.strip()

        if not line.startswith(":"):
            continue

        try:
            length = int(line[1:3], 16)
            address = int(line[3:7], 16)
            record_type = int(line[7:9], 16)
            data_hex = line[9:9 + length * 2]

            if record_type == 0:
                binary.extend(bytes.fromhex(data_hex))
            elif record_type == 4:
                upper_base = int(data_hex, 16) << 16
            elif record_type == 1:
                break

        except Exception:
            continue

    return bytes(binary)


def extract_ascii_strings(data, min_length=4):
    results = []
    current = ""

    for byte in data:
        if 32 <= byte <= 126:
            current += chr(byte)
        else:
            if len(current) >= min_length:
                results.append(current)
            current = ""

    if len(current) >= min_length:
        results.append(current)

    return results


def make_hex_view(data, width=16, limit=65536):
    lines = []
    data = data[:limit]

    for offset in range(0, len(data), width):
        chunk = data[offset:offset + width]
        hex_part = " ".join(f"{b:02X}" for b in chunk)
        ascii_part = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
        lines.append(f"{offset:08X}  {hex_part:<48}  {ascii_part}")

    if len(data) >= limit:
        lines.append("\n[!] Hex preview limited to first 64 KB")

    return "\n".join(lines)


def scan_keywords(strings):
    hits = {}

    for keyword in PLC_KEYWORDS:
        matched = [s for s in strings if keyword.lower() in s.lower()]
        if matched:
            hits[keyword] = matched[:100]

    return hits


def find_versions(strings):
    found = []

    for s in strings:
        for pattern in VERSION_PATTERNS:
            if re.search(pattern, s, re.I):
                found.append(s)
                break

    return list(dict.fromkeys(found))


class CyberHexTool:
    def __init__(self, root):
        self.root = root
        self.root.title("Legend Cyber Hex / PLC Firmware Inspector")
        self.root.geometry("1250x780")
        self.root.configure(bg=CYBER_BG)

        self.file_path = None
        self.binary_data = b""
        self.strings = []
        self.output_text = ""

        self.build_ui()

    def cyber_button(self, parent, text, command, fg=CYAN):
        return tk.Button(
            parent,
            text=text,
            command=command,
            bg=PANEL_BG,
            fg=fg,
            activebackground=CYAN,
            activeforeground=CYBER_BG,
            relief="flat",
            padx=12,
            pady=6,
            font=("Consolas", 10, "bold")
        )

    def build_ui(self):
        title = tk.Label(
            self.root,
            text="⚡ LEGEND CYBER HEX / PLC FIRMWARE INSPECTOR ⚡",
            bg=CYBER_BG,
            fg=GREEN,
            font=("Consolas", 18, "bold")
        )
        title.pack(fill="x", pady=8)

        toolbar = tk.Frame(self.root, bg=PANEL_BG)
        toolbar.pack(fill="x", padx=10, pady=5)

        self.cyber_button(toolbar, "Open File", self.open_file).pack(side="left", padx=4)
        self.cyber_button(toolbar, "Auto Analyze", self.auto_analyze, GREEN).pack(side="left", padx=4)
        self.cyber_button(toolbar, "Extract Strings", self.extract_strings_action).pack(side="left", padx=4)
        self.cyber_button(toolbar, "Decode Intel HEX", self.decode_intel_hex_action, YELLOW).pack(side="left", padx=4)
        self.cyber_button(toolbar, "Hex Viewer", self.hex_viewer_action, PINK).pack(side="left", padx=4)
        self.cyber_button(toolbar, "Save Binary", self.save_binary_action, YELLOW).pack(side="left", padx=4)
        self.cyber_button(toolbar, "Export Report", self.export_report_action, GREEN).pack(side="left", padx=4)
        self.cyber_button(toolbar, "Compare File", self.compare_file_action, PINK).pack(side="left", padx=4)
        self.cyber_button(toolbar, "Clear", self.clear_output, RED).pack(side="left", padx=4)

        search_frame = tk.Frame(self.root, bg=CYBER_BG)
        search_frame.pack(fill="x", padx=10, pady=5)

        tk.Label(
            search_frame,
            text="Search:",
            bg=CYBER_BG,
            fg=CYAN,
            font=("Consolas", 11, "bold")
        ).pack(side="left")

        self.search_var = tk.StringVar()
        self.search_entry = tk.Entry(
            search_frame,
            textvariable=self.search_var,
            bg=TEXT_BG,
            fg=WHITE,
            insertbackground=GREEN,
            font=("Consolas", 11),
            relief="flat"
        )
        self.search_entry.pack(side="left", fill="x", expand=True, padx=8)

        self.cyber_button(search_frame, "Find", self.search_output, GREEN).pack(side="left")

        self.file_label = tk.Label(
            self.root,
            text="No file loaded",
            bg=CYBER_BG,
            fg=WHITE,
            anchor="w",
            font=("Consolas", 10)
        )
        self.file_label.pack(fill="x", padx=12)

        self.text_area = scrolledtext.ScrolledText(
            self.root,
            wrap=tk.NONE,
            bg=TEXT_BG,
            fg=GREEN,
            insertbackground=CYAN,
            selectbackground=PINK,
            selectforeground=WHITE,
            font=("Consolas", 10),
            relief="flat"
        )
        self.text_area.pack(fill="both", expand=True, padx=10, pady=10)

    def write_output(self, text):
        self.output_text = text
        self.text_area.delete("1.0", tk.END)
        self.text_area.insert(tk.END, text)

    def open_file(self):
        path = filedialog.askopenfilename(title="Select firmware / HEX / binary / PLC file")

        if not path:
            return

        self.file_path = Path(path)
        self.binary_data = self.file_path.read_bytes()
        detected = detect_file_type(self.file_path)

        self.file_label.config(
            text=f"Loaded: {self.file_path} | Type: {detected} | Size: {self.file_path.stat().st_size:,} bytes"
        )

        self.write_output(
            f"[+] Loaded: {self.file_path}\n"
            f"[+] Detected: {detected}\n"
            f"[+] Size: {self.file_path.stat().st_size:,} bytes\n\n"
            f"Use Auto Analyze for full inspection.\n"
        )

    def get_analysis_binary(self):
        detected = detect_file_type(self.file_path)

        if detected.startswith("Intel HEX"):
            text = self.file_path.read_text(errors="replace")
            return intel_hex_to_binary(text)

        return self.file_path.read_bytes()

    def auto_analyze(self):
        if not self.file_path:
            messagebox.showerror("Error", "No file loaded")
            return

        detected = detect_file_type(self.file_path)
        analysis_binary = self.get_analysis_binary()
        self.strings = extract_ascii_strings(analysis_binary)

        keyword_hits = scan_keywords(self.strings)
        versions = find_versions(self.strings)

        report = []
        report.append("═" * 80)
        report.append("LEGEND CYBER HEX / PLC FIRMWARE REPORT")
        report.append("═" * 80)
        report.append(f"File           : {self.file_path}")
        report.append(f"Detected Type  : {detected}")
        report.append(f"File Size      : {self.file_path.stat().st_size:,} bytes")
        report.append(f"Analysis Bytes : {len(analysis_binary):,}")
        report.append(f"Strings Found  : {len(self.strings):,}")
        report.append("")

        report.append("VERSION / BUILD CANDIDATES")
        report.append("-" * 80)
        if versions:
            report.extend(versions[:200])
        else:
            report.append("No obvious version strings found.")

        report.append("")
        report.append("PLC / INDUSTRIAL KEYWORD HITS")
        report.append("-" * 80)
        if keyword_hits:
            for key, values in keyword_hits.items():
                report.append(f"\n[{key}] {len(values)} preview hits")
                report.extend(f"  {v}" for v in values[:30])
        else:
            report.append("No PLC keyword hits found.")

        report.append("")
        report.append("ALL EXTRACTED STRINGS")
        report.append("-" * 80)
        report.extend(self.strings)

        self.write_output("\n".join(report))

    def extract_strings_action(self):
        if not self.file_path:
            messagebox.showerror("Error", "No file loaded")
            return

        data = self.file_path.read_bytes()
        self.strings = extract_ascii_strings(data)
        self.write_output("\n".join(self.strings))
        messagebox.showinfo("Done", f"Found {len(self.strings):,} strings")

    def decode_intel_hex_action(self):
        if not self.file_path:
            messagebox.showerror("Error", "No file loaded")
            return

        text = self.file_path.read_text(errors="replace")
        binary = intel_hex_to_binary(text)
        self.binary_data = binary
        self.strings = extract_ascii_strings(binary)

        output = [
            "[+] Intel HEX decoded",
            f"[+] Binary bytes: {len(binary):,}",
            f"[+] Strings found: {len(self.strings):,}",
            "",
            *self.strings
        ]

        self.write_output("\n".join(output))

    def hex_viewer_action(self):
        if not self.file_path:
            messagebox.showerror("Error", "No file loaded")
            return

        data = self.get_analysis_binary()
        self.write_output(make_hex_view(data))

    def save_binary_action(self):
        if not self.file_path:
            messagebox.showerror("Error", "No file loaded")
            return

        detected = detect_file_type(self.file_path)
        if not detected.startswith("Intel HEX"):
            messagebox.showwarning("Notice", "This is not detected as Intel HEX. Saving raw bytes instead.")

        data = self.get_analysis_binary()

        default_name = self.file_path.stem + ".bin"
        path = filedialog.asksaveasfilename(
            title="Save binary",
            initialfile=default_name,
            defaultextension=".bin",
            filetypes=[("Binary files", "*.bin"), ("All files", "*.*")]
        )

        if path:
            Path(path).write_bytes(data)
            messagebox.showinfo("Saved", f"Saved binary:\n{path}")

    def export_report_action(self):
        if not self.output_text:
            messagebox.showerror("Error", "No report/output to save")
            return

        default_name = "firmware_report.txt"
        if self.file_path:
            default_name = self.file_path.stem + "_report.txt"

        path = filedialog.asksaveasfilename(
            title="Export report",
            initialfile=default_name,
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt")]
        )

        if path:
            Path(path).write_text(self.output_text, encoding="utf-8")
            messagebox.showinfo("Saved", f"Report saved:\n{path}")

    def compare_file_action(self):
        if not self.file_path:
            messagebox.showerror("Error", "Open first file before compare")
            return

        other = filedialog.askopenfilename(title="Select second file to compare")

        if not other:
            return

        first_strings = extract_ascii_strings(self.get_analysis_binary())

        second_path = Path(other)
        second_type = detect_file_type(second_path)

        if second_type.startswith("Intel HEX"):
            second_data = intel_hex_to_binary(second_path.read_text(errors="replace"))
        else:
            second_data = second_path.read_bytes()

        second_strings = extract_ascii_strings(second_data)

        diff = difflib.unified_diff(
            first_strings,
            second_strings,
            fromfile=str(self.file_path),
            tofile=str(second_path),
            lineterm=""
        )

        self.write_output("\n".join(diff))

    def search_output(self):
        term = self.search_var.get().strip()

        if not term:
            return

        content = self.text_area.get("1.0", tk.END)
        lines = content.splitlines()

        matches = [
            f"{idx + 1}: {line}"
            for idx, line in enumerate(lines)
            if term.lower() in line.lower()
        ]

        if matches:
            self.write_output("\n".join(matches))
        else:
            messagebox.showinfo("Search", f"No matches for: {term}")

    def clear_output(self):
        self.output_text = ""
        self.text_area.delete("1.0", tk.END)


if __name__ == "__main__":
    root = tk.Tk()
    app = CyberHexTool(root)
    root.mainloop()
PY

cat > README.md <<'MD'
# Legend Cyber Hex / PLC Firmware Inspector

Cyber-themed local Python UI for inspecting:

- Intel HEX firmware
- Raw binary files
- PLC/HMI artifacts
- TwinCAT/Siemens config exports
- Embedded firmware files

## Features

- File type auto-detection
- Intel HEX decoding
- ASCII string extraction
- PLC keyword scanner
- Version/build finder
- Hex viewer
- Save decoded binary
- Export full report
- Compare two files
- Search output panel

## Install

```bash
cd ~/Legend/HexTOtext
chmod +x CyberHexTool.py
python3 CyberHexTool.py
