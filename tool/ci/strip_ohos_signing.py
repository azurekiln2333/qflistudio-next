#!/usr/bin/env python3
"""Remove signing entries from an OHOS project build profile.

Usage: python3 tool/ci/strip_ohos_signing.py ohos/build-profile.json5

The tracked profile names a local key store that no hosted runner has. Hvigor
then fails while it signs the HAP. This script removes app.signingConfigs and
each product's signingConfig, so hvigor stops after the unsigned HAP.

Run it on a CI working copy only. Never commit the stripped profile.

Exit codes: 0 done or nothing to remove, 1 unreadable or unexpected profile,
2 wrong usage. The file stays untouched on every failure.
"""

import json
import os
import sys
import tempfile


class ProfileError(Exception):
    """The profile cannot be parsed or has an unexpected structure."""


def json5_to_json(text):
    """Convert the JSON5 subset hvigor profiles use into strict JSON.

    Handles // and /* */ comments, trailing commas and single-quoted strings.
    Anything else, such as an unquoted key, is left for json.loads to reject.
    """
    out = []
    i = 0
    length = len(text)
    while i < length:
        char = text[i]
        if char in ('"', "'"):
            quote = char
            i += 1
            chunk = []
            while True:
                if i >= length:
                    raise ProfileError("unterminated string")
                char = text[i]
                if char == "\\":
                    if i + 1 >= length:
                        raise ProfileError("unterminated escape sequence")
                    following = text[i + 1]
                    # \' is valid JSON5 but not JSON. A bare quote is enough.
                    chunk.append("'" if following == "'" else char + following)
                    i += 2
                    continue
                if char == quote:
                    i += 1
                    break
                if char == "\n":
                    raise ProfileError("line break inside a string")
                # A double quote inside a single-quoted string needs an escape.
                chunk.append('\\"' if char == '"' else char)
                i += 1
            out.append('"' + "".join(chunk) + '"')
        elif text.startswith("//", i):
            end = text.find("\n", i)
            i = length if end < 0 else end
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                raise ProfileError("unterminated block comment")
            i = end + 2
        elif char in "}]":
            # Drop a trailing comma before the closing bracket.
            j = len(out) - 1
            while j >= 0 and out[j].isspace():
                j -= 1
            if j >= 0 and out[j] == ",":
                del out[j]
            out.append(char)
            i += 1
        else:
            out.append(char)
            i += 1
    return "".join(out)


def parse_profile(text):
    """Return (profile, was_strict_json)."""
    try:
        return json.loads(text), True
    except ValueError:
        pass
    try:
        return json.loads(json5_to_json(text)), False
    except ValueError as error:
        raise ProfileError("not JSON or supported JSON5: %s" % error) from error


def strip_signing(profile):
    """Remove signing entries in place. Return a list of removal notes."""
    if not isinstance(profile, dict):
        raise ProfileError("the top level is not an object")
    app = profile.get("app")
    if not isinstance(app, dict):
        raise ProfileError("'app' is missing or is not an object")

    removed = []
    if "signingConfigs" in app:
        configs = app.pop("signingConfigs")
        names = []
        if isinstance(configs, list):
            for config in configs:
                # Report names only. Never echo key store material.
                name = config.get("name") if isinstance(config, dict) else None
                names.append(str(name) if name is not None else "<unnamed>")
        removed.append(
            "app.signingConfigs (%d: %s)" % (len(names), ", ".join(names) or "none")
        )

    products = app.get("products", [])
    if not isinstance(products, list):
        raise ProfileError("'app.products' is not a list")
    for index, product in enumerate(products):
        if not isinstance(product, dict):
            raise ProfileError("app.products[%d] is not an object" % index)
        if "signingConfig" in product:
            value = product.pop("signingConfig")
            removed.append(
                "app.products[%d].signingConfig (product %r used %r)"
                % (index, product.get("name"), value)
            )
    return removed


def write_atomically(path, text):
    directory = os.path.dirname(os.path.abspath(path))
    handle, temporary = tempfile.mkstemp(prefix=".build-profile.", dir=directory)
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(text)
        os.replace(temporary, path)
    except BaseException:
        if os.path.exists(temporary):
            os.remove(temporary)
        raise


def main(arguments):
    if len(arguments) != 2:
        print("usage: strip_ohos_signing.py <build-profile.json5>", file=sys.stderr)
        return 2
    path = arguments[1]

    try:
        with open(path, "r", encoding="utf-8-sig") as stream:
            text = stream.read()
        profile, strict = parse_profile(text)
        removed = strip_signing(profile)
    except (OSError, UnicodeDecodeError, ProfileError) as error:
        print("::error::Cannot strip signing from %s: %s" % (path, error))
        return 1

    if not removed:
        print("%s holds no signing entry. Nothing to remove." % path)
        return 0

    if not strict:
        print("Note: %s used JSON5 syntax. The rewrite is strict JSON without comments." % path)
    try:
        write_atomically(path, json.dumps(profile, indent=2, ensure_ascii=False) + "\n")
        with open(path, "r", encoding="utf-8") as stream:
            leftover = strip_signing(json.load(stream))
    except (OSError, ValueError, ProfileError) as error:
        print("::error::Cannot rewrite %s: %s" % (path, error))
        return 1
    if leftover:
        print("::error::Signing entries remain in %s: %s" % (path, "; ".join(leftover)))
        return 1

    print("Removed from %s:" % path)
    for note in removed:
        print("  - " + note)
    print("This profile builds an unsigned HAP. Do not commit it.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
