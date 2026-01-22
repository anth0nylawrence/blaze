#!/usr/bin/env python3
"""
Render atoms.jsonl to feature-roadmap.md.

This script reads the canonical JSONL source of truth and produces
a deterministic markdown roadmap. The output is stable given the
same input (sorted by phase, then by id).

Usage:
    python3 scripts/render_atoms_roadmap.py
    python3 scripts/render_atoms_roadmap.py --input docs/atoms/atoms.jsonl --output docs/roadmap/feature-roadmap.md
    python3 scripts/render_atoms_roadmap.py --dry-run
"""

import argparse
import json
from datetime import datetime
from pathlib import Path


def load_atoms(path):
    """Load atoms from JSONL file."""
    atoms = []
    with open(path) as f:
        for line in f:
            if line.strip():
                atoms.append(json.loads(line))
    return atoms


def sort_atoms(atoms):
    """Sort atoms by phase, then by id for deterministic output."""
    def sort_key(atom):
        # Extract phase number if possible
        phase = atom.get("phase", "")
        phase_num = 999
        if phase.startswith("Phase "):
            try:
                phase_num = int(phase.split()[1].split(":")[0].split("-")[0])
            except (ValueError, IndexError):
                pass
        return (phase_num, atom.get("id", ""))

    return sorted(atoms, key=sort_key)


def group_by_phase(atoms):
    """Group atoms by phase."""
    phases = {}
    for atom in atoms:
        phase = atom.get("phase", "Unknown Phase")
        if phase not in phases:
            phases[phase] = []
        phases[phase].append(atom)
    return phases


def render_list(items, prefix="- "):
    """Render a list of items as markdown."""
    if not items:
        return "_None specified._\n"
    return "".join(f"{prefix}{item}\n" for item in items)


def render_metric(metric):
    """Render a single metric as a table row."""
    return f"| {metric.get('name', '')} | {metric.get('type', '')} | {metric.get('unit', '')} | {metric.get('target', '')} | {metric.get('notes', '')} |"


