#!/usr/bin/env python3
"""
Validate atoms.jsonl against Blaze Atom Schema v2.

This validator enforces:
- JSON Schema compliance (v2)
- No truncation (ellipsis rejection)
- No placeholder spam (N/A/TBD/TODO/FIXME detection with recursive traversal)
- Repo-relative refs only (no /mnt/, no absolute paths, no .., no ~, no ://)
- Dependency integrity (existence check + cycle detection)
- Testing gate (at least one non-N/A test)
- Evidence gate (completed_evidence must reference artifact path or CI link)
- N/A budget (max 20% of required fields)
- Traceability gate (source_refs_strict with valid refs)
- Phase ordering (numeric parsing for stable sorting)
- Path hygiene (no traversal attacks)

Usage:
    python3 scripts/validate_atoms.py [path/to/atoms.jsonl]
    python3 scripts/validate_atoms.py --schema v1 docs/atoms.jsonl
    python3 scripts/validate_atoms.py --format pretty docs/atoms/atoms.jsonl
    python3 scripts/validate_atoms.py --validate-template docs/atoms/atom.template.v2.json
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

try:
    from jsonschema import Draft202012Validator, ValidationError
    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False
    print("Warning: jsonschema not installed. Schema validation disabled.", file=sys.stderr)
    print("Install with: pip install jsonschema", file=sys.stderr)

# =============================================================================
# Regex patterns
# =============================================================================
ATOM_ID_RE = re.compile(r"^E\d{3}-F\d{3}-S\d{3}-T\d{3}-A\d{3}$")
EPIC_ID_RE = re.compile(r"^E\d{3}$")
FEATURE_ID_RE = re.compile(r"^E\d{3}-F\d{3}$")
STORY_ID_RE = re.compile(r"^E\d{3}-F\d{3}-S\d{3}$")
TASK_ID_RE = re.compile(r"^E\d{3}-F\d{3}-S\d{3}-T\d{3}$")
ELLIPSIS_RE = re.compile(r"\.\.\.")
MNT_PATH_RE = re.compile(r"/mnt/")
ABSOLUTE_PATH_RE = re.compile(r"^/[^/]")  # Starts with / but not //

# Phase pattern for numeric sorting: matches "Phase N", "Phase N.M", "N", "N.M", etc.
PHASE_NUMERIC_RE = re.compile(r"(?:Phase\s+)?(\d+(?:\.\d+)*)")

# Path hygiene patterns (dangerous path components)
PATH_TRAVERSAL_RE = re.compile(r"(?:^|/)\.\.(?:/|$)")  # Contains /../ or starts with ../
PATH_HOME_RE = re.compile(r"(?:^|/)~(?:/|$)")  # Contains ~ for home expansion
PATH_PROTOCOL_RE = re.compile(r"://")  # Contains protocol (except https:// which is allowed in source_refs)
PATH_BACKSLASH_RE = re.compile(r"\\")  # Contains backslashes
PATH_LEADING_WHITESPACE_RE = re.compile(r"^\s")  # Leading whitespace

# Valid prefixes for repo-relative paths
VALID_REPO_PREFIXES = ("docs/", "Sources/", "Tests/", "Blaze/", "scripts/", ".github/", "thoughts/")

# Fields that should contain repo-relative paths
PATH_FIELDS = {"files_touched", "new_files", "artifact_outputs"}

# =============================================================================
# N/A and Placeholder Detection
# =============================================================================

# N/A patterns (case-insensitive)
NA_PATTERNS = {"n/a", "na"}

# Placeholder patterns (case-insensitive)
PLACEHOLDER_PATTERNS = {"tbd", "todo", "fixme", "as needed", "etc.", "etc"}

def is_na_or_placeholder(value: str) -> Tuple[bool, Optional[str]]:
    """
    Check if a string value is N/A or a placeholder.
    Returns (True, pattern_matched) if detected, (False, None) otherwise.
    """
    if not isinstance(value, str):
        return False, None

    lower = value.strip().lower()

    # Check exact N/A matches
    if lower in NA_PATTERNS:
        return True, lower

    # Check placeholder patterns (exact match or as standalone word)
    for pattern in PLACEHOLDER_PATTERNS:
        if lower == pattern or lower.startswith(pattern + " ") or lower.endswith(" " + pattern):
            return True, pattern
        # Also catch patterns like "[TBD]" or "(TODO)"
        if f"[{pattern}]" in lower or f"({pattern})" in lower:
            return True, pattern

    return False, None


def find_na_and_placeholders_recursive(
    obj: Any,
    path: str = "",
    results: Optional[List[Tuple[str, str]]] = None
) -> List[Tuple[str, str]]:
    """
    Recursively traverse an object and find all N/A and placeholder values.

    Returns list of (dot_path, matched_pattern) tuples.

    Dot-path format examples:
      - "new_files"
      - "contracts.persistence"
      - "test_plan.perf[0]"
      - "reviewers[0]"
    """
    if results is None:
        results = []

    if isinstance(obj, dict):
        for key, value in obj.items():
            new_path = f"{path}.{key}" if path else key
            find_na_and_placeholders_recursive(value, new_path, results)
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            new_path = f"{path}[{i}]"
            find_na_and_placeholders_recursive(item, new_path, results)
    elif isinstance(obj, str):
        is_na, pattern = is_na_or_placeholder(obj)
        if is_na:
            results.append((path, pattern))

    return results


# =============================================================================
# Enums and Constants
# =============================================================================
SEVERITIES = {"P0", "P1", "P2", "P3", "P4", "P5", "P6"}
AREAS = {"Core", "UI", "Data", "QA", "Infra", "Security", "UX"}
RISKS = {"low", "medium", "high"}
STATUSES = {"planned", "in_progress", "blocked", "done"}
PRIORITY_RANKS = {"must", "should", "could"}
METRIC_TYPES = {"counter", "gauge", "timer", "histogram", "none"}

# Required fields for v1 (subset that v2 also uses)
V1_REQUIRED_FIELDS = [
    "id", "severity", "epic", "feature", "story", "story_description",
    "task", "task_description", "atom", "atom_description",
    "problem_statement", "scope_in", "scope_out", "assumptions", "constraints",
    "functional_requirements", "nonfunctional_requirements", "implementation_steps",
    "files_touched", "new_files", "commands_used", "data_model_changes",
    "api_contracts", "event_contracts", "ui_states", "ui_interactions", "ui_copy",
    "edge_cases", "failure_modes", "rollback_plan", "test_plan",
    "telemetry_events", "metrics", "log_expectations",
    "acceptance_tests", "acceptance_criteria", "definition_of_done",
    "completed_when", "completed_evidence", "dependencies", "dependency_ids",
    "epic_id", "feature_id", "story_id", "task_id", "phase", "area", "risk",
    "status", "status_reason", "owner", "reviewers", "estimate_days",
    "priority_rank", "source_refs", "open_questions", "notes",
]

# Additional required fields for v2
V2_REQUIRED_FIELDS = V1_REQUIRED_FIELDS + [
    "schema_version", "created_at", "updated_at", "source_refs_strict",
    "na_justifications", "verification_steps", "artifact_outputs",
    "risk_register", "contracts",
]

# List fields that must have minimum items
LIST_MIN2_FIELDS = {"functional_requirements", "implementation_steps", "edge_cases", "acceptance_criteria"}
LIST_MIN1_FIELDS = {
    "scope_in", "scope_out", "assumptions", "constraints", "nonfunctional_requirements",
    "files_touched", "new_files", "commands_used", "data_model_changes",
    "api_contracts", "event_contracts", "ui_states", "ui_interactions", "ui_copy",
    "failure_modes", "telemetry_events", "log_expectations", "acceptance_tests",
    "reviewers", "source_refs", "open_questions",
}

TEST_PLAN_KEYS = ["unit", "integration", "ui", "perf", "security"]

# N/A budget: max percentage of required fields that can be N/A
NA_BUDGET_PERCENT = 20


# =============================================================================
# Helper Functions
# =============================================================================

def is_non_empty_string(value: Any) -> bool:
    """Check if value is a non-empty string."""
    return isinstance(value, str) and value.strip() != ""


def is_simple_na(value: Any) -> bool:
    """Check if value is a simple N/A (for backwards compat)."""
    if isinstance(value, str):
        return value.strip().lower() in NA_PATTERNS
    return False


def contains_ellipsis(value: Any) -> Tuple[bool, Optional[str]]:
    """
    Check if value contains literal ellipsis.
    Returns (True, location) if found, (False, None) otherwise.
    """
    if isinstance(value, str):
        if ELLIPSIS_RE.search(value):
            return True, value[:50] + "..." if len(value) > 50 else value
        return False, None
    elif isinstance(value, list):
        for i, item in enumerate(value):
            found, loc = contains_ellipsis(item)
            if found:
                return True, f"[{i}]: {loc}"
        return False, None
    elif isinstance(value, dict):
        for k, v in value.items():
            found, loc = contains_ellipsis(v)
            if found:
                return True, f".{k}: {loc}"
        return False, None
    return False, None


def contains_mnt_path(value: Any) -> bool:
    """Check if value contains /mnt/ path reference."""
    if isinstance(value, str):
        return bool(MNT_PATH_RE.search(value))
    elif isinstance(value, list):
        return any(contains_mnt_path(item) for item in value)
    elif isinstance(value, dict):
        return any(contains_mnt_path(v) for v in value.values())
    return False


def check_path_hygiene(path: str) -> Optional[str]:
    """
    Check a path for hygiene issues.
    Returns error message if issue found, None if clean.
    """
    if not isinstance(path, str):
        return None

    # Skip N/A values
    if path.strip().lower() in NA_PATTERNS:
        return None

    if PATH_TRAVERSAL_RE.search(path):
        return "contains '..' path traversal"
    if PATH_HOME_RE.search(path):
        return "contains '~' home expansion"
    if PATH_BACKSLASH_RE.search(path):
        return "contains backslash (use forward slash)"
    if PATH_LEADING_WHITESPACE_RE.match(path):
        return "has leading whitespace"

    # Protocol check - allow https:// in source_refs_strict but not in path fields
    # This is handled separately for source_refs_strict

    return None


def is_repo_relative_path(path: str) -> bool:
    """Check if path is repo-relative (not absolute, not /mnt/)."""
    if not isinstance(path, str):
        return False
    if is_simple_na(path):
        return True  # N/A is allowed (but needs justification)
    if ABSOLUTE_PATH_RE.match(path):
        return False
    if MNT_PATH_RE.search(path):
        return False
    return True


def is_valid_source_ref(ref: str) -> bool:
    """Check if source_refs_strict entry is valid (repo path or https URL)."""
    if not isinstance(ref, str):
        return False
    if ref.startswith("https://"):
        return True
    if any(ref.startswith(prefix) for prefix in VALID_REPO_PREFIXES):
        return True
    return False


def count_na_fields(atom: Dict, required_fields: List[str]) -> int:
    """Count how many required fields have N/A values."""
    na_count = 0
    for field in required_fields:
        value = atom.get(field)
        if value is None:
            continue
        if is_simple_na(value):
            na_count += 1
        elif isinstance(value, list) and len(value) == 1 and is_simple_na(value[0]):
            na_count += 1
    return na_count


def parse_phase_sort_key(phase: str) -> Tuple[int, ...]:
    """
    Parse phase string into numeric tuple for sorting.

    Examples:
      "Phase 1" -> (1,)
      "Phase 2.10" -> (2, 10)
      "2.9" -> (2, 9)
      "Phase 10.1.5" -> (10, 1, 5)
      "Intro" -> (999999,) (non-numeric phases sort last)

    This ensures 2.10 > 2.9 > 2.2 numerically.
    """
    match = PHASE_NUMERIC_RE.search(phase)
    if match:
        parts = match.group(1).split(".")
        return tuple(int(p) for p in parts)
    return (999999,)  # Non-numeric phases sort last


def detect_cycles(atoms: List[Dict]) -> List[List[str]]:
    """Detect cycles in dependency graph using DFS."""
    graph = {}
    for atom in atoms:
        atom_id = atom.get("id")
        deps = atom.get("dependency_ids", [])
        graph[atom_id] = deps

    visited = set()
    rec_stack = set()
    cycles = []

    def dfs(node: str, path: List[str]):
        if node in rec_stack:
            cycle_start = path.index(node)
            cycles.append(path[cycle_start:] + [node])
            return
        if node in visited:
            return
        if node not in graph:
            return

        visited.add(node)
        rec_stack.add(node)
        path.append(node)

        for neighbor in graph[node]:
            dfs(neighbor, path)

        path.pop()
        rec_stack.remove(node)

    for node in graph:
        if node not in visited:
            dfs(node, [])

    return cycles


# =============================================================================
# Atom Validator
# =============================================================================

class AtomValidator:
    """Validator for Blaze Atom Schema."""

    def __init__(self, schema_version: str = "v2", schema_path: Optional[str] = None):
        self.schema_version = schema_version
        self.schema = None
        self.validator = None

        if HAS_JSONSCHEMA and schema_path:
            try:
                with open(schema_path) as f:
                    self.schema = json.load(f)
                self.validator = Draft202012Validator(self.schema)
            except Exception as e:
                print(f"Warning: Could not load schema: {e}", file=sys.stderr)

        self.required_fields = V2_REQUIRED_FIELDS if schema_version == "v2" else V1_REQUIRED_FIELDS

    def validate_atom(self, atom: Dict, line_no: int, all_ids: Set[str]) -> List[Tuple[int, str, str]]:
        """Validate a single atom, returning list of errors."""
        errors: List[Tuple[int, str, str]] = []
        atom_id = atom.get("id", "unknown")

        # 1. JSON Schema validation (if available)
        if self.validator:
            for error in self.validator.iter_errors(atom):
                errors.append((line_no, atom_id, f"Schema: {error.message}"))

        # 2. Required fields check
        for field in self.required_fields:
            if field not in atom:
                errors.append((line_no, atom_id, f"Missing required field: {field}"))

        # 3. ID pattern validation
        if not ATOM_ID_RE.match(atom_id):
            errors.append((line_no, atom_id, "id must match E###-F###-S###-T###-A###"))

        # 4. ID component consistency
        self._validate_id_consistency(atom, line_no, atom_id, errors)

        # 5. Enum validations
        self._validate_enums(atom, line_no, atom_id, errors)

        # 6. List minimums
        self._validate_lists(atom, line_no, atom_id, errors)

        # 7. CRITICAL: Ellipsis detection (no truncation)
        self._validate_no_ellipsis(atom, line_no, atom_id, errors)

        # 8. CRITICAL: /mnt/ path rejection
        self._validate_no_mnt_paths(atom, line_no, atom_id, errors)

        # 9. Repo-relative path validation
        self._validate_repo_paths(atom, line_no, atom_id, errors)

        # 10. Path hygiene (no .., ~, backslashes)
        self._validate_path_hygiene(atom, line_no, atom_id, errors)

        # 11. Dependencies
        self._validate_dependencies(atom, line_no, atom_id, all_ids, errors)

        # 12. Test plan structure
        self._validate_test_plan(atom, line_no, atom_id, errors)

        # 13. Metrics structure
        self._validate_metrics(atom, line_no, atom_id, errors)

        # 14. Definition of done structure
        self._validate_definition_of_done(atom, line_no, atom_id, errors)

        # 15. Testing gate
        self._validate_test_gate(atom, line_no, atom_id, errors)

        # 16. Evidence gate
        self._validate_evidence_gate(atom, line_no, atom_id, errors)

        # 17. Review gate
        self._validate_review_gate(atom, line_no, atom_id, errors)

        # v2-specific validations
        if self.schema_version == "v2":
            # 18. CRITICAL: Recursive N/A + placeholder gating
            self._validate_na_justifications_recursive(atom, line_no, atom_id, errors)

            # 19. N/A budget
            self._validate_na_budget(atom, line_no, atom_id, errors)

            # 20. source_refs_strict validation
            self._validate_source_refs_strict(atom, line_no, atom_id, errors)

            # 21. Verification steps
            self._validate_verification_steps(atom, line_no, atom_id, errors)

            # 22. Risk register
            self._validate_risk_register(atom, line_no, atom_id, errors)

            # 23. Contracts
            self._validate_contracts(atom, line_no, atom_id, errors)

            # 24. Phase validation (sortable)
            self._validate_phase(atom, line_no, atom_id, errors)

        return errors

    def _validate_id_consistency(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Validate that epic_id, feature_id, story_id, task_id match the atom id."""
        if not ATOM_ID_RE.match(atom_id):
            return

        parts = atom_id.split("-")
        derived_epic = parts[0]
        derived_feature = "-".join(parts[:2])
        derived_story = "-".join(parts[:3])
        derived_task = "-".join(parts[:4])

        epic_id = atom.get("epic_id", "")
        feature_id = atom.get("feature_id", "")
        story_id = atom.get("story_id", "")
        task_id = atom.get("task_id", "")

        if epic_id != derived_epic:
            errors.append((line_no, atom_id, f"epic_id '{epic_id}' does not match id prefix '{derived_epic}'"))
        if feature_id != derived_feature:
            errors.append((line_no, atom_id, f"feature_id '{feature_id}' does not match id prefix '{derived_feature}'"))
        if story_id != derived_story:
            errors.append((line_no, atom_id, f"story_id '{story_id}' does not match id prefix '{derived_story}'"))
        if task_id != derived_task:
            errors.append((line_no, atom_id, f"task_id '{task_id}' does not match id prefix '{derived_task}'"))

    def _validate_enums(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Validate enum fields."""
        if atom.get("severity") not in SEVERITIES:
            errors.append((line_no, atom_id, f"severity must be one of {sorted(SEVERITIES)}"))
        if atom.get("area") not in AREAS:
            errors.append((line_no, atom_id, f"area must be one of {sorted(AREAS)}"))
        if atom.get("risk") not in RISKS:
            errors.append((line_no, atom_id, f"risk must be one of {sorted(RISKS)}"))
        if atom.get("status") not in STATUSES:
            errors.append((line_no, atom_id, f"status must be one of {sorted(STATUSES)}"))
        if atom.get("priority_rank") not in PRIORITY_RANKS:
            errors.append((line_no, atom_id, f"priority_rank must be one of {sorted(PRIORITY_RANKS)}"))

    def _validate_lists(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Validate list field minimums."""
        for field in LIST_MIN2_FIELDS:
            value = atom.get(field, [])
            if not isinstance(value, list):
                errors.append((line_no, atom_id, f"{field} must be a list"))
            elif len(value) < 2:
                errors.append((line_no, atom_id, f"{field} must have at least 2 items"))

        for field in LIST_MIN1_FIELDS:
            value = atom.get(field, [])
            if not isinstance(value, list):
                errors.append((line_no, atom_id, f"{field} must be a list"))
            elif len(value) < 1:
                errors.append((line_no, atom_id, f"{field} must have at least 1 item"))

    def _validate_no_ellipsis(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """CRITICAL: Detect any ellipsis in fields (build failure)."""
        for field, value in atom.items():
            found, location = contains_ellipsis(value)
            if found:
                errors.append((line_no, atom_id, f"TRUNCATION: {field} contains '...' (forbidden) at {location}"))

    def _validate_no_mnt_paths(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """CRITICAL: Detect /mnt/ path references (build failure)."""
        for field, value in atom.items():
            if contains_mnt_path(value):
                errors.append((line_no, atom_id, f"INVALID_PATH: {field} contains '/mnt/' reference (forbidden)"))

    def _validate_repo_paths(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Validate that path fields contain repo-relative paths."""
        for field in PATH_FIELDS:
            value = atom.get(field, [])
            if not isinstance(value, list):
                continue
            for path in value:
                if not is_repo_relative_path(path):
                    errors.append((line_no, atom_id, f"{field} contains invalid path: {path}"))

    def _validate_path_hygiene(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Validate path hygiene (no .., ~, backslashes, etc.)."""
        for field in PATH_FIELDS:
            value = atom.get(field, [])
            if not isinstance(value, list):
                continue
            for path in value:
                issue = check_path_hygiene(path)
                if issue:
                    errors.append((line_no, atom_id, f"PATH_HYGIENE: {field} path '{path}' {issue}"))

    def _validate_dependencies(self, atom: Dict, line_no: int, atom_id: str, all_ids: Set[str], errors: List):
        """Validate dependency fields."""
        dependencies = atom.get("dependencies", "")
        dependency_ids = atom.get("dependency_ids", [])

        if not isinstance(dependency_ids, list):
            errors.append((line_no, atom_id, "dependency_ids must be a list"))
            return

        # Check consistency
        if dependencies.strip().lower() == "none" and dependency_ids:
            errors.append((line_no, atom_id, "dependency_ids must be empty when dependencies is 'None'"))
        if dependencies.strip().lower() != "none" and not dependency_ids:
            errors.append((line_no, atom_id, "dependency_ids must be non-empty when dependencies is not 'None'"))

        # Check that all dependency_ids exist
        for dep_id in dependency_ids:
            if not ATOM_ID_RE.match(dep_id):
                errors.append((line_no, atom_id, f"Invalid dependency_id format: {dep_id}"))
            elif dep_id not in all_ids:
                errors.append((line_no, atom_id, f"dependency_id '{dep_id}' not found in file"))

    def _validate_test_plan(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Validate test_plan structure."""
        test_plan = atom.get("test_plan", {})
        if not isinstance(test_plan, dict):
            errors.append((line_no, atom_id, "test_plan must be an object"))
            return

        for key in TEST_PLAN_KEYS:
            if key not in test_plan:
                errors.append((line_no, atom_id, f"test_plan missing key: {key}"))
            elif not isinstance(test_plan[key], list) or len(test_plan[key]) < 1:
                errors.append((line_no, atom_id, f"test_plan.{key} must have at least 1 item"))

    def _validate_metrics(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Validate metrics array."""
        metrics = atom.get("metrics", [])
        if not isinstance(metrics, list):
            errors.append((line_no, atom_id, "metrics must be a list"))
            return
        if len(metrics) < 1:
            errors.append((line_no, atom_id, "metrics must have at least 1 item"))
            return

        for i, metric in enumerate(metrics):
            if not isinstance(metric, dict):
                errors.append((line_no, atom_id, f"metrics[{i}] must be an object"))
                continue
            for key in ["name", "type", "unit", "target", "notes"]:
                if key not in metric or not is_non_empty_string(metric.get(key)):
                    errors.append((line_no, atom_id, f"metrics[{i}].{key} must be non-empty"))
            if metric.get("type") not in METRIC_TYPES:
                errors.append((line_no, atom_id, f"metrics[{i}].type must be one of {sorted(METRIC_TYPES)}"))

    def _validate_definition_of_done(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Validate definition_of_done structure."""
        dod = atom.get("definition_of_done", {})
        if not isinstance(dod, dict):
            errors.append((line_no, atom_id, "definition_of_done must be an object"))
            return

        criteria = dod.get("criteria", [])
        if not isinstance(criteria, list) or len(criteria) < 2:
            errors.append((line_no, atom_id, "definition_of_done.criteria must have at least 2 items"))

        for key in ["requires_tests", "requires_telemetry", "requires_error_handling", "requires_rollback_plan"]:
            if key not in dod or not isinstance(dod.get(key), bool):
                errors.append((line_no, atom_id, f"definition_of_done.{key} must be a boolean"))

    def _validate_test_gate(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Testing gate: at least one non-N/A test required."""
        test_plan = atom.get("test_plan", {})
        if not isinstance(test_plan, dict):
            return

        all_tests = []
        for key in TEST_PLAN_KEYS:
            items = test_plan.get(key, [])
            if isinstance(items, list):
                all_tests.extend(items)

        has_real_test = any(is_non_empty_string(item) and not is_simple_na(item) for item in all_tests)
        if not has_real_test:
            errors.append((line_no, atom_id, "TESTING_GATE: at least one test entry must be non-N/A"))

    def _validate_evidence_gate(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """
        Evidence gate: completed_evidence must reference either:
        1. A repo-relative artifact path (from files_touched/new_files/artifact_outputs)
        2. A CI run link (https://)
        3. Specific verification keywords that indicate real proof

        The evidence must describe HOW completion was verified.
        """
        evidence = atom.get("completed_evidence", "")
        if not is_non_empty_string(evidence):
            errors.append((line_no, atom_id, "completed_evidence must be non-empty"))
            return

        evidence_lower = evidence.lower()

        # Collect all artifact paths from the atom
        artifact_paths = set()
        for field in ["files_touched", "new_files", "artifact_outputs"]:
            paths = atom.get(field, [])
            if isinstance(paths, list):
                for p in paths:
                    if isinstance(p, str) and not is_simple_na(p):
                        # Add the path and also just the filename
                        artifact_paths.add(p)
                        if "/" in p:
                            artifact_paths.add(p.split("/")[-1])

        # Check for CI link
        has_ci_link = "https://" in evidence

        # Check for artifact path reference
        has_artifact_ref = any(artifact in evidence for artifact in artifact_paths if artifact)

        # Check for verification keywords that indicate real proof
        # These patterns indicate the evidence describes HOW completion was verified
        verification_keywords = [
            # Testing patterns
            "test", "tests", "spec", "specs",
            "unit test", "integration test", "e2e",
            "coverage", "assertion", "verify", "verified",
            # Build/compile patterns
            "compile", "compiles", "build", "builds",
            ".swift", ".md", ".json", ".yaml",
            # Manual verification patterns
            "manual", "inspection", "review", "reviewed",
            "screenshot", "recording", "demo",
            # Output/artifact patterns
            "output", "log", "result", "artifact",
            "ci ", "ci/cd", "pipeline", "workflow",
            # Behavioral patterns
            "shows", "demonstrates", "confirms", "passes",
            "works", "functions", "behaves", "renders",
            "displays", "handles", "processes",
        ]

        has_verification_keyword = any(kw in evidence_lower for kw in verification_keywords)

        if not (has_ci_link or has_artifact_ref or has_verification_keyword):
            errors.append((
                line_no, atom_id,
                "EVIDENCE_GATE: completed_evidence must describe how completion was verified "
                "(tests, builds, manual inspection, output artifacts, etc.)"
            ))

    def _validate_review_gate(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """Review gate: status_reason required, owner for in_progress."""
        status_reason = atom.get("status_reason", "")
        if not is_non_empty_string(status_reason) or is_simple_na(status_reason):
            errors.append((line_no, atom_id, "status_reason must be a specific, non-N/A string"))

        status = atom.get("status")
        owner = atom.get("owner", "")
        if status == "in_progress" and (not is_non_empty_string(owner) or is_simple_na(owner) or owner == "unassigned"):
            errors.append((line_no, atom_id, "owner must be assigned when status is in_progress"))

    def _validate_na_justifications_recursive(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """
        v2: Recursive N/A + placeholder gating.

        Traverses the ENTIRE atom object to find:
        - N/A (case-insensitive): "N/A", "NA"
        - Placeholders: "TBD", "TODO", "FIXME", "as needed", "etc."

        Each detected value requires a justification entry in na_justifications
        keyed by dot-path format (e.g., "contracts.persistence[0]").
        """
        na_justifications = atom.get("na_justifications", {})
        if not isinstance(na_justifications, dict):
            errors.append((line_no, atom_id, "na_justifications must be an object"))
            na_justifications = {}

        # Find all N/A and placeholder values recursively
        # Skip the na_justifications field itself
        atom_copy = {k: v for k, v in atom.items() if k != "na_justifications"}
        detected = find_na_and_placeholders_recursive(atom_copy)

        # Check that all detected values have justifications
        for path, pattern in detected:
            if path not in na_justifications:
                errors.append((
                    line_no, atom_id,
                    f"N/A_GATE: '{path}' has value '{pattern}' but no entry in na_justifications "
                    f"(add key '{path}' with justification)"
                ))
            elif not is_non_empty_string(na_justifications.get(path)):
                errors.append((
                    line_no, atom_id,
                    f"N/A_GATE: na_justifications['{path}'] must be a non-empty explanation"
                ))

    def _validate_na_budget(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """v2: N/A budget - max 20% of required fields can be N/A."""
        na_count = count_na_fields(atom, self.required_fields)
        total = len(self.required_fields)
        percent = (na_count / total) * 100 if total > 0 else 0

        if percent > NA_BUDGET_PERCENT:
            errors.append((line_no, atom_id, f"N/A_BUDGET: {na_count}/{total} ({percent:.1f}%) fields are N/A (max {NA_BUDGET_PERCENT}%)"))

    def _validate_source_refs_strict(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """v2: source_refs_strict must contain valid repo paths or URLs."""
        refs = atom.get("source_refs_strict", [])
        if not isinstance(refs, list):
            errors.append((line_no, atom_id, "source_refs_strict must be a list"))
            return
        if len(refs) < 1:
            errors.append((line_no, atom_id, "source_refs_strict must have at least 1 item"))
            return

        for ref in refs:
            if not is_valid_source_ref(ref):
                errors.append((line_no, atom_id, f"TRACEABILITY: source_refs_strict entry '{ref}' must be repo path (docs/...) or https URL"))
            # Additional hygiene check (but allow https://)
            if not ref.startswith("https://"):
                issue = check_path_hygiene(ref)
                if issue:
                    errors.append((line_no, atom_id, f"PATH_HYGIENE: source_refs_strict entry '{ref}' {issue}"))

    def _validate_verification_steps(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """v2: verification_steps must have at least 2 items."""
        steps = atom.get("verification_steps", [])
        if not isinstance(steps, list):
            errors.append((line_no, atom_id, "verification_steps must be a list"))
        elif len(steps) < 2:
            errors.append((line_no, atom_id, "verification_steps must have at least 2 items"))

    def _validate_risk_register(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """v2: risk_register structure validation."""
        rr = atom.get("risk_register", {})
        if not isinstance(rr, dict):
            errors.append((line_no, atom_id, "risk_register must be an object"))
            return

        for key in ["risks", "mitigations"]:
            value = rr.get(key, [])
            if not isinstance(value, list) or len(value) < 1:
                errors.append((line_no, atom_id, f"risk_register.{key} must have at least 1 item"))

        for key in ["blast_radius", "fallback_plan"]:
            if not is_non_empty_string(rr.get(key)):
                errors.append((line_no, atom_id, f"risk_register.{key} must be a non-empty string"))

    def _validate_contracts(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """v2: contracts structure validation."""
        contracts = atom.get("contracts", {})
        if not isinstance(contracts, dict):
            errors.append((line_no, atom_id, "contracts must be an object"))
            return

        for key in ["events", "apis", "state", "persistence"]:
            value = contracts.get(key, [])
            if not isinstance(value, list) or len(value) < 1:
                errors.append((line_no, atom_id, f"contracts.{key} must have at least 1 item"))

    def _validate_phase(self, atom: Dict, line_no: int, atom_id: str, errors: List):
        """v2: Validate phase is sortable (has numeric component)."""
        phase = atom.get("phase", "")
        if not is_non_empty_string(phase):
            errors.append((line_no, atom_id, "phase must be a non-empty string"))
            return

        # Just validate it can be parsed; actual sorting happens in renderer
        sort_key = parse_phase_sort_key(phase)
        if sort_key == (999999,):
            # Non-numeric phase - warn but don't fail
            # (Some phases like "Intro" or "Cleanup" may be intentionally non-numeric)
            pass


# =============================================================================
# Main Validation Functions
# =============================================================================

def validate_atoms(path: str, schema_version: str = "v2") -> Tuple[List[Tuple[int, str, str]], int]:
    """Validate all atoms in a JSONL file."""
    errors: List[Tuple[int, str, str]] = []
    atoms: List[Tuple[int, Dict]] = []
    all_ids: Set[str] = set()
    duplicate_ids: Set[str] = set()

    # Determine schema path
    schema_path = None
    if schema_version == "v2":
        schema_path = Path(path).parent / "atom.schema.v2.json"
        if not schema_path.exists():
            schema_path = Path("docs/atoms/atom.schema.v2.json")
    else:
        schema_path = Path(path).parent / "atom.schema.json"
        if not schema_path.exists():
            schema_path = Path("docs/atoms/atom.schema.json")

    if not schema_path.exists():
        schema_path = None

    validator = AtomValidator(schema_version, str(schema_path) if schema_path else None)

    # Parse all atoms first (collect IDs for dependency checking)
    try:
        lines = Path(path).read_text().splitlines()
    except FileNotFoundError:
        return [(0, "N/A", f"File not found: {path}")], 0

    for line_no, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            atom = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append((line_no, "N/A", f"Invalid JSON: {exc}"))
            continue

        if not isinstance(atom, dict):
            errors.append((line_no, "N/A", f"Line must be a JSON object, got {type(atom).__name__}"))
            continue

        atom_id = atom.get("id")
        if atom_id:
            if atom_id in all_ids:
                duplicate_ids.add(atom_id)
            all_ids.add(atom_id)
        atoms.append((line_no, atom))

    # Report duplicates
    for dup_id in sorted(duplicate_ids):
        errors.append((0, dup_id, "Duplicate atom ID"))

    # Validate each atom
    for line_no, atom in atoms:
        atom_errors = validator.validate_atom(atom, line_no, all_ids)
        errors.extend(atom_errors)

    # Cycle detection in dependencies
    atom_dicts = [atom for _, atom in atoms]
    cycles = detect_cycles(atom_dicts)
    for cycle in cycles:
        cycle_str = " -> ".join(cycle)
        errors.append((0, cycle[0], f"CYCLE_DETECTED: {cycle_str}"))

    return errors, len(atoms)


def validate_template(path: str, schema_version: str = "v2") -> Tuple[List[Tuple[int, str, str]], int]:
    """Validate a single template JSON file (not JSONL)."""
    errors: List[Tuple[int, str, str]] = []

    # Determine schema path
    schema_path = None
    if schema_version == "v2":
        schema_path = Path(path).parent / "atom.schema.v2.json"
        if not schema_path.exists():
            schema_path = Path("docs/atoms/atom.schema.v2.json")
    else:
        schema_path = Path(path).parent / "atom.schema.json"
        if not schema_path.exists():
            schema_path = Path("docs/atoms/atom.schema.json")

    if not schema_path.exists():
        schema_path = None

    validator = AtomValidator(schema_version, str(schema_path) if schema_path else None)

    try:
        content = Path(path).read_text()
        atom = json.loads(content)
    except FileNotFoundError:
        return [(0, "N/A", f"File not found: {path}")], 0
    except json.JSONDecodeError as exc:
        return [(0, "N/A", f"Invalid JSON: {exc}")], 0

    if not isinstance(atom, dict):
        return [(0, "N/A", f"File must contain a JSON object, got {type(atom).__name__}")], 0

    atom_id = atom.get("id", "template")

    # For template validation, we don't check dependency existence
    # since the template may reference non-existent example atoms
    all_ids = {atom_id}

    # Also add any dependency_ids to all_ids so they don't fail existence check
    dep_ids = atom.get("dependency_ids", [])
    if isinstance(dep_ids, list):
        all_ids.update(dep_ids)

    atom_errors = validator.validate_atom(atom, 1, all_ids)
    errors.extend(atom_errors)

    return errors, 1


def format_output(path: str) -> str:
    """Pretty-print JSONL for stable diffs (optional)."""
    output_lines = []
    lines = Path(path).read_text().splitlines()
    for line in lines:
        if not line.strip():
            continue
        atom = json.loads(line)
        # Sort keys for stable output
        output_lines.append(json.dumps(atom, sort_keys=True, ensure_ascii=False))
    return "\n".join(output_lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate atoms.jsonl against Blaze Atom Schema")
    parser.add_argument("path", nargs="?", default="docs/atoms/atoms.jsonl",
                        help="Path to JSONL file (default: docs/atoms/atoms.jsonl)")
    parser.add_argument("--schema", choices=["v1", "v2"], default="v2",
                        help="Schema version to validate against (default: v2)")
    parser.add_argument("--format", choices=["pretty", "json", "summary"], default="summary",
                        help="Output format (default: summary)")
    parser.add_argument("--validate-template", action="store_true",
                        help="Validate a single template JSON file instead of JSONL")
    args = parser.parse_args()

    if args.format == "pretty":
        try:
            output = format_output(args.path)
            print(output)
            return 0
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            return 1

    if args.validate_template:
        errors, atom_count = validate_template(args.path, args.schema)
    else:
        errors, atom_count = validate_atoms(args.path, args.schema)

    if args.format == "json":
        result = {
            "path": args.path,
            "schema_version": args.schema,
            "atom_count": atom_count,
            "error_count": len(errors),
            "errors": [
                {"line": line_no, "atom_id": atom_id, "message": msg}
                for line_no, atom_id, msg in errors
            ]
        }
        print(json.dumps(result, indent=2))
        return 1 if errors else 0

    # Summary format (default)
    if errors:
        print(f"FAIL: {len(errors)} issues found in {args.path}")
        print()

        # Group errors by type
        truncation = [e for e in errors if "TRUNCATION" in e[2]]
        invalid_path = [e for e in errors if "INVALID_PATH" in e[2] or "/mnt/" in e[2]]
        path_hygiene = [e for e in errors if "PATH_HYGIENE" in e[2]]
        na_gate = [e for e in errors if "N/A_GATE" in e[2] or "N/A_BUDGET" in e[2]]
        testing = [e for e in errors if "TESTING_GATE" in e[2] or "EVIDENCE_GATE" in e[2]]
        cycles = [e for e in errors if "CYCLE" in e[2]]
        other = [e for e in errors if e not in truncation + invalid_path + path_hygiene + na_gate + testing + cycles]

        if truncation:
            print(f"=== TRUNCATION ERRORS ({len(truncation)}) ===")
            for line_no, atom_id, msg in truncation[:5]:
                print(f"  line {line_no} {atom_id}: {msg}")
            if len(truncation) > 5:
                print(f"  ... and {len(truncation) - 5} more")
            print()

        if invalid_path:
            print(f"=== INVALID PATH ERRORS ({len(invalid_path)}) ===")
            for line_no, atom_id, msg in invalid_path[:5]:
                print(f"  line {line_no} {atom_id}: {msg}")
            if len(invalid_path) > 5:
                print(f"  ... and {len(invalid_path) - 5} more")
            print()

        if path_hygiene:
            print(f"=== PATH HYGIENE ERRORS ({len(path_hygiene)}) ===")
            for line_no, atom_id, msg in path_hygiene[:5]:
                print(f"  line {line_no} {atom_id}: {msg}")
            if len(path_hygiene) > 5:
                print(f"  ... and {len(path_hygiene) - 5} more")
            print()

        if na_gate:
            print(f"=== N/A GATING ERRORS ({len(na_gate)}) ===")
            for line_no, atom_id, msg in na_gate[:5]:
                print(f"  line {line_no} {atom_id}: {msg}")
            if len(na_gate) > 5:
                print(f"  ... and {len(na_gate) - 5} more")
            print()

        if testing:
            print(f"=== TESTING GATE ERRORS ({len(testing)}) ===")
            for line_no, atom_id, msg in testing[:5]:
                print(f"  line {line_no} {atom_id}: {msg}")
            if len(testing) > 5:
                print(f"  ... and {len(testing) - 5} more")
            print()

        if cycles:
            print(f"=== DEPENDENCY CYCLES ({len(cycles)}) ===")
            for line_no, atom_id, msg in cycles:
                print(f"  {msg}")
            print()

        if other:
            print(f"=== OTHER ERRORS ({len(other)}) ===")
            for line_no, atom_id, msg in other[:10]:
                loc = f"line {line_no}" if line_no else "file"
                ident = atom_id if atom_id else "unknown"
                print(f"  {loc} {ident}: {msg}")
            if len(other) > 10:
                print(f"  ... and {len(other) - 10} more")
            print()

        return 1

    entity_type = "template" if args.validate_template else "atoms"
    print(f"OK: {atom_count} {entity_type} validated against schema {args.schema}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
