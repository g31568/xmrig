#!/usr/bin/env python3
"""Reapply the fork's donation defaults after each upstream merge."""

from pathlib import Path
import re


def patch(root: Path) -> None:
    replacements = {
        "src/donate.h": [
            (r"(constexpr const int kDefaultDonateLevel\s*=\s*)\d+(\s*;)", r"\g<1>0\2"),
            (r"(constexpr const int kMinimumDonateLevel\s*=\s*)\d+(\s*;)", r"\g<1>0\2"),
        ],
        "src/config.json": [(r'("donate-(?:level|over-proxy)"\s*:\s*)\d+', r"\g<1>0")],
        "src/core/config/Config_default.h": [(r'("donate-(?:level|over-proxy)"\s*:\s*)\d+', r"\g<1>0")],
        "src/base/net/stratum/Pools.h": [
            (r"(ProxyDonate m_proxyDonate\s*=\s*)PROXY_DONATE_\w+", r"\g<1>PROXY_DONATE_NONE"),
        ],
        "src/base/net/stratum/Pools.cpp": [
            (r"(reader.getInt\(kDonateOverProxy,\s*)PROXY_DONATE_\w+", r"\g<1>PROXY_DONATE_NONE"),
        ],
        "src/core/config/usage.h": [
            (r'(--donate-level=N\s+donate level, default )[^"\\]*', r"\g<1>0%"),
        ],
    }
    patched = {}
    # Validate every expected setting before writing any source files.
    for relative, rules in replacements.items():
        path = root / relative
        content = path.read_text()
        for pattern, replacement in rules:
            content, count = re.subn(pattern, replacement, content)
            # Config templates contain both direct and proxy donation settings.
            expected = 2 if relative in ("src/config.json", "src/core/config/Config_default.h") else 1
            if count != expected:
                raise ValueError(f"Expected {expected} donation settings in {relative}, found {count}")
        patched[path] = content

    for path, content in patched.items():
        if path.read_text() != content:
            path.write_text(content)


if __name__ == "__main__":
    patch(Path(__file__).resolve().parents[2])
