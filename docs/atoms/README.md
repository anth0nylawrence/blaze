# Blaze Atom Schema

This directory contains the canonical atom schemas and the single source of truth for Blaze feature atoms.

## Directory Structure

```
docs/atoms/
├── README.md                  # This file
├── atom.schema.json           # v1 schema (legacy, for archived atoms only)
├── atom.schema.v2.json        # v2 schema (canonical, required for new atoms)
├── atoms.jsonl                # Canonical JSONL source of truth
├── backlog.jsonl              # Incomplete atoms (status=blocked)
└── atom.template.v2.json      # Example valid v2 atom
```

## Schema Versions

### v1 (Legacy)
- Basic structural validation
- Required fields and type checks
- ID pattern enforcement
- **Use case**: Archived atoms only

### v2 (Canonical)
- All v1 requirements plus:
- `schema_version: "v2"` required
- `created_at` / `updated_at` timestamps
- `source_refs_strict`: No `/mnt/` refs, only repo paths or https URLs
- `na_justifications`: Must explain every N/A field
- `verification_steps`: Concrete proof steps
- `artifact_outputs`: What files this atom produces
- `risk_register`: Explicit risks, mitigations, blast radius
- `contracts`: Summary index of events/apis/state/persistence
- **Ellipsis rejection**: No `...` in any field

## Validation Rules

The validator (`scripts/validate_atoms.py`) enforces:

1. **Schema compliance**: Every line validates against v2 schema
2. **No truncation**: Literal `...` anywhere fails the build
3. **No placeholder spam**: N/A fields require justification
4. **Repo-relative refs**: No `/mnt/data/...` or absolute paths
5. **Dependency integrity**: All `dependency_ids` must exist, no cycles
6. **Testing gate**: At least one non-N/A test required
7. **Evidence gate**: `completed_evidence` must reference artifacts or verification keywords
8. **N/A budget**: Max 20% of required fields can be N/A
9. **Recursive N/A detection**: Detects N/A anywhere in nested objects/arrays
10. **Placeholder detection**: `TBD`, `TODO`, `FIXME`, `as needed`, `etc.` all require justification
11. **Path hygiene**: No `..`, `~`, backslashes, or leading whitespace in paths
12. **Phase ordering**: Phases sort numerically (2.9 < 2.10, not lexicographically)

### N/A Justifications (Dot-Path Format)

The `na_justifications` field uses dot-path keys to identify exactly where N/A values appear:

```json
{
  "na_justifications": {
    "telemetry_events[0]": "No telemetry needed for internal refactor",
    "contracts.persistence[0]": "Pure UI component, no persistence",
    "test_plan.perf[0]": "Performance not a concern for this small utility"
  }
}
```

Key format examples:
- `field_name` - Top-level field
- `field_name[0]` - First array element
- `nested.field[0]` - Nested object array element
- `contracts.persistence[0]` - Deep nesting

## Workflow

### Adding a New Atom

1. Copy `atom.template.v2.json` as starting point
2. Fill all required fields (no placeholders, no `...`)
3. Add N/A justifications for any N/A fields
4. Append as single line to `atoms.jsonl`
5. Run `make validate-atoms`
6. If validation passes, run `make render-roadmap`
7. Commit both `atoms.jsonl` and `docs/roadmap/feature-roadmap.md`

### Editing Atoms

1. Never edit `docs/roadmap/feature-roadmap.md` directly
2. Edit the atom in `atoms.jsonl`
3. Update `updated_at` timestamp
4. Run `make atoms` (validates + renders)
5. Commit changes

### Migration from Legacy

- Legacy atoms in `docs/atoms.jsonl` (v1) should be migrated to v2
- Incomplete atoms go to `backlog.jsonl` with `status: "blocked"`
- Migration script: `scripts/migrate_atoms_v1_to_v2.py` (if needed)

## Commands

```bash
# Validate atoms
make validate-atoms
python3 scripts/validate_atoms.py docs/atoms/atoms.jsonl --schema v2

# Validate template (single JSON file)
python3 scripts/validate_atoms.py --validate-template docs/atoms/atom.template.v2.json --schema v2

# Render roadmap from atoms
make render-roadmap
python3 scripts/render_atoms_roadmap.py

# Both (validate then render)
make atoms

# Run adversarial smoke tests
./scripts/smoke_test_atoms_pipeline.sh
```

## CI Integration

The CI pipeline runs validation on every PR. If validation fails:
1. Check the error messages for specific atom IDs and fields
2. Fix the issues in `atoms.jsonl`
3. Push updated changes

## Golden Rules

1. **JSONL is source of truth** - Never edit markdown roadmap directly
2. **No ellipsis** - If content is too long, restructure it
3. **No guessing** - If you can't specify it, mark as blocked
4. **Repo-relative only** - All paths must be relative to repo root
5. **Justify N/A** - Every N/A needs a reason in `na_justifications`
