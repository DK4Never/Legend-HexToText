#!/usr/bin/env python3

import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext
from pathlib import Path


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


def intel_hex_to_binary_text(hex_text):
    binary = bytearray()

    for line in hex_text.splitlines():
        line = line.strip()

        if not line.startswith(":"):
            continue

        try:
            length = int(line[1:3], 16)
            record_type = int(line[7:9], 16)
            data = line[9:9 + length * 2]

            if record_type == 0:
                binary.extend(bytes.fromhex(data))

        except Exception:
            continue

    return bytes(binary)


class HexToolUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Legend Hex / Firmware Text Tool")
        self.root.geometry("1000x700")

        self.file_path = None
        self.output_text = ""

        self.build_ui()

    def build_ui(self):
        top = tk.Frame(self.root)
        top.pack(fill="x", padx=10, pady=10)

        tk.Button(top, text="Open File", command=self.open_file).pack(side="left", padx=5)
        tk.Button(top, text="Extract Strings", command=self.extract_strings).pack(side="left", padx=5)
        tk.Button(top, text="Decode Intel HEX", command=self.decode_intel_hex).pack(side="left", padx=5)
        tk.Button(top, text="Save Output", command=self.save_output).pack(side="left", padx=5)
        tk.Button(top, text="Clear", command=self.clear_output).pack(side="left", padx=5)

        self.file_label = tk.Label(self.root, text="No file loaded", anchor="w")
        self.file_label.pack(fill="x", padx=10)

        self.text_area = scrolledtext.ScrolledText(self.root, wrap=tk.WORD)
        self.text_area.pack(fill="both", expand=True, padx=10, pady=10)

    def open_file(self):
        path = filedialog.askopenfilename(
            title="Select HEX / BIN / PLC file",
            filetypes=[
                ("All files", "*.*"),
                ("HEX files", "*.hex *.HEX"),
                ("Binary files", "*.bin *.BIN"),
                ("Text files", "*.txt *.TXT"),
            ]
        )

        if path:
            self.file_path = Path(path)
            self.file_label.config(text=f"Loaded: {self.file_path}")
            self.text_area.delete("1.0", tk.END)
            self.text_area.insert(tk.END, f"[+] Loaded file:\n{self.file_path}\n")

    def extract_strings(self):
        if not self.file_path:
            messagebox.showerror("Error", "No file loaded")
            return

        data = self.file_path.read_bytes()
        strings = extract_ascii_strings(data)

        self.output_text = "\n".join(strings)

        self.text_area.delete("1.0", tk.END)
        self.text_area.insert(tk.END, self.output_text)

        messagebox.showinfo("Done", f"Found {len(strings)} strings")

    def decode_intel_hex(self):
        if not self.file_path:
            messagebox.showerror("Error", "No file loaded")
            return

        hex_text = self.file_path.read_text(errors="replace")
        binary = intel_hex_to_binary_text(hex_text)
        strings = extract_ascii_strings(binary)

        self.output_text = "\n".join(strings)

        self.text_area.delete("1.0", tk.END)
        self.text_area.insert(tk.END, self.output_text)

        messagebox.showinfo(
            "Done",
            f"Decoded Intel HEX\nBinary bytes: {len(binary)}\nStrings found: {len(strings)}"
        )

    def save_output(self):
        if not self.output_text:
            messagebox.showerror("Error", "No output to save")
            return

        path = filedialog.asksaveasfilename(
            title="Save output",
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt")]
        )

        if path:
            Path(path).write_text(self.output_text, encoding="utf-8")
            messagebox.showinfo("Saved", f"Saved to:\n{path}")

    def clear_output(self):
        self.output_text = ""
        self.text_area.delete("1.0", tk.END)


if __name__ == "__main__":
    root = tk.Tk()
    app = HexToolUI(root)
    root.mainloop()