def render_atom(atom):
    """Render a single atom as markdown."""
    lines = []

    # Title
    atom_id = atom.get("id", "unknown")
    atom_name = atom.get("atom", "Untitled Atom")
    severity = atom.get("severity", "")
    status = atom.get("status", "")
    risk = atom.get("risk", "")

    lines.append(f"### {atom_id} — {atom_name}")
    lines.append("")
    lines.append(f"**Severity:** {severity} | **Status:** {status} | **Risk:** {risk} | **Estimate:** {atom.get('estimate_days', 0)} days")
    lines.append("")

    # Epic/Feature/Story/Task hierarchy
    lines.append(f"> **Epic:** {atom.get('epic', '')}")
    lines.append(f"> **Feature:** {atom.get('feature', '')}")
    lines.append(f"> **Story:** {atom.get('story', '')}")
    lines.append(f"> **Task:** {atom.get('task', '')}")
    lines.append("")

    # Problem Statement
    lines.append("#### Problem Statement")
    lines.append(atom.get("problem_statement", "_Not specified._"))
    lines.append("")

    # Description
    lines.append("#### Description")
    lines.append(atom.get("atom_description", "_Not specified._"))
    lines.append("")

    # Scope
    lines.append("#### Scope")
    lines.append("**In Scope:**")
    lines.append(render_list(atom.get("scope_in", [])))
    lines.append("**Out of Scope:**")
    lines.append(render_list(atom.get("scope_out", [])))

    # Requirements
    lines.append("#### Functional Requirements")
    lines.append(render_list(atom.get("functional_requirements", []), "1. "))

    lines.append("#### Non-Functional Requirements")
    lines.append(render_list(atom.get("nonfunctional_requirements", [])))

    # Implementation
    lines.append("#### Implementation Steps")
    lines.append(render_list(atom.get("implementation_steps", []), "1. "))

    # Files
    lines.append("#### Files")
    lines.append("**Files Touched:**")
    lines.append(render_list(atom.get("files_touched", []), "- `"))
    lines[-1] = lines[-1].replace("\n", "`\n") if lines[-1] != "_None specified._\n" else lines[-1]

    new_files = atom.get("new_files", [])
    if new_files and new_files != ["N/A"]:
        lines.append("**New Files:**")
        lines.append(render_list(new_files, "- `"))
        lines[-1] = lines[-1].replace("\n", "`\n")

    # Commands
    commands = atom.get("commands_used", [])
    if commands and commands != ["N/A"] and commands != ["No external commands; runner-managed execution only."]:
        lines.append("#### Commands")
        lines.append("```bash")
        for cmd in commands:
            lines.append(cmd)
        lines.append("```")
        lines.append("")

    # Data Model Changes
    data_changes = atom.get("data_model_changes", [])
    if data_changes and data_changes != ["N/A"]:
        lines.append("#### Data Model Changes")
        lines.append(render_list(data_changes))

    # Contracts
    lines.append("#### Contracts")
    lines.append("**API Contracts:**")
    lines.append(render_list(atom.get("api_contracts", [])))
    lines.append("**Event Contracts:**")
    lines.append(render_list(atom.get("event_contracts", [])))

    # UI
    ui_states = atom.get("ui_states", [])
    if ui_states and ui_states != ["N/A"]:
        lines.append("#### UI States")
        lines.append(render_list(ui_states))

    ui_interactions = atom.get("ui_interactions", [])
    if ui_interactions and ui_interactions != ["N/A"]:
        lines.append("#### UI Interactions")
        lines.append(render_list(ui_interactions))

    # Edge Cases & Failure Modes
    lines.append("#### Edge Cases")
    lines.append(render_list(atom.get("edge_cases", [])))

    lines.append("#### Failure Modes")
    lines.append(render_list(atom.get("failure_modes", [])))

    lines.append("#### Rollback Plan")
    lines.append(atom.get("rollback_plan", "_Not specified._"))
    lines.append("")

    # Testing
    lines.append("#### Test Plan")
    test_plan = atom.get("test_plan", {})
    for category in ["unit", "integration", "ui", "perf", "security"]:
        tests = test_plan.get(category, [])
        if tests and tests != ["N/A"] and tests != ["Not applicable: no direct UI surface for this atom."]:
            lines.append(f"**{category.title()}:**")
            lines.append(render_list(tests))

    # Metrics
    metrics = atom.get("metrics", [])
    if metrics:
        lines.append("#### Metrics")
        lines.append("| Name | Type | Unit | Target | Notes |")
        lines.append("|------|------|------|--------|-------|")
        for metric in metrics:
            lines.append(render_metric(metric))
        lines.append("")

    # Telemetry
    telemetry = atom.get("telemetry_events", [])
    if telemetry and telemetry != ["N/A"]:
        lines.append("#### Telemetry Events")
        lines.append(render_list(telemetry, "- `") .replace("\n", "`\n"))

    # Acceptance
    lines.append("#### Acceptance Tests")
    lines.append(render_list(atom.get("acceptance_tests", [])))

    lines.append("#### Acceptance Criteria")
    lines.append(render_list(atom.get("acceptance_criteria", []), "- [ ] "))

    # Definition of Done
    dod = atom.get("definition_of_done", {})
    lines.append("#### Definition of Done")
    lines.append(render_list(dod.get("criteria", []), "- [ ] "))

    flags = []
    if dod.get("requires_tests"):
        flags.append("Tests")
    if dod.get("requires_telemetry"):
        flags.append("Telemetry")
    if dod.get("requires_error_handling"):
        flags.append("Error Handling")
    if dod.get("requires_rollback_plan"):
        flags.append("Rollback Plan")
    if flags:
        lines.append(f"**Requires:** {', '.join(flags)}")
        lines.append("")

    # Completion
    lines.append("#### Completion")
    lines.append(f"**Completed When:** {atom.get('completed_when', '_Not specified._')}")
    lines.append("")
    lines.append(f"**Evidence:** {atom.get('completed_evidence', '_Not specified._')}")
    lines.append("")

    # Dependencies
    deps = atom.get("dependencies", "")
    dep_ids = atom.get("dependency_ids", [])
    if deps and deps != "None":
        lines.append("#### Dependencies")
        lines.append(f"{deps}")
        if dep_ids:
            lines.append("")
            lines.append("**Dependency IDs:** " + ", ".join(f"`{d}`" for d in dep_ids))
        lines.append("")

    # Source Refs
    refs = atom.get("source_refs", [])
    if refs:
        lines.append("#### Source References")
        lines.append(render_list(refs))

    # Open Questions
    questions = atom.get("open_questions", [])
    if questions and questions != ["None at this time."]:
        lines.append("#### Open Questions")
        lines.append(render_list(questions))

    # Notes
    notes = atom.get("notes", "")
    if notes:
        lines.append("#### Notes")
        lines.append(notes)
        lines.append("")

    # Owner/Reviewers
    lines.append("---")
    lines.append(f"**Owner:** {atom.get('owner', 'unassigned')} | **Reviewers:** {', '.join(atom.get('reviewers', ['TBD']))}")
    lines.append("")

    return "\n".join(lines)


