from pathlib import Path

def hex_file_to_text(input_file, output_file):
    try:
        hex_data = Path(input_file).read_text()

        # Remove spaces and newlines
        hex_data = "".join(hex_data.split())

        text = bytes.fromhex(hex_data).decode(
            "utf-8",
            errors="replace"
        )

        Path(output_file).write_text(
            text,
            encoding="utf-8"
        )

        print(f"[+] Saved text to: {output_file}")

    except Exception as e:
        print(f"[!] Error: {e}")

hex_file_to_text(
    "input.hex",
    "output.txt"
)
