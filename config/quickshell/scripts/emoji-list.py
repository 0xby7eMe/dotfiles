#!/usr/bin/env python3
# Prints "<emoji>\t<name>" lines for the launcher's ":" emoji picker, built
# from Python's Unicode database so no extra data package is needed.
import sys
import unicodedata

# (start, end, needs VS16 to render as color emoji)
RANGES = [
    (0x1F600, 0x1F64F, False),  # smileys
    (0x1F900, 0x1F9FF, False),  # supplemental symbols & pictographs
    (0x1FA70, 0x1FAFF, False),  # symbols & pictographs extended-A
    (0x1F300, 0x1F5FF, False),  # misc symbols & pictographs
    (0x1F680, 0x1F6FF, False),  # transport & map
    (0x2600, 0x26FF, True),     # misc symbols
    (0x2700, 0x27BF, True),     # dingbats
]
SKIP = ("SKIN TONE", "REGIONAL INDICATOR", "TAG ")

out = []
for start, end, vs16 in RANGES:
    for cp in range(start, end + 1):
        ch = chr(cp)
        name = unicodedata.name(ch, "")
        if not name or unicodedata.category(ch) != "So" or any(s in name for s in SKIP):
            continue
        out.append(f"{ch}️\t{name.lower()}" if vs16 else f"{ch}\t{name.lower()}")
sys.stdout.write("\n".join(out) + "\n")
