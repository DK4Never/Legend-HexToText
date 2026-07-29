def hex_to_text(hex_string: str) -> str:
    """
    Converts a hex string into readable text.
    Example:
    48656c6c6f -> Hello
    """

    # Remove spaces, new lines, and common prefixes
    cleaned_hex = (
        hex_string
        .replace(" ", "")
        .replace("\n", "")
        .replace("0x", "")
        .replace("\\x", "")
    )

    try:
        bytes_data = bytes.fromhex(cleaned_hex)
        return bytes_data.decode("utf-8")
    except ValueError:
        return "Invalid hex input."
    except UnicodeDecodeError:
        return "Hex converted, but it is not valid UTF-8 text."


def main():
    print("=== Hex to Text Converter ===")
    user_input = input("Enter hex value: ")

    result = hex_to_text(user_input)

    print("\nDecoded text:")
    print(result)


if __name__ == "__main__":
    main()
