#!/usr/bin/env python3
"""Embed the tested shell script in a self-contained Automator Quick Action."""

import plistlib
import shutil
from pathlib import Path


PROJECT = Path(__file__).resolve().parent.parent
TEMPLATE = PROJECT / "templates" / "QuickAction.workflow"
OUTPUT = PROJECT / "dist" / "Downscale Images.workflow"
SCRIPT = PROJECT / "scripts" / "downscale.sh"


def main() -> None:
    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(TEMPLATE, OUTPUT)

    document = OUTPUT / "Contents" / "document.wflow"
    with document.open("rb") as stream:
        workflow = plistlib.load(stream)
    workflow["actions"][0]["action"]["ActionParameters"]["COMMAND_STRING"] = (
        SCRIPT.read_text(encoding="utf-8")
    )
    with document.open("wb") as stream:
        plistlib.dump(workflow, stream, sort_keys=False)
    print(OUTPUT)


if __name__ == "__main__":
    main()
