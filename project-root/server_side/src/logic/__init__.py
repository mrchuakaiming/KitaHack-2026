# project-root/server_side/src/logic/__init__.py

"""
Logic package for server-side processing.

This package exposes core functions from process_actions.py
for AI-based group dining recommendations.
"""

from .process_actions import (
    data_converter,
    our_model,
    generate_prompt_for_ai,
    generate_prompt_for_user
)

__all__ = [
    "data_converter",
    "our_model",
    "generate_prompt_for_ai",
    "generate_prompt_for_user",
]