def render_roadmap(atoms):
    """Render the complete roadmap from atoms."""
    lines = []

    # Header
    now = datetime.now().strftime("%Y-%m-%d")
    lines.append("# Blaze Feature Roadmap")
    lines.append("")
    lines.append(f"_Generated from `docs/atoms/atoms.jsonl` on {now}_")
    lines.append("")
    lines.append("> **Do not edit this file directly.** Edit `docs/atoms/atoms.jsonl` and run `make render-roadmap`.")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Summary stats
    total = len(atoms)
    by_status = {}
    for atom in atoms:
        status = atom.get("status", "unknown")
        by_status[status] = by_status.get(status, 0) + 1

    lines.append("## Summary")
    lines.append("")
    lines.append(f"**Total Atoms:** {total}")
    lines.append("")
    lines.append("| Status | Count |")
    lines.append("|--------|-------|")
    for status in ["done", "in_progress", "planned", "blocked"]:
        if status in by_status:
            lines.append(f"| {status} | {by_status[status]} |")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Group by phase
    sorted_atoms = sort_atoms(atoms)
    phases = group_by_phase(sorted_atoms)

    # Sort phases by phase number
    def phase_sort_key(phase_name):
        if phase_name.startswith("Phase "):
            try:
                return int(phase_name.split()[1].split(":")[0].split("-")[0])
            except (ValueError, IndexError):
                pass
        return 999

    sorted_phases = sorted(phases.keys(), key=phase_sort_key)

    # Table of Contents
    lines.append("## Table of Contents")
    lines.append("")
    for phase in sorted_phases:
        phase_atoms = phases[phase]
        anchor = phase.lower().replace(" ", "-").replace(":", "").replace("—", "")
        lines.append(f"- [{phase}](#{anchor}) ({len(phase_atoms)} atoms)")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Render each phase
    for phase in sorted_phases:
        phase_atoms = phases[phase]

        lines.append(f"## {phase}")
        lines.append("")
        lines.append(f"_{len(phase_atoms)} atoms in this phase_")
        lines.append("")

        # Phase summary table
        lines.append("| ID | Atom | Status | Priority | Risk |")
        lines.append("|----|------|--------|----------|------|")
        for atom in phase_atoms:
            lines.append(f"| {atom.get('id', '')} | {atom.get('atom', '')} | {atom.get('status', '')} | {atom.get('priority_rank', '')} | {atom.get('risk', '')} |")
        lines.append("")

        # Render each atom
        for atom in phase_atoms:
            lines.append(render_atom(atom))
            lines.append("")

        lines.append("---")
        lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Render atoms.jsonl to feature-roadmap.md")
    parser.add_argument("--input", "-i", default="docs/atoms/atoms.jsonl",
                        help="Path to atoms JSONL file (default: docs/atoms/atoms.jsonl)")
    parser.add_argument("--output", "-o", default="docs/roadmap/feature-roadmap.md",
                        help="Path to output markdown (default: docs/roadmap/feature-roadmap.md)")
    parser.add_argument("--dry-run", "-n", action="store_true",
                        help="Print to stdout instead of writing to file")
    args = parser.parse_args()

    # Load atoms
    try:
        atoms = load_atoms(args.input)
    except FileNotFoundError:
        print(f"Error: File not found: {args.input}")
        return 1
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {args.input}: {e}")
        return 1

    if not atoms:
        print(f"Warning: No atoms found in {args.input}")
        return 1

    # Render roadmap
    roadmap = render_roadmap(atoms)

    # Output
    if args.dry_run:
        print(roadmap)
    else:
        # Ensure output directory exists
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        output_path.write_text(roadmap)
        print(f"OK: Rendered {len(atoms)} atoms to {args.output}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
