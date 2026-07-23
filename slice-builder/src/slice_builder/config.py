"""Configuration dataclasses shared across the slice-builder."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class DepRef:
    """A resolved dependency reference.

    Attributes:
        sd_name: bare SD name (e.g. ``curl``).
        is_bin: True if the dep SDF declares ``store: bin``.
        prefix: the release bin prefix (e.g. ``bin-``) if the dep is a bin dep,
            otherwise the empty string (deb deps use the bare name).
        sdf: the loaded dep SDF as a plain dict.
    """

    sd_name: str
    is_bin: bool
    prefix: str
    sdf: dict


@dataclass
class BuildConfig:
    """Parsed CLI configuration for a single ``generate-sdf`` invocation."""

    bin_archive: str
    base: str
    package: str
    track: str
    dependencies: list[str] = field(default_factory=list)
    sdf_lookup_dir: str | None = None
    output: str = ""
    omp: str = "omp"
    omp_model: str | None = None
    retries: int = 3
