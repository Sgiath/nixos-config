"""Load the invoking user's API credentials without serializing them in Nix."""

import json
import os
from pathlib import Path
import shlex
import sys


def main():
    mapping = json.loads(Path(sys.argv[1]).read_text())
    arguments = sys.argv[2:]
    if not arguments:
        raise ValueError("usage: with-api-keys COMMAND [ARGS...] or --shell")

    values = {}
    files = {}
    for name, filename in mapping.items():
        try:
            if filename not in files:
                files[filename] = Path(filename).read_text()
            value = files[filename]
            if "\0" in value:
                raise ValueError("environment values cannot contain NUL")
            values[name] = value
        except (OSError, ValueError) as error:
            # Report the credential name, never its value.
            raise ValueError(f"cannot load {name}: {type(error).__name__}") from None

    if arguments == ["--shell"]:
        for name, value in values.items():
            print(f"export {name}={shlex.quote(value)}")
    else:
        os.execvpe(arguments[0], arguments, {**os.environ, **values})


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"with-api-keys: {error}", file=sys.stderr)
        sys.exit(1)
