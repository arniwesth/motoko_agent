"""Harbor adapter placeholder for Motoko.

Terminal-Bench v2/Harbor integration is a follow-up once TB v1 adapter stabilizes.
"""
from __future__ import annotations


class MotokoAgent:  # pragma: no cover
    @staticmethod
    def name() -> str:
        return "motoko"

    def __init__(self, *args, **kwargs):
        raise NotImplementedError("Harbor adapter is not implemented yet; use benchmarks/tb_adapter/motoko_agent.py")
