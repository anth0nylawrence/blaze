#!/usr/bin/env python3
"""
Migrate atoms from v1 schema to v2 schema.

This script adds the required v2 fields with sensible defaults:
- schema_version: "v2"
- created_at / updated_at: current timestamp
- source_refs_strict: derived from source_refs (fixing /mnt/ paths)
- na_justifications: empty (atoms should be reviewed)
- verification_steps: derived from acceptance_tests
- artifact_outputs: derived from new_files
- risk_register: generated from existing risk/failure_modes
- contracts: derived from api_contracts/event_contracts

Usage:
    python3 scripts/migrate_atoms_v1_to_v2.py docs/atoms.jsonl > docs/atoms/atoms.jsonl
    python3 scripts/migrate_atoms_v1_to_v2.py --dry-run docs/atoms.jsonl
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path


def fix_source_ref(ref):
    """Fix /mnt/data paths to repo-relative paths."""
    if not isinstance(ref, str):
        return ref

    # Map known /mnt/data references to repo paths
    mappings = {
        "/mnt/data/blaze-chat-ui-polish-spec (1).md": "docs/feature/blaze-chat-ui-polish-spec (1).md",
        "/mnt/data/feature-roadmap.md": "docs/feature/feature-roadmap.md",
        "/mnt/data/mcp-visibility.md": "docs/feature/mcp-visibility.md",
        "/mnt/data/phase2.md": "docs/phase2.md",
    }

    for old, new in mappings.items():
        if old in ref:
            ref = ref.replace(old, new)

    # Generic /mnt/data/ replacement
    ref = re.sub(r"/mnt/data/([^#\s]+)", r"docs/\1", ref)

    return ref


def derive_source_refs_strict(source_refs):
    """Derive source_refs_strict from source_refs."""
    result = []
    for ref in source_refs:
        fixed = fix_source_ref(ref)
        # Ensure it starts with a valid prefix
        if fixed.startswith(("docs/", "Sources/", "Tests/", "Blaze/", "scripts/", "https://")):
            result.append(fixed)
        elif "/" in fixed and not fixed.startswith("/"):
            # Assume it's a repo path
            result.append(fixed)
        else:
            # Default to docs/ prefix
            result.append(f"docs/{fixed}")

    # Ensure at least one entry
    if not result:
        result = ["docs/atoms/README.md"]

    return result


def derive_verification_steps(atom):
    """Derive verification_steps from acceptance_tests and other fields."""
    steps = []

    # Add build/run step
    if atom.get("area") in ["Core", "UI", "Data"]:
        steps.append("Run swift build && swift test to verify compilation and tests pass")

    # Add acceptance test verification
    tests = atom.get("acceptance_tests", [])
    for test in tests[:2]:  # Take first 2
        if test and test.lower() != "n/a":
            steps.append(f"Verify: {test}")

    # Add evidence verification
    evidence = atom.get("completed_evidence", "")
    if evidence and evidence.lower() != "n/a":
        steps.append(f"Check evidence: {evidence}")

    # Ensure at least 2 steps
    while len(steps) < 2:
        steps.append("Review code changes and verify acceptance criteria")

    return steps


def derive_artifact_outputs(atom):
    """Derive artifact_outputs from new_files and other fields."""
    outputs = []

    new_files = atom.get("new_files", [])
    for f in new_files:
        if f and f.lower() != "n/a":
            outputs.append(f)

    # If no new files, use files_touched
    if not outputs:
        touched = atom.get("files_touched", [])
        for f in touched[:2]:  # First 2 modified files
            if f:
                outputs.append(f)

    # Ensure at least one
    if not outputs:
        outputs = ["N/A"]

    return outputs


def derive_risk_register(atom):
    """Derive risk_register from existing fields."""
    risk_level = atom.get("risk", "low")
    failure_modes = atom.get("failure_modes", [])
    rollback = atom.get("rollback_plan", "Revert changes")

    # Build risks from failure modes
    risks = []
    for fm in failure_modes[:2]:
        if fm and fm.lower() != "n/a":
            risks.append(fm)
    if not risks:
        risks = [f"Implementation may have {risk_level} impact issues"]

    # Build mitigations
    mitigations = []
    if risk_level == "high":
        mitigations.append("Implement comprehensive test coverage before deployment")
        mitigations.append("Use feature flags for gradual rollout")
    elif risk_level == "medium":
        mitigations.append("Add unit tests for critical paths")
    else:
        mitigations.append("Standard code review process")

    # Blast radius
    area = atom.get("area", "Core")
    files = atom.get("files_touched", [])
    blast_radius = f"Affects {area} subsystem; {len(files)} files impacted"

    return {
        "risks": risks,
        "mitigations": mitigations,
        "blast_radius": blast_radius,
        "fallback_plan": rollback if rollback else "Revert git changes"
    }


def derive_contracts(atom):
    """Derive contracts summary from existing fields."""
    return {
        "events": atom.get("telemetry_events", ["N/A"])[:2] or ["N/A"],
        "apis": atom.get("api_contracts", ["N/A"])[:2] or ["N/A"],
        "state": atom.get("data_model_changes", ["N/A"])[:2] or ["N/A"],
        "persistence": ["Session event store"] if "Store" in str(atom.get("files_touched", [])) else ["N/A"]
    }


def derive_na_justifications(atom):
    """Build na_justifications for any N/A fields."""
    justifications = {}

    # Check common N/A patterns
    fields_to_check = [
        ("new_files", "No new files created; modifying existing files only"),
        ("ui_states", "No direct UI impact from this atom"),
        ("ui_interactions", "No direct UI interaction from this atom"),
        ("ui_copy", "No user-facing copy changes"),
        ("commands_used", "No external commands; automated via build system"),
    ]

    for field, justification in fields_to_check:
        value = atom.get(field, [])
        if isinstance(value, list) and len(value) == 1 and value[0].lower() == "n/a":
            justifications[field] = justification
        elif isinstance(value, str) and value.lower() == "n/a":
            justifications[field] = justification

    return justifications


def migrate_atom(atom):
    """Migrate a single atom from v1 to v2."""
    now = datetime.now().isoformat() + "Z"

    # Start with existing atom
    v2 = dict(atom)

    # Add v2 required fields
    v2["schema_version"] = "v2"
    v2["created_at"] = now
    v2["updated_at"] = now

    # Fix and add source_refs_strict
    v2["source_refs_strict"] = derive_source_refs_strict(atom.get("source_refs", []))

    # Add N/A justifications
    v2["na_justifications"] = derive_na_justifications(atom)

    # Add verification steps
    v2["verification_steps"] = derive_verification_steps(atom)

    # Add artifact outputs
    v2["artifact_outputs"] = derive_artifact_outputs(atom)

    # Add risk register
    v2["risk_register"] = derive_risk_register(atom)

    # Add contracts summary
    v2["contracts"] = derive_contracts(atom)

    return v2


def migrate_file(input_path):
    """Migrate all atoms in a file from v1 to v2."""
    atoms = []
    with open(input_path) as f:
        for line in f:
            if line.strip():
                atom = json.loads(line)
                v2_atom = migrate_atom(atom)
                atoms.append(v2_atom)
    return atoms


def main():
    parser = argparse.ArgumentParser(description="Migrate atoms from v1 to v2 schema")
    parser.add_argument("input", help="Path to v1 atoms JSONL file")
    parser.add_argument("--output", "-o", help="Output file (default: stdout)")
    parser.add_argument("--dry-run", "-n", action="store_true", help="Show first 3 atoms only")
    args = parser.parse_args()

    try:
        atoms = migrate_file(args.input)
    except FileNotFoundError:
        print(f"Error: File not found: {args.input}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON: {e}", file=sys.stderr)
        return 1

    if args.dry_run:
        for atom in atoms[:3]:
            print(json.dumps(atom, indent=2))
            print()
        print(f"... ({len(atoms) - 3} more atoms)")
        return 0

    output_lines = [json.dumps(atom, ensure_ascii=False) for atom in atoms]
    output = "\n".join(output_lines)

    if args.output:
        Path(args.output).write_text(output + "\n")
        print(f"OK: Migrated {len(atoms)} atoms to {args.output}", file=sys.stderr)
    else:
        print(output)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
