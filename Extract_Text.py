#!/usr/bin/env python3

import argparse
from pathlib import Path


def extract_strings(data, min_length=4):
    strings = []
    current = ""

    for byte in data:
        if 32 <= byte <= 126:
            current += chr(byte)
        else:
            if len(current) >= min_length:
                strings.append(current)
            current = ""

    if len(current) >= min_length:
        strings.append(current)

    return strings


def main():
    parser = argparse.ArgumentParser(
        description="Extract readable strings from binary files"
    )

    parser.add_argument(
        "input_file",
        help="File to analyze"
    )

    parser.add_argument(
        "-o",
        "--output",
        default="extracted_strings.txt"
    )

    parser.add_argument(
        "-m",
        "--min-length",
        type=int,
        default=4
    )

    args = parser.parse_args()

    try:
        data = Path(args.input_file).read_bytes()

        strings = extract_strings(
            data,
            args.min_length
        )

        Path(args.output).write_text(
            "\n".join(strings),
            encoding="utf-8"
        )

        print(f"[+] Found {len(strings)} strings")
        print(f"[+] Saved to {args.output}")

    except Exception as e:
        print(f"[!] Error: {e}")


if __name__ == "__main__":
    main()
