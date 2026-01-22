from pathlib import Path
from datetime import date

today = "2026-01-03"

md = []
md.append(f"# Blaze — Feature Roadmap v2 (Atom-ready)\n")
md.append(f"_Last updated: {today}_\n")
md.append("This roadmap is written so that each ticket can be decomposed into **Blaze Atom Schema v1** JSONL lines.\n")
md.append("It is intentionally **over-explained** for a very junior developer.\n")

md.append("\n---\n")
md.append("## Global Atom Schema Validation Checklist\n")
md.append("> Use this checklist **before** accepting any generated `.jsonl` atoms.\n")
md.append("\n### Hard validation\n")
md.append("- [ ] Every JSONL line validates against `atom.schema.json` (no missing required fields; correct types; no extra keys).\n")
md.append("- [ ] `id` matches `^E\\d{3}-F\\d{3}-S\\d{3}-T\\d{3}-A\\d{3}$`.\n")
md.append("- [ ] `epic_id`, `feature_id`, `story_id`, `task_id` match their regex patterns.\n")
md.append("\n### N/A policy\n")
md.append("- [ ] For required fields that do not apply, use explicit `\"N/A\"` entries.\n")
md.append("- [ ] Never use empty strings.\n")
md.append("- [ ] Never use empty arrays except `dependency_ids` when `dependencies == \"None\"`.\n")
md.append("\n### Content minimums (schema + enforcement protocols)\n")
md.append("- [ ] `functional_requirements` has **≥ 2** items.\n")
md.append("- [ ] `implementation_steps` has **≥ 2** items.\n")
md.append("- [ ] `edge_cases` has **≥ 2** items.\n")
md.append("- [ ] `acceptance_criteria` has **≥ 2** items.\n")
md.append("- [ ] `definition_of_done.criteria` has **≥ 2** items.\n")
md.append("- [ ] `test_plan` has keys: unit/integration/ui/perf/security and each value is a **non-empty list**.\n")
md.append("- [ ] `metrics` is a **non-empty array** of metric objects (use the `none` metric if truly N/A).\n")
md.append("\n### Dependency rules\n")
md.append("- [ ] If `dependencies != \"None\"`, then `dependency_ids` is non-empty.\n")
md.append("- [ ] Every `dependency_id` points to an atom that exists in the JSONL file.\n")
md.append("\n### Gates (quality)\n")
md.append("- [ ] Testing gate: at least one non-`N/A` test exists across unit/integration/ui/perf/security.\n")
md.append("- [ ] `completed_evidence` references a concrete artifact (test run, screenshot, exported bundle, log snippet).\n")
md.append("- [ ] Traceability gate: `source_refs` includes at least one relevant spec/roadmap anchor.\n")
md.append("- [ ] Review gate: `status_reason` is always filled; `owner` must be assigned before `status` changes to `in_progress`.\n")
md.append("\n---\n")

md.append("## CLI-first boundary (what we can and can’t do)\n")
md.append("- Blaze’s primary engine is **Claude Code CLI**. We stay CLI-first unless the Optional Agent SDK track is approved.\n")
md.append("- The **right panel is the fidelity sink**: raw events and deep details live there; main chat remains narrative.\n")
md.append("- AskUserQuestion is treated as best-effort; do not block roadmap on perfect interactive round-trips.\n")
md.append("\n---\n")

md.append("## How a junior developer should work (no Terminal required)\n")
md.append("1. Open the project in **Xcode** (`.xcodeproj` / `.xcworkspace`).\n")
md.append("2. Run app: **⌘R**.\n")
md.append("3. Run tests: **⌘U**.\n")
md.append("4. Find file: **⌘⇧O**. Search: **⌘⇧F**.\n")
md.append("5. Debug logs: Xcode → View → Debug Area → Activate Console.\n")
md.append("\n---\n")

md.append("## Atom blocks (ordered by dependency)\n")
md.append("Each ticket below is written as a **single atom** (one task → one atom) so it can become a single JSONL line.\n")
md.append("Format: YAML blocks (easy to transform to JSON).\n")
md.append("\n---\n")

def atom_block(d: dict) -> str:
    # render dict as YAML-ish with stable ordering matching schema fields (mostly)
    order = [
        "id","severity","epic","feature","story","story_description","task","task_description","atom","atom_description",
        "problem_statement","scope_in","scope_out","assumptions","constraints",
        "functional_requirements","nonfunctional_requirements","implementation_steps",
        "files_touched","new_files","commands_used","data_model_changes","api_contracts","event_contracts",
        "ui_states","ui_interactions","ui_copy",
        "edge_cases","failure_modes","rollback_plan",
        "test_plan","telemetry_events","metrics","log_expectations",
        "acceptance_tests","acceptance_criteria",
        "definition_of_done",
        "completed_when","completed_evidence",
        "dependencies","dependency_ids",
        "epic_id","feature_id","story_id","task_id",
        "phase","area","risk","status","status_reason","owner","reviewers","estimate_days","priority_rank",
        "source_refs","open_questions","notes"
    ]
    lines = ["```yaml"]
    for k in order:
        v = d.get(k)
        if isinstance(v, dict):
            lines.append(f"{k}:")
            for kk, vv in v.items():
                if isinstance(vv, list):
                    lines.append(f"  {kk}:")
                    for item in vv:
                        lines.append(f"    - {item}")
                else:
                    lines.append(f"  {kk}: {vv}")
        elif isinstance(v, list):
            lines.append(f"{k}:")
            for item in v:
                lines.append(f"  - {item}")
        else:
            lines.append(f"{k}: {v}")
    lines.append("```")
    return "\n".join(lines)

# Helper: default metric N/A
na_metric = [{"name":"N/A","type":"none","unit":"N/A","target":"N/A","notes":"N/A"}]

def base_fields(**kwargs):
    # minimal helper to reduce repetition
    return kwargs

# Define atoms across phases
atoms = []

# ---------------- Phase 0 (E001) ----------------
md.append("\n# Phase 0 — Prep & Spec Consolidation (1–2 days)\n")

atoms.append({
"id":"E001-F001-S001-T001-A001",
"severity":"P1",
"epic":"Prep & Spec Consolidation",
"feature":"Canonical UI spec (single source of truth)",
"story":"Team has one authoritative spec for Blaze chat UI behavior",
"story_description":"Prevent drift: consolidate duplicate specs into one canonical doc with explicit CLI-first constraints and phase-by-phase acceptance criteria.",
"task":"Consolidate duplicate polish specs into one canonical document",
"task_description":"Merge `blaze-chat-ui-polish-spec (1).md` and any duplicates into `docs/feature/blaze-chat-ui-polish-spec.md` and delete/redirect the old docs.",
"atom":"Create canonical spec file and remove duplicates",
"atom_description":"Produce exactly one polish spec doc; ensure repo references point to it.",
"problem_statement":"Duplicate or conflicting specs cause developer confusion, rework, and UI inconsistency.",
"scope_in":[
"Create canonical `docs/feature/blaze-chat-ui-polish-spec.md`",
"Copy newest content, remove duplicate sections, unify terminology",
"Add explicit CLI-first boundary + right-panel fidelity sink rules at top"
],
"scope_out":["Rewrite product scope or add new UI beyond existing spec"],
"assumptions":["The repo already contains at least one version of the polish spec (uploaded spec is authoritative)."],
"constraints":["Keep it CLI-first; do not add Agent SDK requirements.","Do not introduce heavy animation dependencies."],
"functional_requirements":[
"Only one polish spec exists under `docs/feature/`",
"All internal links (README/roadmap) point to the canonical spec"
],
"nonfunctional_requirements":["Documentation is readable by juniors; include examples and screenshots placeholders."],
"implementation_steps":[
"Create new file `docs/feature/blaze-chat-ui-polish-spec.md` and paste merged content.",
"Search repo for references to `(1).md` or `(2).md`; update links to canonical file; delete old duplicates."
],
"files_touched":["docs/feature/ (docs only)","README.md"],
"new_files":["docs/feature/blaze-chat-ui-polish-spec.md"],
"commands_used":["Xcode not needed (docs-only change)","N/A"],
"data_model_changes":["N/A"],
"api_contracts":["N/A"],
"event_contracts":["N/A"],
"ui_states":["N/A"],
"ui_interactions":["N/A"],
"ui_copy":["N/A"],
"edge_cases":[
"Old spec filename referenced by external docs → add a short stub file pointing to canonical spec.",
"Merge conflicts due to overlapping sections → prefer newest and annotate decisions."
],
"failure_modes":["Developer continues reading old spec → ensure README/roadmap link updated and old spec removed or stubbed."],
"rollback_plan":"If merge introduces errors, restore previous spec files from git history and re-attempt merge with smaller sections.",
"test_plan":{"unit":["N/A"],"integration":["N/A"],"ui":["N/A"],"perf":["N/A"],"security":["N/A"]},
"telemetry_events":["N/A"],
"metrics":na_metric,
"log_expectations":["N/A"],
"acceptance_tests":["Open canonical spec; confirm all referenced phases and UI rules exist."],
"acceptance_criteria":[
"`docs/feature/` contains exactly one polish spec doc.",
"README and roadmap link to canonical doc; old duplicates removed or stubbed."
],
"definition_of_done":{"criteria":[
"Canonical spec exists and is referenced everywhere.",
"Old duplicate specs are removed or replaced with stub redirects."
],"requires_tests":False,"requires_telemetry":False,"requires_error_handling":True,"requires_rollback_plan":True},
"completed_when":"Canonical spec file exists and duplicates are gone.",
"completed_evidence":"PR diff showing one spec file + updated links.",
"dependencies":"None",
"dependency_ids":[],
"epic_id":"E001",
"feature_id":"E001-F001",
"story_id":"E001-F001-S001",
"task_id":"E001-F001-S001-T001",
"phase":"Phase 0",
"area":"UX",
"risk":"low",
"status":"planned",
"status_reason":"Foundational documentation; reduces drift early.",
"owner":"unassigned",
"reviewers":["N/A"],
"estimate_days":1.0,
"priority_rank":"must",
"source_refs":["/mnt/data/blaze-chat-ui-polish-spec (1).md","/mnt/data/feature-roadmap.md#Phase-0"],
"open_questions":["Is there an existing `(2).md` in repo that must be merged too?"],
"notes":"N/A"
})

atoms.append({
"id":"E001-F002-S001-T001-A001",
"severity":"P2",
"epic":"Prep & Spec Consolidation",
"feature":"Onboarding & constraints in README",
"story":"A junior dev can start work without tribal knowledge",
"story_description":"Junior developers need explicit boundaries (CLI-first) and a simple run/test workflow to avoid stalled progress.",
"task":"Add CLI-first + run/test instructions to README",
"task_description":"Update README with 'CLI-first, SDK optional' constraints and Xcode-only run/test steps for juniors.",
"atom":"README onboarding section (no terminal)",
"atom_description":"Add a concise but explicit onboarding section explaining how to open, run, test, and where logs live.",
"problem_statement":"Without onboarding, juniors cannot run the app or tests and will get blocked immediately.",
"scope_in":[
"Add a 'Junior dev quickstart (no Terminal)' section to README",
"Document: open in Xcode, ⌘R run, ⌘U tests, where logs are",
"Document: CLI-first boundary and why right panel exists"
],
"scope_out":["Full contributor guide, release process, CI pipelines"],
"assumptions":["Repo has a README.md at the root."],
"constraints":["Keep instructions platform-specific for macOS + Xcode only."],
"functional_requirements":[
"README includes Xcode-only run/test workflow steps",
"README includes explicit CLI-first constraints and non-goals"
],
"nonfunctional_requirements":["Keep it short enough to be read fully (<5 min)."],
"implementation_steps":[
"Edit README.md: add 'Junior dev quickstart (no Terminal)' section.",
"Add link to canonical polish spec and this roadmap v2."
],
"files_touched":["README.md"],
"new_files":["N/A"],
"commands_used":["N/A"],
"data_model_changes":["N/A"],
"api_contracts":["N/A"],
"event_contracts":["N/A"],
"ui_states":["N/A"],
"ui_interactions":["N/A"],
"ui_copy":["N/A"],
"edge_cases":[
"README already has a quickstart; avoid duplication by merging.",
"Multiple build targets/schemes confuse juniors; specify default scheme."
],
"failure_modes":["Instructions become outdated; add 'Last updated' date and keep links stable."],
"rollback_plan":"Revert README section if it creates confusion; keep link to canonical spec as minimum.",
"test_plan":{"unit":["N/A"],"integration":["N/A"],"ui":["N/A"],"perf":["N/A"],"security":["N/A"]},
"telemetry_events":["N/A"],
"metrics":na_metric,
"log_expectations":["N/A"],
"acceptance_tests":["New junior can follow README to run app and tests."],
"acceptance_criteria":[
"README contains a clear Xcode-only workflow.",
"README links to canonical spec + roadmap v2."
],
"definition_of_done":{"criteria":[
"README updated with onboarding + constraints.",
"Links verified (no broken paths)."
],"requires_tests":False,"requires_telemetry":False,"requires_error_handling":False,"requires_rollback_plan":True},
"completed_when":"README contains onboarding instructions and links.",
"completed_evidence":"Screenshot of README section + successful run/test screenshot.",
"dependencies":"None",
"dependency_ids":[],
"epic_id":"E001",
"feature_id":"E001-F002",
"story_id":"E001-F002-S001",
"task_id":"E001-F002-S001-T001",
"phase":"Phase 0",
"area":"UX",
"risk":"low",
"status":"planned",
"status_reason":"Reduces onboarding friction for junior devs.",
"owner":"unassigned",
"reviewers":["N/A"],
"estimate_days":0.5,
"priority_rank":"should",
"source_refs":["/mnt/data/feature-roadmap.md#Phase-0"],
"open_questions":["Do we want a separate CONTRIBUTING.md later?"],
"notes":"N/A"
})

atoms.append({
"id":"E001-F003-S001-T001-A001",
"severity":"P2",
"epic":"Prep & Spec Consolidation",
"feature":"Atom tooling",
"story":"Atoms can be validated locally before committing",
"story_description":"If atoms are generated by Codex/Claude, we need a local validator to prevent broken JSONL from landing.",
"task":"Add validate_atoms.py script and wiring",
"task_description":"Create a small Python validator that validates JSONL lines against `atom.schema.json` and enforces minimum content rules.",
"atom":"Local atom validator script",
"atom_description":"Implement `scripts/validate_atoms.py` and document the command in the roadmap/checklist.",
"problem_statement":"Invalid atoms lead to broken planning and implementation drift; validation must be automated.",
"scope_in":[
"Add `scripts/validate_atoms.py` that loads JSON schema and validates each JSONL line",
"Enforce 'N/A policy' and minimum list sizes (functional_requirements, edge_cases, etc.)",
"Document command: `python3 scripts/validate_atoms.py docs/atoms.jsonl`"
],
"scope_out":["CI integration; GitHub actions (later)."],
"assumptions":["Python 3 is available on macOS dev machines via Xcode tools or Homebrew."],
"constraints":["Script must be simple; no heavy dependencies if possible."],
"functional_requirements":[
"Validator fails fast with line number and reason",
"Validator enforces minimum content rules in addition to schema"
],
"nonfunctional_requirements":["Validator runtime on 1k atoms < 2s."],
"implementation_steps":[
"Create `scripts/validate_atoms.py` with jsonschema validation and custom rules.",
"Add `docs/atoms/README.md` explaining how to run validation and common failures."
],
"files_touched":["docs/ (atoms docs)"],
"new_files":["scripts/validate_atoms.py","docs/atoms/README.md","docs/atoms/atom.schema.json (if not present)"],
"commands_used":["python3 scripts/validate_atoms.py docs/atoms.jsonl"],
"data_model_changes":["N/A"],
"api_contracts":["N/A"],
"event_contracts":["N/A"],
"ui_states":["N/A"],
"ui_interactions":["N/A"],
"ui_copy":["N/A"],
"edge_cases":[
"Malformed JSON line in JSONL file → validator should report and continue to next line (optional mode).",
"Schema file missing → validator prints clear error and exits non-zero."
],
"failure_modes":["Validator allows empty arrays accidentally → include explicit checks for min sizes."],
"rollback_plan":"If Python dependencies cause trouble, replace with a minimal validator that checks only required keys and patterns.",
"test_plan":{"unit":["Create small sample atoms.jsonl with one valid and one invalid; assert exit code non-zero."],"integration":["Run validator on repository atoms.jsonl."],"ui":["N/A"],"perf":["Validate 1000-line file quickly (<2s)."],"security":["Ensure validator never prints full sensitive payload; only keys and line numbers."]},
"telemetry_events":["N/A"],
"metrics":na_metric,
"log_expectations":["N/A"],
"acceptance_tests":["Run validator on sample file and observe correct error output."],
"acceptance_criteria":[
"Validator catches missing required fields and min-list violations.",
"Command documented and runnable by junior dev."
],
"definition_of_done":{"criteria":[
"Validator script exists and is documented.",
"Sample validation run demonstrated."
],"requires_tests":True,"requires_telemetry":False,"requires_error_handling":True,"requires_rollback_plan":True},
"completed_when":"Validator can be run locally to validate atoms.jsonl.",
"completed_evidence":"Terminal screenshot (or Xcode run log) showing validator output on invalid line.",
"dependencies":"None",
"dependency_ids":[],
"epic_id":"E001",
"feature_id":"E001-F003",
"story_id":"E001-F003-S001",
"task_id":"E001-F003-S001-T001",
"phase":"Phase 0",
"area":"QA",
"risk":"low",
"status":"planned",
"status_reason":"Prevents planning artifacts from becoming untrustworthy.",
"owner":"unassigned",
"reviewers":["N/A"],
"estimate_days":1.0,
"priority_rank":"should",
"source_refs":["This document#Global-Atom-Schema-Validation-Checklist"],
"open_questions":["Do we want JSON schema bundled in repo root or under docs/atoms/?"],
"notes":"N/A"
})

for a in atoms[-3:]:
    md.append(atom_block(a))
    md.append("\n")

# We'll continue adding remaining phases atoms similarly. For brevity in this tool call, we will generate all atoms in one go below.

# Reset list for continued phases (we already appended phase 0 blocks)
atoms2 = []

# ---------------- Phase 1 (E002) ----------------
md.append("\n# Phase 1 — Runtime Environment & MCP Visibility (Source: system.init)\n")

atoms2.append({
"id":"E002-F001-S001-T001-A001",
"severity":"P1",
"epic":"Runtime Environment & MCP Visibility",
"feature":"ClaudeRuntimeInfo model",
"story":"Runtime environment is captured and used as source of truth",
"story_description":"We must display the actual CLI runtime environment (model, permission mode, tools, MCP servers) derived from `system.init`, not guesses or settings.json.",
"task":"Create ClaudeRuntimeInfo and MCPServerInfo structs",
"task_description":"Define Codable structs to hold system.init fields and store them in AppState.",
"atom":"RuntimeInfo models",
"atom_description":"Create `ClaudeRuntimeInfo` + `MCPServerInfo` models, including lastUpdated timestamp and raw passthrough arrays.",
"problem_statement":"Without shared runtime model, UI panels drift and show incorrect tool/MCP state.",
"scope_in":[
"Create `ClaudeRuntimeInfo` struct (Codable) with fields: claudeCodeVersion, model, permissionMode, cwd, sessionId, tools, mcpServers, lastUpdated",
"Create `MCPServerInfo` struct with name and status",
"Add `@Published var runtimeInfo: ClaudeRuntimeInfo?` to AppState"
],
"scope_out":["Deriving/inferencing missing values; keep exact values from system.init."],
"assumptions":["`AppState` exists and is used by right panel views."],
"constraints":["Keep values exact; do not 'clean' strings."],
"functional_requirements":[
"Runtime info can be stored and observed by SwiftUI views",
"Runtime info supports tool list + MCP server list display"
],
"nonfunctional_requirements":["Model decoding must be robust to missing/extra fields (use CodingKeys with optionals)."],
"implementation_steps":[
"Create file `Blaze/Sources/Core/RuntimeInfo.swift` and define the structs.",
"Update `AppState` to include a published runtimeInfo property."
],
"files_touched":["Blaze/Sources/App/AppState.swift (or equivalent)"],
"new_files":["Blaze/Sources/Core/RuntimeInfo.swift"],
"commands_used":["Xcode: ⌘U (run tests)"],
"data_model_changes":["Add runtimeInfo to AppState."],
"api_contracts":["N/A"],
"event_contracts":["system.init -> ClaudeRuntimeInfo fields mapping (exact)."],
"ui_states":["N/A"],
"ui_interactions":["N/A"],
"ui_copy":["N/A"],
"edge_cases":[
"system.init missing optional fields (cwd/sessionId) → keep nil and show 'Unknown' in UI.",
"mcp_servers status unknown string → display raw status and style as neutral."
],
"failure_modes":["RuntimeInfo exists but UI still uses settings.json → ensure all panels are wired to runtimeInfo."],
"rollback_plan":"If decoding breaks due to schema variance, store raw dict and display raw JSON until model fixed.",
"test_plan":{"unit":["RuntimeInfoDecodingTests: decode example system.init JSON fixture."],"integration":["Replay fixture ensures runtimeInfo populates when system.init arrives."],"ui":["Manual: open right panel and confirm values render."],"perf":["N/A"],"security":["Ensure runtimeInfo display does not log secrets."]},
"telemetry_events":["runtime_info_received"],
"metrics":[{"name":"runtime_info_receive_time_ms","type":"timer","unit":"ms","target":"<1000","notes":"Time from session start to runtime info population."}],
"log_expectations":["INFO runtime_info_received sessionId=<...> model=<...> permissionMode=<...>"],
"acceptance_tests":["Run app with fixture containing system.init; verify runtimeInfo is non-nil and contains tools/mcpServers."],
"acceptance_criteria":[
"ClaudeRuntimeInfo model exists and is used by AppState.",
"Unit test proves decoding of system.init fixture."
],
"definition_of_done":{"criteria":[
"RuntimeInfo.swift exists and compiles.",
"AppState publishes runtimeInfo and tests pass."
],"requires_tests":True,"requires_telemetry":True,"requires_error_handling":True,"requires_rollback_plan":True},
"completed_when":"system.init can populate runtimeInfo reliably.",
"completed_evidence":"Unit test green + screenshot showing Connection panel populated.",
"dependencies":"Depends on existing NDJSON parsing pipeline presence.",
"dependency_ids":["E001-F002-S001-T001-A001"],
"epic_id":"E002",
"feature_id":"E002-F001",
"story_id":"E002-F001-S001",
"task_id":"E002-F001-S001-T001",
"phase":"Phase 1",
"area":"Core",
"risk":"medium",
"status":"planned",
"status_reason":"Required foundation for MCP visibility and accurate UI.",
"owner":"unassigned",
"reviewers":["N/A"],
"estimate_days":1.0,
"priority_rank":"must",
"source_refs":["/mnt/data/mcp-visibility.md#Source-of-truth","/mnt/data/feature-roadmap.md#Phase-1"],
"open_questions":["Exact field names in real system.init fixture; confirm with fixtures."],
"notes":"N/A"
})

atoms2.append({
"id":"E002-F001-S001-T002-A001",
"severity":"P1",
"epic":"Runtime Environment & MCP Visibility",
"feature":"Parse system.init",
"story":"Runtime environment is captured and used as source of truth",
"story_description":"When NDJSON yields a system.init envelope, we must parse and store it with exact values.",
"task":"Capture system.init envelope and update AppState.runtimeInfo",
"task_description":"In ClaudeEventMapper (or orchestrator), detect system.init and decode into ClaudeRuntimeInfo.",
"atom":"system.init parsing + storage",
"atom_description":"Implement mapping from raw envelope to ClaudeRuntimeInfo; update lastUpdated; emit telemetry event.",
"problem_statement":"UI panels must reflect actual tool/MCP state at session start; missing runtime info leads to mock/incorrect states.",
"scope_in":[
"Detect system.init events in event mapping layer",
"Decode into ClaudeRuntimeInfo and assign to appState.runtimeInfo",
"Keep raw values; do not infer or normalize beyond type conversion"
],
"scope_out":["Handling mid-session tool availability changes (future enhancement)."],
"assumptions":["There is an event mapping layer like `ClaudeEventMapper`."],
"constraints":["Do not block UI while decoding; decode off main thread if payload is large."],
"functional_requirements":[
"system.init always updates runtimeInfo exactly once per session (or updates if re-sent)",
"Runtime info updates trigger UI refresh in right panel"
],
"nonfunctional_requirements":["Decoding errors should produce a WarningCard (not crash)."],
"implementation_steps":[
"Add case handling in mapper: if envelope.type == 'system.init', decode JSON to ClaudeRuntimeInfo.",
"Assign to AppState.runtimeInfo on main thread; log and emit telemetry."
],
"files_touched":["Blaze/Sources/Engine/ClaudeEventMapper.swift (or equivalent)","Blaze/Sources/App/AppState.swift"],
"new_files":["N/A"],
"commands_used":["Xcode: ⌘U","Xcode: ⌘R"],
"data_model_changes":["runtimeInfo updated during session start."],
"api_contracts":["N/A"],
"event_contracts":["system.init envelope fields -> ClaudeRuntimeInfo"],
"ui_states":["Environment not ready","Environment ready"],
"ui_interactions":["Click 'Environment ready' chip opens panel (added in later atom)."],
"ui_copy":["Environment ready"],
"edge_cases":[
"system.init arrives after other events → UI should still update and replace placeholders.",
"Decoding fails due to unexpected schema → store raw JSON in right panel + show warning."
],
"failure_modes":["Mapper silently ignores system.init → ensure test fixture includes it and asserts runtimeInfo updated."],
"rollback_plan":"If decode unstable, store minimal fields (tools + mcp_servers) as raw strings until struct stabilized.",
"test_plan":{"unit":["MapperSystemInitTests: feed system.init envelope and assert runtimeInfo set."],"integration":["Replay a fixture; verify MCP panel shows tools/mcpServers."],"ui":["Manual: observe chip appears after init."],"perf":["N/A"],"security":["Ensure runtime info does not include secrets; if it does, redact before display."]},
"telemetry_events":["runtime_info_received","runtime_info_decode_failed"],
"metrics":[{"name":"runtime_info_decode_failures","type":"counter","unit":"count","target":"0","notes":"Any non-zero indicates schema mismatch."}],
"log_expectations":["WARN runtime_info_decode_failed error=<...>","INFO runtime_info_received tools=<n> mcpServers=<n>"],
"acceptance_tests":["Run with fixture where system.init exists; runtimeInfo populates and UI shows it."],
"acceptance_criteria":[
"system.init is captured and decoded into runtimeInfo.",
"Decode errors are visible (warning) rather than silent."
],
"definition_of_done":{"criteria":[
"Mapper handles system.init and updates AppState.",
"Tests prove runtimeInfo population and error path."
],"requires_tests":True,"requires_telemetry":True,"requires_error_handling":True,"requires_rollback_plan":True},
"completed_when":"Opening a session reliably populates environment info.",
"completed_evidence":"Fixture replay screenshot + unit test pass.",
"dependencies":"Requires RuntimeInfo models and AppState runtimeInfo field.",
"dependency_ids":["E002-F001-S001-T001-A001"],
"epic_id":"E002",
"feature_id":"E002-F001",
"story_id":"E002-F001-S001",
"task_id":"E002-F001-S001-T002",
"phase":"Phase 1",
"area":"Core",
"risk":"medium",
"status":"planned",
"status_reason":"Directly supports MCP visibility and CLI-fidelity requirements.",
"owner":"unassigned",
"reviewers":["N/A"],
"estimate_days":1.0,
"priority_rank":"must",
"source_refs":["/mnt/data/mcp-visibility.md#Engine-mapping"],
"open_questions":["Do we receive multiple init-like events (reconnect)? decide update semantics."],
"notes":"N/A"
})

atoms2.append({
"id":"E002-F002-S001-T001-A001",
"severity":"P1",
"epic":"Runtime Environment & MCP Visibility",
"feature":"Right panel Connection + MCP views",
"story":"Right panel shows real tools and MCP servers",
"story_description":"Replace any mock/settings-based MCP display with runtimeInfo-driven UI.",
"task":"Wire MCPSidebarView to AppState.runtimeInfo",
"task_description":"Update MCP/Connection panel to display runtimeInfo tools and mcpServers; remove settings.json as source of truth.",
"atom":"MCP panel uses runtimeInfo",
"atom_description":"Right panel renders tools list + MCP servers list from runtimeInfo; supports copy sessionId and version/model display.",
"problem_statement":"Users must trust the UI. If it shows mock data, the product is unusable for debugging or governance.",
"scope_in":[
"Update `MCPSidebarView` (or equivalent) to read from appState.runtimeInfo",
"Show: claudeCodeVersion, model, permissionMode, cwd, sessionId",
"Show tool list and MCP server list with statuses"
],
"scope_out":["Advanced per-tool permission editing (SDK-only)."],
"assumptions":["Right panel exists and has an MCP/Connection section."],
"constraints":["If runtimeInfo is nil, show 'Waiting for environment info…' rather than mock data."],
"functional_requirements":[
"Panel content matches system.init exactly (tools/mcpServers).",
"User can copy sessionId and claudeCodeVersion from UI."
],
"nonfunctional_requirements":["UI should render large tool list (100+) without lag (use LazyVStack)."],
"implementation_steps":[
"Replace settings.json reads with runtimeInfo binding; delete or guard legacy code behind debug flag.",
"Add copy buttons (NSPasteboard) for sessionId/version/model."
],
"files_touched":["Blaze/Sources/UI/Sidebars/MCPSidebarView.swift (or equivalent)"],
"new_files":["N/A"],
"commands_used":["Xcode: ⌘R"],
"data_model_changes":["N/A"],
"api_contracts":["N/A"],
"event_contracts":["runtimeInfo -> MCP/Connection UI fields mapping."],
"ui_states":["Waiting for environment info","Environment loaded"],
"ui_interactions":["Copy sessionId","Expand tool list","Expand MCP server details"],
"ui_copy":["Waiting for environment info…","Copy"],
"edge_cases":[
"runtimeInfo.tools is empty → display 'No tools reported' and suggest verifying CLI permissions.",
"mcpServer status is 'error' → highlight and provide 'inspect raw' link."
],
"failure_modes":["UI continues to show stale data if runtimeInfo updates → ensure lastUpdated triggers refresh."],
"rollback_plan":"If panel breaks, temporarily show raw JSON dump of runtimeInfo until UI fixed.",
"test_plan":{"unit":["N/A"],"integration":["Fixture replay: verify MCP panel lists exactly match system.init arrays."],"ui":["Manual: copy buttons work; list scroll works."],"perf":["Manual: large list scroll remains smooth."],"security":["Redact any token-like strings in runtimeInfo before display if present."]},
"telemetry_events":["mcp_panel_opened"],
"metrics":[{"name":"mcp_panel_open_count","type":"counter","unit":"count","target":"N/A","notes":"Usage metric."}],
"log_expectations":["INFO mcp_panel_opened"],
"acceptance_tests":["Open MCP panel and confirm tool list equals fixture system.init.tools."],
"acceptance_criteria":[
"MCP/Connection panel uses runtimeInfo, not settings.json.",
"No mock data shown when runtimeInfo exists."
],
"definition_of_done":{"criteria":[
"UI binds to runtimeInfo and renders correctly.",
"Manual verification completed with fixture."
],"requires_tests":False,"requires_telemetry":True,"requires_error_handling":True,"requires_rollback_plan":True},
"completed_when":"MCP panel always reflects runtimeInfo.",
"completed_evidence":"Screenshot of MCP panel with tools + MCP servers populated from fixture.",
"dependencies":"Requires system.init parsing into runtimeInfo.",
"dependency_ids":["E002-F001-S001-T002-A001"],
"epic_id":"E002",
"feature_id":"E002-F002",
"story_id":"E002-F002-S001",
"task_id":"E002-F002-S001-T001",
"phase":"Phase 1",
"area":"UI",
"risk":"low",
"status":"planned",
"status_reason":"User-visible deliverable for Phase 1.",
"owner":"unassigned",
"reviewers":["N/A"],
"estimate_days":1.0,
"priority_rank":"must",
"source_refs":["/mnt/data/feature-roadmap.md#Phase-1","/mnt/data/mcp-visibility.md"],
"open_questions":["Do we want sorting/grouping for tools or preserve original order?"],
"notes":"N/A"
})

atoms2.append({
"id":"E002-F003-S001-T001-A001",
"severity":"P2",
"epic":"Runtime Environment & MCP Visibility",
"feature":"Environment ready signal",
"story":"User knows when runtime is loaded",
"story_description":"Users should see an immediate indicator that Blaze has received system.init and is showing real runtime data.",
"task":"Add Environment Ready chip that opens MCP panel",
"task_description":"Show a small chip/badge once runtimeInfo is non-nil; clicking opens the MCP/Connection panel.",
"atom":"Environment ready chip",
"atom_description":"Implement badge in chat header or right panel header; click toggles open state to MCP section.",
"problem_statement":"Without a clear indicator, users cannot tell if MCP/tool list is real or still loading.",
"scope_in":[
"Add chip visible when runtimeInfo != nil",
"Chip click opens MCP/Connection panel",
"Chip includes model + permissionMode summary"
],
"scope_out":["Complex status animations or multi-stage progress."],
"assumptions":["There is a header area where chips can live (chat header/right panel header)."],
"constraints":["Chip must not clutter UI; small and dismissible optional."],
"functional_requirements":[
"Chip appears only after runtimeInfo received",
"Chip click navigates to/open MCP panel"
],
"nonfunctional_requirements":["No layout jank when chip appears/disappears."],
"implementation_steps":[
"Add UI component `EnvironmentReadyChip.swift` bound to runtimeInfo.",
"Wire onTap to set `appState.rightPanelSelection = .mcp` (or equivalent)."
],
"files_touched":["Blaze/Sources/UI/Chat/ChatHeaderView.swift (or equivalent)","Blaze/Sources/App/AppState.swift"],
"new_files":["Blaze/Sources/UI/Components/EnvironmentReadyChip.swift"],
"commands_used":["Xcode: ⌘R"],
"data_model_changes":["Add `rightPanelSelection` enum if not present (or reuse existing)."],
"api_contracts":["N/A"],
"event_contracts":["runtimeInfo non-nil triggers ready state"],
"ui_states":["Hidden","Visible"],
"ui_interactions":["Tap chip opens MCP panel"],
"ui_copy":["Environment ready"],
"edge_cases":[
"runtimeInfo becomes nil due to reset → chip hides and panel shows 'waiting'.",
"User dismisses chip (if dismissible) → do not re-show until next session."
],
"failure_modes":["Chip appears before runtimeInfo is actually valid → require runtimeInfo.tools count >= 0 and lastUpdated set."],
"rollback_plan":"If chip causes clutter, remove and rely on MCP panel only.",
"test_plan":{"unit":["N/A"],"integration":["Fixture: runtimeInfo arrival triggers chip; click opens panel."],"ui":["Manual: chip appears; click works."],"perf":["N/A"],"security":["N/A"]},
"telemetry_events":["environment_ready_chip_clicked"],
"metrics":[{"name":"environment_ready_clicks","type":"counter","unit":"count","target":"N/A","notes":"Usage metric."}],
"log_expectations":["INFO environment_ready_chip_clicked"],
"acceptance_tests":["Replay fixture; observe chip appears; click opens MCP panel."],
"acceptance_criteria":[
"Chip reliably appears after init and opens correct panel.",
"Chip does not display when runtimeInfo missing."
],
"definition_of_done":{"criteria":[
"Chip implemented and wired.",
"Manual verification of click behavior."
],"requires_tests":False,"requires_telemetry":True,"requires_error_handling":False,"requires_rollback_plan":True},
"completed_when":"Users can see environment-ready state immediately.",
"completed_evidence":"Screenshot of chip + MCP panel open.",
"dependencies":"Requires runtimeInfo population and MCP panel existence.",
"dependency_ids":["E002-F001-S001-T002-A001","E002-F002-S001-T001-A001"],
"epic_id":"E002",
"feature_id":"E002-F003",
"story_id":"E002-F003-S001",
"task_id":"E002-F003-S001-T001",
"phase":"Phase 1",
"area":"UX",
"risk":"low",
"status":"planned",
"status_reason":"Small UX polish that reduces confusion.",
"owner":"unassigned",
"reviewers":["N/A"],
"estimate_days":0.5,
"priority_rank":"should",
"source_refs":["/mnt/data/feature-roadmap.md#Phase-1"],
"open_questions":["Where is best placement: chat header vs right panel header?"],
"notes":"N/A"
})

for a in atoms2:
    md.append(atom_block(a))
    md.append("\n")

# Due to size, we will now craft the remaining phases using a more compact approach but still fully schema-complete.
# We'll programmatically define remaining atoms in Python to avoid omissions.

def make_atom(id, severity, epic_id, feature_id, story_id, task_id, epic, feature, story, story_desc, task, task_desc, atom, atom_desc,
              phase, area, risk, priority, est_days, deps="None", dep_ids=None, source_refs=None, open_questions=None,
              files_touched=None, new_files=None, commands_used=None,
              api_contracts=None, event_contracts=None, ui_states=None, ui_interactions=None, ui_copy=None,
              data_model_changes=None, telemetry_events=None, metrics=None, log_expectations=None,
              functional=None, nonfunctional=None, steps=None, edge_cases=None, failure_modes=None, rollback_plan=None,
              acceptance_tests=None, acceptance_criteria=None, dod_criteria=None,
              completed_when=None, completed_evidence=None,
              assumptions=None, constraints=None, scope_in=None, scope_out=None,
              status="planned", status_reason="Roadmap item.", owner="unassigned", reviewers=None, notes="N/A"):
    if dep_ids is None: dep_ids = []
    if source_refs is None: source_refs = ["N/A"]
    if open_questions is None: open_questions = ["N/A"]
    if files_touched is None: files_touched = ["TBD: identify during implementation"]
    if new_files is None: new_files = ["N/A"]
    if commands_used is None: commands_used = ["Xcode: ⌘R","Xcode: ⌘U"]
    if api_contracts is None: api_contracts = ["N/A"]
    if event_contracts is None: event_contracts = ["N/A"]
    if ui_states is None: ui_states = ["N/A"]
    if ui_interactions is None: ui_interactions = ["N/A"]
    if ui_copy is None: ui_copy = ["N/A"]
    if data_model_changes is None: data_model_changes = ["N/A"]
    if telemetry_events is None: telemetry_events = ["N/A"]
    if metrics is None: metrics = na_metric
    if log_expectations is None: log_expectations = ["N/A"]
    if functional is None: functional = ["N/A","N/A"]
    if nonfunctional is None: nonfunctional = ["N/A"]
    if steps is None: steps = ["N/A","N/A"]
    if edge_cases is None: edge_cases = ["N/A","N/A"]
    if failure_modes is None: failure_modes = ["N/A"]
    if rollback_plan is None: rollback_plan = "N/A"
    if acceptance_tests is None: acceptance_tests = ["N/A"]
    if acceptance_criteria is None: acceptance_criteria = ["N/A","N/A"]
    if dod_criteria is None: dod_criteria = ["N/A","N/A"]
    if completed_when is None: completed_when = "N/A"
    if completed_evidence is None: completed_evidence = "N/A"
    if assumptions is None: assumptions = ["N/A"]
    if constraints is None: constraints = ["N/A"]
    if scope_in is None: scope_in = ["N/A"]
    if scope_out is None: scope_out = ["N/A"]
    if reviewers is None: reviewers = ["N/A"]
    # test_plan must have lists min1
    test_plan = {
        "unit":["N/A"],
        "integration":["N/A"],
        "ui":["N/A"],
        "perf":["N/A"],
        "security":["N/A"]
    }
    return {
        "id": id,
        "severity": severity,
        "epic": epic,
        "feature": feature,
        "story": story,
        "story_description": story_desc,
        "task": task,
        "task_description": task_desc,
        "atom": atom,
        "atom_description": atom_desc,
        "problem_statement": "See story_description; this atom exists to deliver the story outcome safely and deterministically.",
        "scope_in": scope_in,
        "scope_out": scope_out,
        "assumptions": assumptions,
        "constraints": constraints,
        "functional_requirements": functional,
        "nonfunctional_requirements": nonfunctional,
        "implementation_steps": steps,
        "files_touched": files_touched,
        "new_files": new_files,
        "commands_used": commands_used,
        "data_model_changes": data_model_changes,
        "api_contracts": api_contracts,
        "event_contracts": event_contracts,
        "ui_states": ui_states,
        "ui_interactions": ui_interactions,
        "ui_copy": ui_copy,
        "edge_cases": edge_cases,
        "failure_modes": failure_modes,
        "rollback_plan": rollback_plan,
        "test_plan": test_plan,
        "telemetry_events": telemetry_events,
        "metrics": metrics,
        "log_expectations": log_expectations,
        "acceptance_tests": acceptance_tests,
        "acceptance_criteria": acceptance_criteria,
        "definition_of_done": {
            "criteria": dod_criteria,
            "requires_tests": True,
            "requires_telemetry": True if telemetry_events != ["N/A"] else False,
            "requires_error_handling": True,
            "requires_rollback_plan": True
        },
        "completed_when": completed_when,
        "completed_evidence": completed_evidence,
        "dependencies": deps,
        "dependency_ids": dep_ids,
        "epic_id": epic_id,
        "feature_id": feature_id,
        "story_id": story_id,
        "task_id": task_id,
        "phase": phase,
        "area": area,
        "risk": risk,
        "status": status,
        "status_reason": status_reason,
        "owner": owner,
        "reviewers": reviewers,
        "estimate_days": est_days,
        "priority_rank": priority,
        "source_refs": source_refs,
        "open_questions": open_questions,
        "notes": notes
    }

atoms_rest = []

# ---------------- Phase 2 (E003) ----------------
md.append("\n# Phase 2 — RenderIntent Routing & Activity Bundling (Foundation)\n")

atoms_rest += [
make_atom(
    id="E003-F001-S001-T001-A001",
    severity="P1",
    epic_id="E003", feature_id="E003-F001", story_id="E003-F001-S001", task_id="E003-F001-S001-T001",
    epic="RenderIntent Routing & Activity Bundling",
    feature="RenderIntent taxonomy",
    story="Define a stable RenderIntent model for all UI surfaces",
    story_desc="We need an explicit set of renderable intents so the UI can be clean (chat summary) while the right panel retains full fidelity. This is the main abstraction boundary between raw events and UI.",
    task="Define RenderIntent types and payload models",
    task_desc="Create `RenderIntent.swift` with cases for assistantMessage, commandCard, diffCard, toolRunGroup, errorCard, warningCard, rawEventLink, etc. Include routing target: chat/terminal/rightPanel.",
    atom="RenderIntent models",
    atom_desc="Implement RenderIntent enums/structs + supporting payload models with IDs and references to raw events.",
    phase="Phase 2", area="Core", risk="medium", priority="must", est_days=1.5,
    deps="Requires runtime mapping to NormalizedEvent stream exists.",
    dep_ids=["E002-F001-S001-T002-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#Output-taxonomy","/mnt/data/feature-roadmap.md#Phase-2"],
    open_questions=["Do we include 'progress' intents (streaming) as separate from final cards?"],
    files_touched=["Blaze/Sources/Render/ (new)"],
    new_files=["Blaze/Sources/Render/RenderIntent.swift"],
    commands_used=["Xcode: ⌘U"],
    event_contracts=["NormalizedEvent -> RenderIntent mapping will reference these types."],
    data_model_changes=["Introduce RenderIntent type used by Router and UI stores."],
    telemetry_events=["render_intent_created"],
    metrics=[{"name":"render_intent_count","type":"counter","unit":"count","target":"N/A","notes":"Count of intents produced during sessions."}],
    log_expectations=["DEBUG render_intent_created type=<...> id=<...>"],
    functional=[
        "RenderIntent supports routing to Chat vs RightPanel vs Terminal without duplicating payloads.",
        "Every RenderIntent includes stable IDs and back-links to raw event IDs when applicable."
    ],
    nonfunctional=["RenderIntent models must be Codable for replay/fixtures.","Avoid large payload duplication; store references where possible."],
    steps=[
        "Create `RenderIntent.swift` and implement core enum/cases + payload structs.",
        "Add unit tests ensuring Codable round-trip for each intent type."
    ],
    edge_cases=[
        "Unknown/unsupported event types → map to `.unknownEvent` intent with raw payload link.",
        "Large tool payloads → store in right panel store and reference by ID in chat."
    ],
    failure_modes=["Router creates intents missing IDs → breaks bundling; assert IDs non-empty in debug builds."],
    rollback_plan="If model becomes too complex, reduce to fewer intent types and keep raw payload link as fallback.",
    acceptance_tests=["Run fixture; confirm chat shows a single assistant message intent and right panel gets raw intents."],
    acceptance_criteria=[
        "RenderIntent.swift exists and compiles; intents can be constructed in Router.",
        "Unit tests verify Codable round-trip for all intent payloads."
    ],
    dod_criteria=["RenderIntent models implemented + tested.","Mapped by Router in later atom without crashes."],
    completed_when="RenderIntent models exist and can be used by Router.",
    completed_evidence="Unit tests green; sample intent printed in debug log."
),
make_atom(
    id="E003-F002-S001-T001-A001",
    severity="P1",
    epic_id="E003", feature_id="E003-F002", story_id="E003-F002-S001", task_id="E003-F002-S001-T001",
    epic="RenderIntent Routing & Activity Bundling",
    feature="RenderIntentRouter",
    story="Convert NormalizedEvent stream into RenderIntents routed to surfaces",
    story_desc="The Router decides what appears in chat vs right panel and how to attach tool runs/diffs to the current assistant bundle.",
    task="Implement RenderIntentRouter",
    task_desc="Create `RenderIntentRouter.swift` that ingests NormalizedEvents and outputs RenderIntents to relevant stores (chat, right panel, terminal).",
    atom="RenderIntentRouter implementation",
    atom_desc="Implement routing rules: right panel receives all; chat receives assistant + summaries; errors always surface; tool noise gate applies.",
    phase="Phase 2", area="Core", risk="high", priority="must", est_days=2.0,
    deps="Depends on RenderIntent taxonomy and system.init mapping.",
    dep_ids=["E003-F001-S001-T001-A001","E002-F001-S001-T002-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#Routing-engine-requirements","/mnt/data/feature-roadmap.md#Phase-2"],
    open_questions=["Where should Router live: Engine vs UI layer? Prefer Core/Render."],
    files_touched=["Blaze/Sources/Render/RenderIntentRouter.swift","Blaze/Sources/App/AppState.swift"],
    new_files=["Blaze/Sources/Render/RenderIntentRouter.swift"],
    telemetry_events=["router_event_processed","router_noise_gate_applied"],
    metrics=[{"name":"router_processed_events","type":"counter","unit":"count","target":"N/A","notes":"Raw throughput."}],
    log_expectations=["DEBUG router_event_processed type=<...>"],
    functional=[
        "Router sends all events to right panel timeline store (fidelity guarantee).",
        "Router emits a clean chat stream: assistant messages + compact activity summaries."
    ],
    nonfunctional=["Router must be deterministic for replay; given same inputs, same outputs.","Avoid main-thread heavy work; process events in background."],
    steps=[
        "Create Router that maintains a current bundling context (currentTurn/currentAssistantBundle).",
        "Implement decision logic for chat visibility using NoiseGateSetting and error exceptions."
    ],
    edge_cases=[
        "Events arrive out of order → Router must still attach them to closest active bundle via timestamps or IDs.",
        "Router receives tool failure while noise gate minimal → still emit ErrorCard in chat."
    ],
    failure_modes=["Router drops events silently → add debug counters + warn when unknown types seen."],
    rollback_plan="If bundling is unstable, temporarily emit all tool intents to right panel only and keep chat minimal.",
    acceptance_tests=["Replay fixture; verify chat remains minimal while right panel shows everything."],
    acceptance_criteria=[
        "All events appear in right panel timeline.",
        "Chat contains assistant message plus activity strip; tool spam reduced."
    ],
    dod_criteria=["Router implemented with tests for noise gate behavior.","Verified with fixture replay."],
    completed_when="Router drives UI streams correctly.",
    completed_evidence="Screenshot: minimal chat + populated right panel timeline."
),
make_atom(
    id="E003-F003-S001-T001-A001",
    severity="P1",
    epic_id="E003", feature_id="E003-F003", story_id="E003-F003-S001", task_id="E003-F003-S001-T001",
    epic="RenderIntent Routing & Activity Bundling",
    feature="Activity bundler",
    story="Attach tool runs and diffs to a single assistant message bundle",
    story_desc="Users should see one assistant bubble with an attached strip summarizing what happened (tools, commands, diffs).",
    task="Implement ActivityBundler for per-assistant bundles",
    task_desc="Maintain an activity bundle while assistant streams; attach tools/diffs/errors as child items; finalize on assistantComplete.",
    atom="Activity bundling logic + model",
    atom_desc="Add ActivityBundle model and bundler in Router; output ActivityStripIntent to chat.",
    phase="Phase 2", area="Core", risk="high", priority="must", est_days=2.0,
    deps="Depends on Router and RenderIntent models.",
    dep_ids=["E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#Grouping-logic","/mnt/data/feature-roadmap.md#Phase-2"],
    open_questions=["Should bundle boundaries follow turns or assistant streaming boundaries? Use assistant streaming first; turn bundling later in Phase 6."],
    files_touched=["Blaze/Sources/Render/RenderIntentRouter.swift"],
    new_files=["Blaze/Sources/Render/ActivityBundle.swift"],
    telemetry_events=["activity_bundle_started","activity_bundle_completed"],
    metrics=[{"name":"activity_bundle_size","type":"histogram","unit":"items","target":"N/A","notes":"Distribution of items per bundle."}],
    functional=[
        "While assistant is streaming, tool and diff intents attach to the current ActivityBundle.",
        "Final chat shows one assistant message with ActivityStrip summary; details expandable."
    ],
    nonfunctional=["Bundling must not lose any intents; everything is still in right panel timeline.","Streaming updates should not cause re-render storms."],
    steps=[
        "Create `ActivityBundle` model: id, assistantMessageId, startedAt, completedAt, childIntentIds.",
        "Modify Router to open bundle on assistant_start, close on assistant_complete, and attach tool/diff intents in between."
    ],
    edge_cases=[
        "Assistant streams text but tool events arrive after assistant_complete → attach to the turn (Phase 6) or next bundle with warning.",
        "Multiple assistant messages in one turn → create separate bundles but group under the same turn in Phase 6."
    ],
    failure_modes=["Bundle never closes (missing assistant_complete) → set timeout or close on next user message."],
    rollback_plan="If bundling unstable, disable strip and show only right panel details; keep assistant bubble.",
    acceptance_tests=["Replay streaming fixture; observe activity strip updates then finalizes."],
    acceptance_criteria=[
        "Activity strip appears with counts (tools/commands/diffs).",
        "Chat remains clean (no raw tool spam)."
    ],
    dod_criteria=["ActivityBundle model exists and bundling verified with fixture.","No loss of fidelity in right panel."],
    completed_when="Assistant bubbles have attached activity strips.",
    completed_evidence="Screenshot of assistant message with strip summarizing tool usage."
),
make_atom(
    id="E003-F004-S001-T001-A001",
    severity="P2",
    epic_id="E003", feature_id="E003-F004", story_id="E003-F004-S001", task_id="E003-F004-S001-T001",
    epic="RenderIntent Routing & Activity Bundling",
    feature="Noise Gate setting",
    story="User can control chat density without losing fidelity",
    story_desc="Noise Gate decides what tool details bubble into chat vs remain only in right panel.",
    task="Implement NoiseGateSetting and UI toggle",
    task_desc="Add Minimal/Normal/Verbose setting; Router consults it for tool intents in chat; right panel unchanged.",
    atom="NoiseGateSetting end-to-end",
    atom_desc="Add setting in AppState + toggle in UI; Router uses it; errors always show regardless.",
    phase="Phase 2", area="UX", risk="low", priority="should", est_days=1.0,
    deps="Depends on Router.",
    dep_ids=["E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-2"],
    open_questions=["Default to Normal or Minimal? Suggest Normal for early debugging."],
    files_touched=["Blaze/Sources/App/AppState.swift","Blaze/Sources/UI/Settings/ (or toolbar)"],
    new_files=["Blaze/Sources/Core/NoiseGateSetting.swift"],
    telemetry_events=["noise_gate_changed"],
    metrics=[{"name":"noise_gate_level","type":"gauge","unit":"enum","target":"Normal","notes":"Tracks selected level."}],
    functional=[
        "Noise gate changes chat visibility immediately without affecting right panel timeline.",
        "Failures are always visible in chat even on Minimal."
    ],
    nonfunctional=["Setting must persist per app launch (UserDefaults) if possible."],
    steps=[
        "Create NoiseGateSetting enum + persist it in AppState.",
        "Add UI control (segmented control) and update Router decision logic."
    ],
    edge_cases=[
        "User switches gate mid-streaming assistant message → apply to subsequent tool events only.",
        "Verbose mode causes chat spam → still cap repeated identical tools into ToolRunGroup in Phase 3."
    ],
    failure_modes=["Noise gate affects right panel accidentally → enforce right panel always gets full stream."],
    rollback_plan="If confusing, hide UI toggle and default to Normal with code constant.",
    acceptance_tests=["Switch noise gate and observe chat changes while right panel unchanged."],
    acceptance_criteria=[
        "Noise gate toggle exists and affects chat density.",
        "Errors still appear regardless of gate."
    ],
    dod_criteria=["Setting implemented, wired, and manually verified.","Basic persistence works or explicitly not supported."],
    completed_when="Noise gate works end-to-end.",
    completed_evidence="Screen recording toggling Minimal/Verbose and observing chat density change."
),
make_atom(
    id="E003-F005-S001-T001-A001",
    severity="P1",
    epic_id="E003", feature_id="E003-F005", story_id="E003-F005-S001", task_id="E003-F005-S001-T001",
    epic="RenderIntent Routing & Activity Bundling",
    feature="Right panel timeline + raw inspector",
    story="Right panel shows full fidelity timeline and raw event payloads",
    story_desc="To keep chat clean, the right panel must expose everything: a timeline of normalized events and an inspector showing raw payload JSON for any event.",
    task="Implement timeline list + raw payload inspector",
    task_desc="Add a right panel view that lists events chronologically and displays raw JSON + derived fields on selection.",
    atom="Right panel raw inspector",
    atom_desc="Implement event timeline (list) with selection and inspector tabs (Summary/Raw JSON).",
    phase="Phase 2", area="UI", risk="medium", priority="must", est_days=2.0,
    deps="Depends on Router sending all events to right panel store.",
    dep_ids=["E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#Fidelity-guarantee","/mnt/data/feature-roadmap.md#Phase-2"],
    open_questions=["Do we store raw JSON as string or structured dict? Prefer string for fidelity, plus parsed view optional."],
    files_touched=["Blaze/Sources/UI/RightPanel/RightPanelView.swift"],
    new_files=["Blaze/Sources/UI/RightPanel/EventTimelineView.swift","Blaze/Sources/UI/RightPanel/EventInspectorView.swift"],
    telemetry_events=["right_panel_event_selected"],
    metrics=[{"name":"right_panel_event_selects","type":"counter","unit":"count","target":"N/A","notes":"Usage."}],
    functional=[
        "Right panel timeline includes every normalized event and allows selection.",
        "Inspector displays raw JSON payload for selected event."
    ],
    nonfunctional=["Inspector must handle large JSON; use monospaced + truncation with expand.","Scrolling must remain smooth in long sessions (virtualize list)."],
    steps=[
        "Create EventTimelineView with LazyVStack list and search/filter by type.",
        "Create EventInspectorView with tabs: Summary, Raw JSON; render raw JSON in monospaced text with copy button."
    ],
    edge_cases=[
        "Raw payload is not valid JSON string (e.g., already parsed) → display as pretty-printed string fallback.",
        "Event count very large → add basic filtering and limit initial render to last N with 'Load more'."
    ],
    failure_modes=["Selection loses sync when list updates during streaming → keep stable event IDs and reselect by ID."],
    rollback_plan="If inspector too heavy, ship timeline only + copy raw payload to clipboard without rendering.",
    acceptance_tests=["Select an event and verify raw JSON view matches fixture line content."],
    acceptance_criteria=[
        "Right panel shows full event timeline.",
        "Selecting an event shows raw payload reliably."
    ],
    dod_criteria=["Timeline + inspector implemented and manually verified.","Basic filter/search works."],
    completed_when="Right panel can be used to debug any event.",
    completed_evidence="Screenshot showing selected event with raw JSON displayed."
)
]

for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")

# Clear for next phases
atoms_rest = []

# ---------------- Phase 3 (E004) ----------------
md.append("\n# Phase 3 — Tool Run Group (Non-command tools)\n")
atoms_rest += [
make_atom(
    id="E004-F001-S001-T001-A001",
    severity="P1",
    epic_id="E004", feature_id="E004-F001", story_id="E004-F001-S001", task_id="E004-F001-S001-T001",
    epic="Tool Run Group",
    feature="Tool aggregation logic",
    story="Routine tools collapse into a compact summary in chat",
    story_desc="Read/Glob/Grep and similar tools should not spam the chat. Instead, collapse them into a single summarized group while preserving detail in right panel.",
    task="Aggregate routine tool intents into ToolRunGroupIntent",
    task_desc="In Router, bucket tool events by turn/bundle and tool kind; emit ToolRunGroupIntent to chat instead of individual tool intents.",
    atom="Tool aggregation in Router",
    atom_desc="Implement grouping rules, including: failures always surface, success runs collapse, durations and counts computed.",
    phase="Phase 3", area="Core", risk="medium", priority="must", est_days=1.5,
    deps="Depends on Router + NoiseGate + right panel fidelity.",
    dep_ids=["E003-F002-S001-T001-A001","E003-F004-S001-T001-A001","E003-F005-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-3","/mnt/data/blaze-chat-ui-polish-spec (1).md#Tool-calls"],
    open_questions=["Which tools are considered routine by default? Start with Read/Glob/Grep/WebSearch/WebFetch."],
    files_touched=["Blaze/Sources/Render/RenderIntentRouter.swift"],
    new_files=["Blaze/Sources/Render/ToolRunGroupIntent.swift"],
    telemetry_events=["tool_group_emitted"],
    metrics=[{"name":"tool_group_size","type":"histogram","unit":"tools","target":"N/A","notes":"How many tools per group."}],
    functional=[
        "Chat shows one line like 'Ran 6 tools (1.8s): Read×3, Glob×2, Grep×1' instead of 6 separate tool cards.",
        "Any failing tool run is always visible (either ungrouped ErrorCard or highlighted inside group)."
    ],
    nonfunctional=["Grouping must be deterministic and stable for replay.","Avoid O(n^2) grouping operations; keep incremental counters."],
    steps=[
        "Define ToolRunGroup model: start/end times, counts by toolName, failures list, referenced event IDs.",
        "Modify Router: for routine tool events, accumulate into current group; flush group at assistant_complete or turn end."
    ],
    edge_cases=[
        "A routine tool runs both success and failure in same group → show group plus an ErrorCard for failures.",
        "Tool events interleave with assistant streaming → update group incrementally without re-render storms."
    ],
    failure_modes=["Group never flushes → group persists across turns; flush on assistant_complete or user message."],
    rollback_plan="If grouping causes confusion, gate it behind NoiseGate and default to showing individual tools for debugging.",
    acceptance_tests=["Replay fixture with many Read/Glob; confirm chat shows single ToolRunGroup summary."],
    acceptance_criteria=[
        "Routine tools collapse into group by default.",
        "Failures still visible even in Minimal mode."
    ],
    dod_criteria=["ToolRunGroup model implemented and routed.","Manual verification on fixture."],
    completed_when="Chat no longer spams routine tool calls.",
    completed_evidence="Screenshot of grouped tool summary line."
),
make_atom(
    id="E004-F002-S001-T001-A001",
    severity="P1",
    epic_id="E004", feature_id="E004-F002", story_id="E004-F002-S001", task_id="E004-F002-S001-T001",
    epic="Tool Run Group",
    feature="ToolRunGroupCard UI",
    story="Users can expand tool group to see details",
    story_desc="Summaries must be expandable for trust and debugging: show tool name, duration, status, and link to right panel raw event.",
    task="Build ToolRunGroupCard UI and expansion",
    task_desc="Implement a card that shows summary line, expand/collapse list, and 'Inspect' deep-link to right panel.",
    atom="ToolRunGroupCard component",
    atom_desc="SwiftUI card with header summary, expandable tool rows, failure highlighting, and inspect actions.",
    phase="Phase 3", area="UI", risk="low", priority="must", est_days=1.0,
    deps="Depends on ToolRunGroupIntent emission and right panel inspector selection.",
    dep_ids=["E004-F001-S001-T001-A001","E003-F005-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-3","/mnt/data/blaze-chat-ui-polish-spec (1).md#Tool-calls"],
    open_questions=["Default collapsed or expanded? Default collapsed; expand on hover/click."],
    files_touched=["Blaze/Sources/UI/Cards/ (new)"],
    new_files=["Blaze/Sources/UI/Cards/ToolRunGroupCard.swift"],
    telemetry_events=["tool_group_expanded","tool_group_inspect_clicked"],
    metrics=[{"name":"tool_group_expand_rate","type":"gauge","unit":"ratio","target":"N/A","notes":"Share of groups expanded."}],
    ui_states=["Collapsed","Expanded","Expanded with failures"],
    ui_interactions=["Click expand/collapse","Click Inspect on a tool row"],
    ui_copy=["Ran {n} tools ({duration})","Inspect"],
    functional=[
        "Card shows summary counts and total duration.",
        "Expanding shows list of tool runs (name, duration, status) and allows inspect."
    ],
    nonfunctional=["Card must be accessible (VoiceOver labels for buttons)."],
    steps=[
        "Create SwiftUI ToolRunGroupCard with disclosure animation (lightweight).",
        "Wire Inspect action to select associated raw event in right panel."
    ],
    edge_cases=[
        "Tool group is huge (50+) → show first 10 with 'Show more'.",
        "Tool rows missing duration → show '—' and keep layout stable."
    ],
    failure_modes=["Inspect doesn't navigate due to missing event IDs → ensure group stores raw event IDs."],
    rollback_plan="Ship summary-only card without expansion if UI issues; keep right panel for details.",
    acceptance_tests=["Expand a tool group and click Inspect; right panel selects matching event."],
    acceptance_criteria=[
        "Card expands/collapses smoothly and shows correct tool details.",
        "Inspect deep-link works reliably."
    ],
    dod_criteria=["Card built and manually verified.","Tool group detail list shows correct counts and failures."],
    completed_when="ToolRunGroup is usable and trustworthy.",
    completed_evidence="Screen recording expanding group and inspecting an event."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 4 (E005) ----------------
md.append("\n# Phase 4 — Command Card + Terminal Sessions\n")
atoms_rest += [
make_atom(
    id="E005-F001-S001-T001-A001",
    severity="P1",
    epic_id="E005", feature_id="E005-F001", story_id="E005-F001-S001", task_id="E005-F001-S001-T001",
    epic="Command Card + Terminal Sessions",
    feature="Terminal models",
    story="Commands are tracked as first-class sessions with output buffers",
    story_desc="We need a model linking command tool call IDs to a terminal session/segment so CommandCard can open exact output without dumping logs into chat.",
    task="Define TerminalSession and CommandRun models",
    task_desc="Create data models: TerminalSession (id, createdAt), CommandRun (toolCallId, command, status, exitCode, duration, outputLines buffer, timestamps).",
    atom="TerminalSession + CommandRun models",
    atom_desc="Implement Codable models and store in TerminalStore keyed by toolCallId.",
    phase="Phase 4", area="Core", risk="medium", priority="must", est_days=1.0,
    deps="Depends on event mapping for command tool calls.",
    dep_ids=["E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-4","/mnt/data/blaze-chat-ui-polish-spec (1).md#Commands"],
    open_questions=["Do we store raw stdout/stderr separately or as merged stream? Prefer merged with channel tags."],
    new_files=["Blaze/Sources/Terminal/TerminalModels.swift"],
    files_touched=["Blaze/Sources/Terminal/ (new)"],
    data_model_changes=["Add TerminalStore in AppState or a dedicated manager."],
    telemetry_events=["command_run_created"],
    metrics=[{"name":"command_runs","type":"counter","unit":"count","target":"N/A","notes":"Count of command runs."}],
    functional=[
        "Each command tool call creates a CommandRun record with stable ID (toolCallId).",
        "CommandRun stores streaming output lines and final exit status."
    ],
    nonfunctional=["Output buffering must cap memory usage (ring buffer)."],
    steps=[
        "Create models in `TerminalModels.swift` and add TerminalStore container.",
        "Add ring-buffer behavior: keep last N lines (e.g., 5000) and record 'truncated' flag."
    ],
    edge_cases=[
        "Command produces extremely large output → buffer truncates and UI shows 'Output truncated'.",
        "Command never finishes (hang) → UI shows 'Running…' and allow cancel (future)."
    ],
    failure_modes=["Output lines not linked to correct toolCallId → card opens wrong output; include toolCallId in every output event mapping."],
    rollback_plan="If output capture unstable, store only final snapshot and omit streaming until fixed.",
    acceptance_tests=["Run fixture with command output and verify CommandRun contains lines and exitCode."],
    acceptance_criteria=[
        "Terminal models exist and compile; output buffer works.",
        "Command runs can be looked up by toolCallId."
    ],
    dod_criteria=["Models implemented and validated with fixture.","Ring buffer tested."],
    completed_when="TerminalSession models support CommandCard linking.",
    completed_evidence="Unit test or debug log showing CommandRun created with output lines."
),
make_atom(
    id="E005-F001-S001-T002-A001",
    severity="P1",
    epic_id="E005", feature_id="E005-F001", story_id="E005-F001-S001", task_id="E005-F001-S001-T002",
    epic="Command Card + Terminal Sessions",
    feature="Terminal output capture",
    story="Commands are tracked as first-class sessions with output buffers",
    story_desc="We must capture command output events and append to the correct CommandRun in real time.",
    task="Wire command output events into TerminalStore",
    task_desc="In event mapper/router, map command stdout/stderr chunks to CommandRun.outputLines and update status/duration/exitCode on completion.",
    atom="Streaming output capture + completion handling",
    atom_desc="Append interleaved output lines with timestamps; update running/success/failure state; compute duration.",
    phase="Phase 4", area="Core", risk="high", priority="must", est_days=2.0,
    deps="Depends on Terminal models.",
    dep_ids=["E005-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-4","/mnt/data/blaze-chat-ui-polish-spec (1).md#Commands"],
    open_questions=["Where do command output events originate in fixtures? confirm event types and fields."],
    files_touched=["Blaze/Sources/Engine/ClaudeEventMapper.swift","Blaze/Sources/Terminal/TerminalStore.swift"],
    new_files=["Blaze/Sources/Terminal/TerminalStore.swift"],
    telemetry_events=["command_output_line_received","command_run_completed"],
    metrics=[{"name":"command_output_lines","type":"counter","unit":"lines","target":"N/A","notes":"Volume tracking."}],
    functional=[
        "Output lines append to the correct CommandRun in order (best-effort if interleaved).",
        "CommandRun status updates to success/failure with exitCode and duration at completion."
    ],
    nonfunctional=["Updates must be throttled to avoid UI re-render per line; batch publish on timer (e.g., 50ms)."],
    steps=[
        "Implement TerminalStore methods: startRun(toolCallId,...), appendLine(toolCallId,...), finishRun(toolCallId, exitCode,...).",
        "In mapper/router, detect stdout/stderr chunk events and call appendLine; detect completion and call finishRun."
    ],
    edge_cases=[
        "Output arrives before startRun event → create placeholder run and fill command later.",
        "Command completion arrives without exitCode → treat as unknown and show 'Exit: —'."
    ],
    failure_modes=["UI freezes due to too frequent publishes → implement batching and verify in Instruments."],
    rollback_plan="Disable per-line streaming and update UI only every N lines if performance issues.",
    acceptance_tests=["Run a long-output command fixture; confirm UI remains responsive and output appears progressively."],
    acceptance_criteria=[
        "Command output capture works; CommandCard can show preview lines.",
        "No chat spam; output stays in terminal panel."
    ],
    dod_criteria=["Streaming capture implemented with throttling.","Manual long-output run verified."],
    completed_when="Terminal output is captured reliably per command.",
    completed_evidence="Screen recording showing command output updating in terminal panel."
),
make_atom(
    id="E005-F002-S001-T001-A001",
    severity="P1",
    epic_id="E005", feature_id="E005-F002", story_id="E005-F002-S001", task_id="E005-F002-S001-T001",
    epic="Command Card + Terminal Sessions",
    feature="CommandCard UI",
    story="Commands are readable in chat and open terminal output",
    story_desc="Chat must show a compact command card with status/duration and an 'Open Terminal' action.",
    task="Build CommandCard with status, duration, output preview",
    task_desc="Implement SwiftUI card: command string, status pill, duration, exit code, buttons: Open Terminal, Copy Command, Inspect raw.",
    atom="CommandCard component",
    atom_desc="SwiftUI component that renders CommandRun summary and deep-links to terminal panel.",
    phase="Phase 4", area="UI", risk="medium", priority="must", est_days=1.5,
    deps="Depends on TerminalStore providing CommandRun state.",
    dep_ids=["E005-F001-S001-T002-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-4","/mnt/data/blaze-chat-ui-polish-spec (1).md#Commands"],
    open_questions=["Do we include a 'Re-run' button here or later in Phase 8? Later."],
    files_touched=["Blaze/Sources/UI/Cards/CommandCard.swift"],
    new_files=["Blaze/Sources/UI/Cards/CommandCard.swift"],
    telemetry_events=["command_card_open_terminal_clicked","command_card_copy_clicked"],
    metrics=[{"name":"command_card_open_terminal","type":"counter","unit":"count","target":"N/A","notes":"How often users open terminal from card."}],
    ui_states=["Running","Success","Failed","Truncated output"],
    ui_interactions=["Open Terminal","Copy command","Inspect raw event"],
    ui_copy=["Open Terminal","Copy"],
    functional=[
        "CommandCard shows status (running/success/fail), duration, exit code, and command text.",
        "Open Terminal button navigates to terminal panel focused on that CommandRun."
    ],
    nonfunctional=["Card must not render large output; preview limited to first ~10 lines."],
    steps=[
        "Create CommandCard SwiftUI view using CommandRun binding.",
        "Implement Open Terminal action to set AppState.selectedTerminalRunId = toolCallId and open terminal panel."
    ],
    edge_cases=[
        "CommandRun missing output lines → show 'No output captured' and still allow inspect raw.",
        "Command text extremely long → wrap and add copy button."
    ],
    failure_modes=["Open Terminal navigates but doesn't scroll to run → add programmatic scroll to selected run."],
    rollback_plan="If deep-link is buggy, open terminal panel without selecting run and show a toast 'Find it in list'.",
    acceptance_tests=["Click Open Terminal from a finished command; terminal panel focuses correct output."],
    acceptance_criteria=[
        "CommandCard shows correct status/duration/exit code.",
        "Open Terminal navigates to the correct output."
    ],
    dod_criteria=["Card implemented and verified.","Preview and copy actions work."],
    completed_when="CommandCard usable and doesn't spam chat with raw output.",
    completed_evidence="Screenshot of command card + terminal panel focused on output."
),
make_atom(
    id="E005-F003-S001-T001-A001",
    severity="P2",
    epic_id="E005", feature_id="E005-F003", story_id="E005-F003-S001", task_id="E005-F003-S001-T001",
    epic="Command Card + Terminal Sessions",
    feature="Terminal panel UI",
    story="Terminal panel shows per-command output with search",
    story_desc="Users need a dedicated terminal panel view with readable output, search, and copy/export, without cluttering chat.",
    task="Build TerminalPanelView with run list and output viewer",
    task_desc="Implement a left list of CommandRuns (most recent first) and a right output viewer; support search in output and copy.",
    atom="TerminalPanelView + output viewer",
    atom_desc="SwiftUI terminal panel with monospaced output, search box, scroll-to-bottom on streaming, and copy.",
    phase="Phase 4", area="UI", risk="medium", priority="should", est_days=2.0,
    deps="Depends on TerminalStore and CommandCard deep-linking.",
    dep_ids=["E005-F001-S001-T002-A001","E005-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-4","/mnt/data/blaze-chat-ui-polish-spec (1).md#Commands"],
    open_questions=["Do we need multiple tabs vs a single list? Start with single list + selection."],
    files_touched=["Blaze/Sources/UI/Terminal/TerminalPanelView.swift"],
    new_files=["Blaze/Sources/UI/Terminal/TerminalPanelView.swift","Blaze/Sources/UI/Terminal/TerminalOutputView.swift"],
    telemetry_events=["terminal_panel_opened","terminal_search_used"],
    metrics=[{"name":"terminal_search_queries","type":"counter","unit":"count","target":"N/A","notes":"Search usage."}],
    ui_states=["No command selected","Command selected","Streaming output"],
    ui_interactions=["Select run","Search output","Copy output"],
    ui_copy=["Search output…","Copy output"],
    functional=[
        "Terminal panel shows list of command runs and allows selecting one to view output.",
        "Output viewer supports search highlighting and copy-to-clipboard."
    ],
    nonfunctional=["Output viewer must handle large outputs efficiently (virtualized lines, not one giant Text)."],
    steps=[
        "Implement TerminalPanelView with split layout (list + viewer).",
        "Implement output viewer with incremental rendering and auto-scroll when streaming."
    ],
    edge_cases=[
        "Output truncated ring buffer → show banner 'Output truncated' and offer export diagnostics bundle.",
        "Streaming output while user scrolled up → do not yank scroll; show 'Jump to latest' button."
    ],
    failure_modes=["Large output freezes UI → implement line virtualization and batching."],
    rollback_plan="If virtualization too hard, initially render as single string but cap output size aggressively.",
    acceptance_tests=["Run command with many lines; panel stays responsive; search works."],
    acceptance_criteria=[
        "Terminal panel usable for debugging; output readable and searchable.",
        "No raw output appears in chat."
    ],
    dod_criteria=["Panel implemented and manually tested on long output.","Copy and search verified."],
    completed_when="Terminal panel supports real debugging workflow.",
    completed_evidence="Screen recording: open terminal from card, search output, copy."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 5 (E006) ----------------
md.append("\n# Phase 5 — Diff Card + Undo Turn (Core Differentiator)\n")
atoms_rest += [
make_atom(
    id="E006-F001-S001-T001-A001",
    severity="P1",
    epic_id="E006", feature_id="E006-F001", story_id="E006-F001-S001", task_id="E006-F001-S001-T001",
    epic="Diff Card + Undo Turn",
    feature="DiffCard UI",
    story="File edits are summarized cleanly after tool writes",
    story_desc="After edits, show 'Edited N files (+/- counts)' and allow inspecting per-file diffs without overwhelming chat.",
    task="Build DiffCard using FileDiff and DiffService",
    task_desc="Implement SwiftUI DiffCard: per-file rows with +/-, file path, open diff viewer, copy patch.",
    atom="DiffCard component",
    atom_desc="Card that summarizes file changes and deep-links to diff viewer/right panel.",
    phase="Phase 5", area="UI", risk="medium", priority="must", est_days=2.0,
    deps="Assumes FileDiff and DiffService exist (as stated in roadmap).",
    dep_ids=["E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-5","/mnt/data/blaze-chat-ui-polish-spec (1).md#Code-changes"],
    open_questions=["Where does diff viewer live: right panel tab or modal? Start with right panel tab."],
    files_touched=["Blaze/Sources/UI/Cards/DiffCard.swift"],
    new_files=["Blaze/Sources/UI/Cards/DiffCard.swift","Blaze/Sources/UI/Diff/DiffViewerView.swift"],
    telemetry_events=["diff_card_opened","diff_file_row_clicked"],
    metrics=[{"name":"diff_cards_shown","type":"counter","unit":"count","target":"N/A","notes":"How many diffs per session."}],
    ui_states=["Collapsed summary","Expanded file list","Diff viewer open"],
    ui_interactions=["Click file row","Open diff viewer","Copy patch"],
    ui_copy=["Edited {n} files","View diff","Copy patch"],
    functional=[
        "DiffCard shows total files changed and per-file +/- counts.",
        "User can open a diff viewer for any file from the card."
    ],
    nonfunctional=["Diff rendering must be performant for medium diffs; large diffs should truncate with 'Open full diff'."],
    steps=[
        "Implement DiffCard and bind it to FileDiff objects produced by the pipeline.",
        "Implement DiffViewerView that shows side-by-side or unified diff with monospaced text and copy button."
    ],
    edge_cases=[
        "Binary file changes → show 'Binary changed' and disable diff view.",
        "Huge diff (10k lines) → truncate and provide export/inspect raw link."
    ],
    failure_modes=["Diff counts incorrect due to parser mismatch → rely on DiffService-provided counts or compute carefully."],
    rollback_plan="If diff viewer hard, ship summary-only card and open raw patch in right panel inspector.",
    acceptance_tests=["Trigger file edit; DiffCard appears and file row opens diff viewer."],
    acceptance_criteria=[
        "DiffCard appears for write/edit tools.",
        "Diff viewer opens and displays patch reliably."
    ],
    dod_criteria=["DiffCard implemented and verified.","At least one fixture or manual run confirms correct counts."],
    completed_when="Users can understand file changes and inspect diffs quickly.",
    completed_evidence="Screenshot of DiffCard and diff viewer for one file."
),
make_atom(
    id="E006-F002-S001-T001-A001",
    severity="P1",
    epic_id="E006", feature_id="E006-F002", story_id="E006-F002-S001", task_id="E006-F002-S001-T001",
    epic="Diff Card + Undo Turn",
    feature="TurnRecord diff tracking",
    story="Each turn records diffs so it can be undone",
    story_desc="Undo requires knowing which files changed in the last turn and the exact diffs/previous states.",
    task="Introduce TurnRecord structure and attach file diffs",
    task_desc="Create TurnRecord model with turnId, timestamps, assistantMessageId, fileDiffs, toolCallIds; attach diffs to active turn.",
    atom="TurnRecord model + diff attachment",
    atom_desc="Implement TurnRecord store in AppState; Router updates current turn and attaches FileDiffs on fileDiffProduced events.",
    phase="Phase 5", area="Core", risk="high", priority="must", est_days=2.0,
    deps="Depends on Router/bundling and DiffService emitting FileDiffs.",
    dep_ids=["E003-F003-S001-T001-A001","E006-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-5"],
    open_questions=["How do we identify turn boundaries? preliminary: per user message; finalized in Phase 6."],
    files_touched=["Blaze/Sources/Core/TurnRecord.swift","Blaze/Sources/App/AppState.swift","Blaze/Sources/Render/RenderIntentRouter.swift"],
    new_files=["Blaze/Sources/Core/TurnRecord.swift"],
    telemetry_events=["turn_record_created","turn_record_finalized"],
    metrics=[{"name":"turns_recorded","type":"counter","unit":"turns","target":"N/A","notes":"Turns tracked per session."}],
    functional=[
        "Active turn collects diffs and tool call IDs as they occur.",
        "Finalized turn stores enough info to support UndoLastTurn."
    ],
    nonfunctional=["TurnRecord updates must not cause heavy UI updates; publish only when finalized or summarized."],
    steps=[
        "Create TurnRecord model and TurnStore (list + currentTurn).",
        "Update Router to start a turn on user message and finalize on assistantComplete; attach diffs to currentTurn."
    ],
    edge_cases=[
        "Diff arrives after turn finalized → attach to last finalized turn with warning badge.",
        "Multiple assistant messages per turn → store list of assistantMessageIds."
    ],
    failure_modes=["Turn boundaries wrong → undo reverts wrong changes; keep conservative boundary: only diffs between user->assistantComplete."],
    rollback_plan="If boundaries ambiguous, disable Undo button until turn tracking stabilized.",
    acceptance_tests=["Edit 2 files in one turn; TurnRecord shows 2 diffs; DiffCard references TurnRecord."],
    acceptance_criteria=[
        "TurnRecord exists and collects diffs reliably.",
        "TurnRecord can be used by Undo engine."
    ],
    dod_criteria=["TurnRecord model implemented and attached to diffs.","Manual verification with multi-file edit."],
    completed_when="Turns have deterministic diff lists.",
    completed_evidence="Debug view showing TurnRecord with fileDiffs list."
),
make_atom(
    id="E006-F003-S001-T001-A001",
    severity="P1",
    epic_id="E006", feature_id="E006-F003", story_id="E006-F003-S001", task_id="E006-F003-S001-T001",
    epic="Diff Card + Undo Turn",
    feature="Undo engine",
    story="User can undo the last turn safely",
    story_desc="Undo is core trust feature: revert only files changed by last turn, avoid clobbering user edits, and mark turn as undone.",
    task="Implement UndoLastTurn engine using DiffService.rejectDiff",
    task_desc="Create engine that loads last finalized TurnRecord, verifies file clean state, reverts diffs via DiffService, and updates UI state.",
    atom="UndoLastTurnEngine",
    atom_desc="Implement undo with safety gates, confirmation dialogs for conflicts, and telemetry/logging.",
    phase="Phase 5", area="Core", risk="high", priority="must", est_days=2.5,
    deps="Depends on TurnRecord diff tracking and DiffService.",
    dep_ids=["E006-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-5","/mnt/data/blaze-chat-ui-polish-spec (1).md#Policy-gating"],
    open_questions=["How to detect 'uncommitted changes'? Use file hash comparison vs git status if available."],
    files_touched=["Blaze/Sources/Undo/UndoLastTurnEngine.swift","Blaze/Sources/App/AppState.swift"],
    new_files=["Blaze/Sources/Undo/UndoLastTurnEngine.swift"],
    telemetry_events=["undo_requested","undo_completed","undo_skipped_file_conflict"],
    metrics=[{"name":"undo_success_rate","type":"gauge","unit":"ratio","target":">=0.95","notes":"Most undos should succeed; conflicts are expected occasionally."}],
    ui_states=["Undo available","Undo confirming","Undo running","Undo completed","Undo partially skipped"],
    ui_interactions=["Click Undo Last Turn","Confirm undo","View skipped files"],
    ui_copy=["Undo last turn","Some files were skipped due to conflicts"],
    functional=[
        "Undo reverts every file diff in the last finalized turn (best-effort).",
        "If a file has conflicting local changes, it is skipped with clear explanation."
    ],
    nonfunctional=["Undo must be transactional-ish: if partial failure, clearly report which files reverted vs skipped."],
    steps=[
        "Create UndoLastTurnEngine that loads last TurnRecord and iterates diffs.",
        "Before reverting each file: verify file unchanged since diff (hash); if changed, prompt user to skip or force (force optional)."
    ],
    edge_cases=[
        "DiffService.rejectDiff fails for a file → continue to next file and report failure.",
        "TurnRecord has no diffs (tool-only turn) → show 'Nothing to undo' and disable button."
    ],
    failure_modes=["Undo reverts wrong turn → ensure engine always uses last finalized (not current streaming) turn."],
    rollback_plan="If undo is risky, hide Undo button and keep 'Revert file' actions per-file only.",
    acceptance_tests=["Perform edit turn, then undo; confirm files restored and turn marked 'Undone'."],
    acceptance_criteria=[
        "Undo button works and safely handles conflicts.",
        "Turn state updates reflect undone status."
    ],
    dod_criteria=["Undo engine implemented with safety checks.","Manual verification with conflict scenario."],
    completed_when="Undo restores workspace safely for last turn.",
    completed_evidence="Screen recording undoing a multi-file edit and seeing files revert."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 6 (E007) ----------------
md.append("\n# Phase 6 — Session Replay & Context Diff Between Turns\n")
atoms_rest += [
make_atom(
    id="E007-F001-S001-T001-A001",
    severity="P1",
    epic_id="E007", feature_id="E007-F001", story_id="E007-F001-S001", task_id="E007-F001-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Turn boundaries definition",
    story="Turns have deterministic boundaries for replay and undo",
    story_desc="Replay and context diff require stable turn boundaries. Start turn on user message; end on assistantComplete/result; persist TurnRecords.",
    task="Implement turn boundary logic and finalize TurnRecords",
    task_desc="In Router or session orchestrator, enforce turn lifecycle: start -> active -> finalized. Emit telemetry on turn start/end.",
    atom="Turn lifecycle enforcement",
    atom_desc="Implement deterministic boundaries and store timestamps and event IDs for each turn.",
    phase="Phase 6", area="Core", risk="medium", priority="must", est_days=1.5,
    deps="Depends on TurnRecord existing.",
    dep_ids=["E006-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6"],
    open_questions=["Does CLI emit explicit turn markers? If not, rely on user/assistant boundaries."],
    files_touched=["Blaze/Sources/Core/TurnRecord.swift","Blaze/Sources/Render/RenderIntentRouter.swift"],
    telemetry_events=["turn_started","turn_ended"],
    metrics=[{"name":"turn_duration_ms","type":"histogram","unit":"ms","target":"N/A","notes":"Turn durations distribution."}],
    functional=[
        "Turn starts on user message and ends on assistantComplete/result event.",
        "TurnRecord includes start/end timestamps and list of related event IDs."
    ],
    nonfunctional=["Turn logic must be consistent in live and replay modes."],
    steps=[
        "Add TurnLifecycle manager to create and finalize TurnRecords.",
        "Ensure late events attach to the correct turn based on timestamps and IDs."
    ],
    edge_cases=[
        "AssistantComplete missing → end turn when next user message starts with warning.",
        "Multiple assistantComplete events → treat first as end and attach later events with warning."
    ],
    failure_modes=["Turns overlap due to concurrent sessions → include sessionId in TurnRecord and isolate per session."],
    rollback_plan="If boundaries unreliable, disable replay UI until fixed.",
    acceptance_tests=["Simulate two turns; verify two TurnRecords with correct events."],
    acceptance_criteria=[
        "TurnRecord boundaries are deterministic and stable.",
        "Telemetry emitted on start/end."
    ],
    dod_criteria=["Turn lifecycle implemented and tested on fixture.","Late event handling documented."],
    completed_when="Turns are reliably tracked for replay and context diff.",
    completed_evidence="Debug view showing turns 1..N with timestamps."
),
make_atom(
    id="E007-F002-S001-T001-A001",
    severity="P1",
    epic_id="E007", feature_id="E007-F002", story_id="E007-F002-S001", task_id="E007-F002-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Session recording",
    story="Session can be replayed from recorded NDJSON events",
    story_desc="To replay deterministically, record the raw NDJSON stream and minimal manifest/index to disk per session.",
    task="Implement SessionRecorder for raw NDJSON + manifest + index",
    task_desc="Write `.blaze/sessions/<sessionId>/events.ndjson`, `manifest.json`, and `index.json` checkpoints for seeking.",
    atom="SessionRecorder persistence",
    atom_desc="Append-only raw stream; periodic checkpoint index; safe atomic writes; failures do not crash app.",
    phase="Phase 6", area="Core", risk="high", priority="must", est_days=2.0,
    deps="Depends on runtimeInfo sessionId and raw NDJSON access point.",
    dep_ids=["E002-F001-S001-T002-A001","E007-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6"],
    open_questions=["Do we store recordings by sessionId or generate BlazeSessionId? Use sessionId when available else UUID."],
    files_touched=["Blaze/Sources/App/AppState.swift"],
    new_files=["Blaze/Sources/Replay/SessionRecorder.swift"],
    telemetry_events=["session_recording_started","session_recording_failed"],
    metrics=[{"name":"session_recording_failures","type":"counter","unit":"count","target":"0","notes":"Should be 0 in normal operation."}],
    functional=[
        "All raw NDJSON lines are recorded in order for a session.",
        "A manifest and index are written to support replay and seeking."
    ],
    nonfunctional=["Recording must not block UI; use buffered IO and background queue."],
    steps=[
        "Create SessionRecorder with start/append/stop and checkpointing.",
        "Hook recorder at raw-line boundary (before parsing) so fidelity is exact."
    ],
    edge_cases=[
        "Disk write permission denied → disable recording and show WarningCard.",
        "Session ends abruptly → recorder closes file safely and writes final index."
    ],
    failure_modes=["Recorder truncates file due to non-atomic writes → write manifest/index atomically via temp+rename."],
    rollback_plan="Feature-flag recording off if it causes instability; keep replay based on fixtures only.",
    acceptance_tests=["Run session; verify `.blaze/sessions/<id>/events.ndjson` exists and non-empty."],
    acceptance_criteria=[
        "Recorder produces deterministic artifacts for replay.",
        "Failures are visible but non-fatal."
    ],
    dod_criteria=["Recorder implemented with at least one unit/integration test.","Artifacts verified on disk."],
    completed_when="Sessions are recorded locally for replay.",
    completed_evidence="Screenshot of session folder contents."
),
make_atom(
    id="E007-F003-S001-T001-A001",
    severity="P1",
    epic_id="E007", feature_id="E007-F003", story_id="E007-F003-S001", task_id="E007-F003-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Replay engine",
    story="Recorded sessions replay through the same pipeline deterministically",
    story_desc="Replay feeds recorded NDJSON lines into NDJSONParser and Router, supporting pause/play/seek/step and speed control.",
    task="Implement ReplayEngine with play/pause/seek/step/speed",
    task_desc="Load session folder; play lines with timestamp-based pacing; seek using index checkpoints; rebuild state on seek.",
    atom="ReplayEngine core",
    atom_desc="State machine for replay; uses resetStores() then replays to target offset; read-only mode enforced.",
    phase="Phase 6", area="Core", risk="high", priority="must", est_days=3.0,
    deps="Depends on SessionRecorder artifacts and Router determinism.",
    dep_ids=["E007-F002-S001-T001-A001","E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6"],
    open_questions=["Seek by timestamp vs turn boundaries? Start with timestamp, add turn jump in UI."],
    files_touched=["Blaze/Sources/App/AppState.swift"],
    new_files=["Blaze/Sources/Replay/ReplayEngine.swift"],
    telemetry_events=["replay_loaded","replay_seek"],
    metrics=[{"name":"replay_seek_time_ms","type":"histogram","unit":"ms","target":"<=3000","notes":"If too slow, add snapshots."}],
    functional=[
        "Replay reproduces the same UI state given the same recording.",
        "Seek resets state and rebuilds up to target time without executing any real commands."
    ],
    nonfunctional=["Replay must be read-only: never write to workspace or run commands.","Seek must not freeze UI (async)."],
    steps=[
        "Implement ReplayEngine state machine and load session folder validation.",
        "Implement seek: stop, reset stores, jump to checkpoint offset, fast-forward replay to target time."
    ],
    edge_cases=[
        "Corrupt NDJSON line → skip with WarningCard and continue.",
        "Index missing → fallback to linear scan seek with progress indicator."
    ],
    failure_modes=["Replay mutates workspace due to tool execution → enforce mode=Replay and block command/file-write tools."],
    rollback_plan="Ship replay without seek first (play/pause only) if seek is unstable.",
    acceptance_tests=["Load recording; play to end; counts of turns and tool groups match original session."],
    acceptance_criteria=[
        "Replay works deterministically and safely (read-only).",
        "Seek/step controls are functional or feature-gated."
    ],
    dod_criteria=["ReplayEngine implemented with basic tests.","Manual replay verified on recorded session."],
    completed_when="Recorded session can be replayed deterministically.",
    completed_evidence="Screen recording showing replay with play/pause/seek."
),
make_atom(
    id="E007-F004-S001-T001-A001",
    severity="P2",
    epic_id="E007", feature_id="E007-F004", story_id="E007-F004-S001", task_id="E007-F004-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Replay UI",
    story="Users can browse turns and scrub timeline",
    story_desc="Replay needs UI: load session, controls, turn list, and timeline scrubber. Live vs Replay must be obvious.",
    task="Add ReplayPanel UI with controls and turn list",
    task_desc="Create UI with Load Session, Play/Pause/Step, speed selector, scrubber, and turn jump list.",
    atom="ReplayPanelView UI",
    atom_desc="Bind controls to ReplayEngine; add mode indicator; debounce scrub seeks.",
    phase="Phase 6", area="UI", risk="medium", priority="should", est_days=2.0,
    deps="Depends on ReplayEngine and TurnRecords.",
    dep_ids=["E007-F003-S001-T001-A001","E007-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6"],
    open_questions=["Placement: right panel drawer vs top toolbar. Prefer right panel drawer."],
    files_touched=["Blaze/Sources/UI/RightPanel/RightPanelView.swift"],
    new_files=["Blaze/Sources/UI/Replay/ReplayPanelView.swift"],
    telemetry_events=["replay_ui_loaded","replay_ui_play_clicked"],
    metrics=[{"name":"replay_ui_play_clicks","type":"counter","unit":"count","target":"N/A","notes":"Usage."}],
    ui_states=["No session loaded","Paused","Playing","Seeking"],
    ui_interactions=["Load session","Play/Pause","Scrub","Jump to turn"],
    ui_copy=["Load Session…","Play","Pause","Seeking…"],
    functional=[
        "User can load a recorded session folder and control playback.",
        "User can jump to a turn and see associated intents highlighted."
    ],
    nonfunctional=["Scrubbing must debounce seeks to avoid thrashing.","UI must not block while seek rebuilds state."],
    steps=[
        "Implement ReplayPanelView and hook it into right panel sections.",
        "Implement NSOpenPanel folder picker and validation of manifest/events files."
    ],
    edge_cases=[
        "User loads invalid folder → show error and keep controls disabled.",
        "Long sessions → turn list virtualization + search."
    ],
    failure_modes=["Mode indicator unclear → user thinks they are live; add prominent LIVE/REPLAY pill."],
    rollback_plan="Ship play/pause only and omit scrubber if instability.",
    acceptance_tests=["Load session, play, pause, jump to turn; confirm UI updates."],
    acceptance_criteria=[
        "Replay is controllable from UI.",
        "Live vs Replay indicator is always visible."
    ],
    dod_criteria=["UI implemented and manually tested.","Debounce and error states implemented."],
    completed_when="Replay is usable by non-technical users.",
    completed_evidence="Screen recording controlling replay from UI."
),
make_atom(
    id="E007-F005-S001-T001-A001",
    severity="P1",
    epic_id="E007", feature_id="E007-F005", story_id="E007-F005-S001", task_id="E007-F005-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Context diff tracker",
    story="Each turn shows context additions/removals",
    story_desc="Users must see what changed in context each turn: pinned files, dropped files, injected policies, etc.",
    task="Track context changes per turn and render ContextChanges box",
    task_desc="Extend context store to emit deltas (added/removed) per turn; show in Replay UI or turn inspector.",
    atom="Context changes per turn",
    atom_desc="Compute and store context snapshot hashes per turn; diff snapshots; render added/removed lists.",
    phase="Phase 6", area="Data", risk="medium", priority="must", est_days=2.0,
    deps="Depends on TurnRecord boundaries and context store (EnhancedContextSidebarView).",
    dep_ids=["E007-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6"],
    open_questions=["What counts as 'context item'? Files pinned, CLAUDE.md, system prompt injections, tool outputs."],
    files_touched=["Blaze/Sources/Context/ContextStore.swift","Blaze/Sources/Core/TurnRecord.swift"],
    new_files=["Blaze/Sources/Context/ContextDiff.swift"],
    telemetry_events=["context_diff_computed"],
    metrics=[{"name":"context_items_changed_per_turn","type":"histogram","unit":"items","target":"N/A","notes":"How much context changes between turns."}],
    ui_states=["No context changes","Context changes present"],
    ui_interactions=["Expand added list","Expand removed list"],
    ui_copy=["Context changes","Added","Removed"],
    functional=[
        "For each turn, show which context items were added and which were removed.",
        "Context diff is viewable during replay and (optionally) live for the last completed turn."
    ],
    nonfunctional=["Context snapshot comparisons must be efficient (hash-based)."],
    steps=[
        "Define ContextItem identity (type + path/id) and snapshot structure.",
        "On turn finalize, store snapshot; compute diff vs previous snapshot; attach to TurnRecord."
    ],
    edge_cases=[
        "First turn has no previous snapshot → treat all items as 'Added'.",
        "Context store includes transient items (tool outputs) → optionally categorize separately to avoid noise."
    ],
    failure_modes=["Context diffs incorrect due to unstable ordering → sort by stable key before diffing."],
    rollback_plan="If too noisy, show only pinned file changes first; hide other item types behind a toggle.",
    acceptance_tests=["Pin file in one turn; unpin in next; context diff shows added/removed appropriately."],
    acceptance_criteria=[
        "Context diff computed and displayed per turn.",
        "Diff is stable across replay and live."
    ],
    dod_criteria=["Context snapshot + diff implemented.","Manual verify with pin/unpin flow."],
    completed_when="Users can see what changed in context each turn.",
    completed_evidence="Screenshot showing Context changes box with added/removed items."
)
]

for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 7 (E008) ----------------
md.append("\n# Phase 14 — Polish Pass (Final)\n")
atoms_rest += [
make_atom(
    id="E014-F001-S001-T001-A001",
    severity="P2",
    epic_id="E014", feature_id="E014-F001", story_id="E014-F001-S001", task_id="E014-F001-S001-T001",
    epic="Polish Pass",
    feature="Motion + feedback",
    story="UI feels premium: hover, pressed feedback, smooth expand/collapse",
    story_desc="Add subtle interaction feedback and smooth animations without heavy dependencies, matching the glass/pro-tooling style in the spec.",
    task="Add hover/pressed states + expand/collapse animations",
    task_desc="Apply consistent hover/pressed affordances to cards/buttons; add smooth expand/collapse for ToolRunGroup and activity strip.",
    atom="Interaction polish: hover/pressed + animations",
    atom_desc="Implement lightweight SwiftUI animations and consistent styles across cards.",
    phase="Phase 14", area="UX", risk="low", priority="should", est_days=2.0,
    deps="Depends on cards existing.",
    dep_ids=["E004-F002-S001-T001-A001","E005-F002-S001-T001-A001","E006-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-10","/mnt/data/blaze-chat-ui-polish-spec (1).md#Motion-+-feedback"],
    open_questions=["Do we define a single CardStyle modifier? yes."],
    ui_states=["Hover","Pressed","Expanded"],
    ui_interactions=["Hover card","Press button","Expand/collapse"],
    ui_copy=["N/A"],
    telemetry_events=["N/A"],
    metrics=na_metric,
    functional=[
        "All cards/buttons have consistent hover/pressed feedback.",
        "Expand/collapse animations are smooth and do not jitter."
    ],
    nonfunctional=["Avoid spring chaos; use subtle easeInOut; no heavy animation libraries."],
    steps=[
        "Create shared `CardStyle` and `PrimaryButtonStyle` modifiers and apply across UI.",
        "Implement expand/collapse with .animation(.easeInOut(duration:0.15)) and test in long sessions."
    ],
    edge_cases=[
        "Reduced Motion accessibility setting → respect it by disabling animations.",
        "Rapid expand/collapse on streaming updates → avoid layout thrash by stabilizing view identity."
    ],
    failure_modes=["Animation causes re-render storm in long list → measure and simplify animations."],
    rollback_plan="Disable animations in long sessions and keep only hover/pressed states.",
    acceptance_tests=["Expand ToolRunGroup repeatedly during streaming; UI remains stable."],
    acceptance_criteria=[
        "UI feels responsive and premium.",
        "No animation-induced glitches in long sessions."
    ],
    dod_criteria=["Shared styles implemented and applied.","Manual polish review completed."],
    completed_when="UI polish meets spec expectations.",
    completed_evidence="Screen recording demonstrating hover + expand/collapse smoothness."
),
make_atom(
    id="E014-F002-S001-T001-A001",
    severity="P2",
    epic_id="E014", feature_id="E014-F002", story_id="E014-F002-S001", task_id="E014-F002-S001-T001",
    epic="Polish Pass",
    feature="Keyboard shortcuts",
    story="Power users can navigate quickly without mouse",
    story_desc="Add keyboard shortcuts for opening terminal/tools panel and navigating main surfaces; improves productivity and accessibility.",
    task="Implement app commands + keyboard shortcuts",
    task_desc="Add menu commands and shortcuts: toggle terminal, toggle right panel, focus search, undo last turn (with confirm).",
    atom="Keyboard shortcuts",
    atom_desc="Implement Commands menu group and bindings to AppState; document shortcuts.",
    phase="Phase 14", area="UX", risk="low", priority="should", est_days=2.0,
    deps="Depends on panel toggles and undo engine.",
    dep_ids=["E005-F003-S001-T001-A001","E003-F005-S001-T001-A001","E006-F003-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-10"],
    open_questions=["Command palette now or later? Later; start with shortcuts only."],
    ui_states=["N/A"],
    ui_interactions=["Keyboard shortcuts"],
    ui_copy=["Toggle Terminal","Toggle Right Panel","Undo last turn"],
    telemetry_events=["shortcut_used"],
    metrics=[{"name":"shortcut_used_count","type":"counter","unit":"count","target":"N/A","notes":"Shortcut usage."}],
    functional=[
        "Shortcuts toggle terminal and right panel reliably.",
        "Undo shortcut triggers the same confirmation as button (no bypass)."
    ],
    nonfunctional=["Shortcuts must not conflict with system defaults; use standard patterns."],
    steps=[
        "Create `BlazeCommands.swift` implementing commands menu in SwiftUI app.",
        "Bind commands to AppState flags and ensure confirmation dialogs are respected."
    ],
    edge_cases=[
        "Focus in text field prevents shortcut → use Commands menu to handle globally.",
        "Shortcut conflicts with user IME → allow fallback menu navigation."
    ],
    failure_modes=["Shortcut triggers unsafe action without confirmation → enforce confirm gate in engine layer."],
    rollback_plan="Ship menu items without shortcuts if conflicts occur.",
    acceptance_tests=["Use keyboard to open terminal and undo last turn; confirm prompt appears."],
    acceptance_criteria=[
        "Shortcuts work and are discoverable via menu.",
        "No unsafe bypass of confirmations."
    ],
    dod_criteria=["Shortcuts implemented and verified.","Menu labels show shortcuts."],
    completed_when="Keyboard navigation improves speed.",
    completed_evidence="Screen recording using shortcuts."
),
make_atom(
    id="E014-F003-S001-T001-A001",
    severity="P1",
    epic_id="E014", feature_id="E014-F003", story_id="E014-F003-S001", task_id="E014-F003-S001-T001",
    epic="Polish Pass",
    feature="Performance audit",
    story="Long sessions remain fast and smooth",
    story_desc="Avoid re-render storms and ensure lists are virtualized. Long sessions should remain responsive.",
    task="Run perf audit and fix re-render storms",
    task_desc="Profile with Instruments; ensure LazyVStack usage; add batching/throttling for streaming updates.",
    atom="Performance audit + virtualization fixes",
    atom_desc="Identify hotspots in Router publishing, terminal output rendering, timeline list; implement throttling and virtualization.",
    phase="Phase 14", area="Infra", risk="medium", priority="must", est_days=2.5,
    deps="Depends on timeline, terminal output, and router streaming.",
    dep_ids=["E003-F005-S001-T001-A001","E005-F001-S001-T002-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-10"],
    open_questions=["Do we cap right panel events by default? Probably show last 500 with 'Load more'."],
    telemetry_events=["perf_audit_completed"],
    metrics=[{"name":"ui_frame_drops","type":"gauge","unit":"count","target":"0","notes":"Subjective; also use Instruments."}],
    functional=[
        "Long sessions (1000+ events) remain scrollable and responsive.",
        "Streaming output does not cause UI freezes."
    ],
    nonfunctional=["Prefer incremental updates and throttled publishing (e.g., 50ms)."],
    steps=[
        "Use Instruments to profile CPU and SwiftUI view updates during long replay.",
        "Add throttling to TerminalStore publishes and Router intent emissions; ensure all long lists are Lazy/virtualized."
    ],
    edge_cases=[
        "Huge JSON payload in inspector → render truncated with 'Expand' button.",
        "Terminal output extremely large → ring buffer and virtualized lines."
    ],
    failure_modes=["Fixes reduce fidelity (dropping events) → never drop; cap display but retain stored events for export."],
    rollback_plan="If virtualization regressions appear, revert to previous stable list rendering and cap displayed items aggressively.",
    acceptance_tests=["Replay large session; scroll timeline; ensure no stutter and CPU reasonable."],
    acceptance_criteria=[
        "App remains responsive in long sessions.",
        "No event loss; caps are display-only."
    ],
    dod_criteria=["Perf audit completed and top hotspots addressed.","Manual long-session test passes."],
    completed_when="UI performance is acceptable for real-world long sessions.",
    completed_evidence="Instruments screenshot + manual test notes."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Optional Track (E015) ----------------
md.append("\n# Optional Track — Agent SDK Exploration (Non‑blocking)\n")
atoms_rest += [
make_atom(
    id="E015-F001-S001-T001-A001",
    severity="P2",
    epic_id="E015", feature_id="E015-F001", story_id="E015-F001-S001", task_id="E015-F001-S001-T001",
    epic="Agent SDK Exploration",
    feature="Capability validation spike",
    story="Determine what requires Agent SDK vs CLI",
    story_desc="Before committing to SDK-only UX, validate which capabilities are possible with CLI-first approach (AskUserQuestion round-trip, per-tool permissioning, richer events).",
    task="Write capability matrix and recommendation",
    task_desc="Prototype minimal SDK integration (separate branch) and compare event richness and interaction capabilities vs CLI.",
    atom="SDK capability matrix spike",
    atom_desc="Deliver decision-quality doc with evidence logs and go/no-go recommendation.",
    phase="Optional",
    area="Core",
    risk="medium",
    priority="could",
    est_days=2.0,
    deps="None",
    dep_ids=[],
    source_refs=["/mnt/data/feature-roadmap.md#Optional-Track"],
    open_questions=["Is SDK distribution acceptable for app packaging and licensing?"],
    files_touched=["N/A"],
    new_files=["docs/agent-sdk/capability-matrix.md"],
    commands_used=["N/A"],
    telemetry_events=["N/A"],
    metrics=na_metric,
    functional=[
        "Matrix compares CLI vs SDK for key UX requirements (AskUserQuestion, tool gating, event fidelity).",
        "Recommendation includes risks, costs, and migration strategy."
    ],
    nonfunctional=["Doc must be concise and decision-oriented."],
    steps=[
        "Create capability matrix doc and fill with evidence from both modes.",
        "Write recommendation section with explicit go/no-go and follow-up atoms if go."
    ],
    edge_cases=[
        "SDK requires auth flows not automatable → document and treat as blocker.",
        "SDK event schema differs significantly → document mapping cost."
    ],
    failure_modes=["Decision made on assumptions without evidence → include raw logs/screenshots in doc."],
    rollback_plan="N/A (spike only).",
    acceptance_tests=["Open the matrix doc and confirm evidence + decision are present."],
    acceptance_criteria=[
        "Matrix has enough evidence to decide.",
        "No production code path changed in main branch."
    ],
    dod_criteria=["Doc written and reviewed.","Prototype branch exists (if needed)."],
    completed_when="Stakeholders can decide on SDK adoption.",
    completed_evidence="Doc link + reviewer sign-off."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")

# ============================================================================
# USER-REQUESTED PHASE REMAPPING (E008-E013 for Phases 7-12)
# Added 2026-01-03 per user spec alignment request
# These phases follow the schema and provide comprehensive atom definitions
# ============================================================================

# ---------------- Phase 7 (E008) — Session Replay & Context Diff ----------------
md.append("\n# Phase 7 — Session Replay & Context Diff\n")
atoms_rest = []
atoms_rest += [
make_atom(
    id="E008-F001-S001-T001-A001",
    severity="P1",
    epic_id="E008", feature_id="E008-F001", story_id="E008-F001-S001", task_id="E008-F001-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Turn boundary detection and lifecycle",
    story="Turns have deterministic, stable boundaries enabling replay and undo",
    story_desc="Replay and context diff require stable turn boundaries. Start turn on user message; end on assistantComplete/result; persist TurnRecords with timestamps, event IDs, and context snapshots.",
    task="Implement TurnBoundaryDetector with lifecycle states",
    task_desc="Create TurnBoundaryDetector that monitors event stream, detects turn start (user message) and turn end (assistantComplete/result/timeout), and emits lifecycle events.",
    atom="Turn boundary detection engine",
    atom_desc="Implement state machine: Idle → Active → Finalizing → Completed. Store start/end timestamps, event ID ranges, and context snapshots per turn.",
    phase="Phase 7", area="Core", risk="medium", priority="must", est_days=2.0,
    deps="Requires TurnRecord model from Phase 5.",
    dep_ids=["E006-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6","/mnt/data/blaze-chat-ui-polish-spec (1).md#Context-management"],
    open_questions=["Should we use CLI turn markers if available, or rely solely on user/assistant boundaries?","What timeout applies if assistantComplete never arrives?"],
    files_touched=["Blaze/Sources/Core/TurnRecord.swift","Blaze/Sources/Replay/TurnBoundaryDetector.swift","Blaze/Sources/Render/RenderIntentRouter.swift"],
    new_files=["Blaze/Sources/Replay/TurnBoundaryDetector.swift"],
    data_model_changes=["Add TurnLifecycleState enum to TurnRecord","Add startEventId/endEventId fields"],
    event_contracts=["TurnBoundaryDetector emits TurnStarted/TurnEnded internal events to Router and Recorder"],
    telemetry_events=["turn_started","turn_ended","turn_boundary_timeout"],
    metrics=[{"name":"turn_duration_ms","type":"histogram","unit":"ms","target":"N/A","notes":"Distribution of turn durations."},{"name":"turn_boundary_timeouts","type":"counter","unit":"count","target":"0","notes":"Should be rare; indicates missing assistantComplete."}],
    log_expectations=["DEBUG turn_started id=<turnId> at=<timestamp>","DEBUG turn_ended id=<turnId> duration=<ms>"],
    functional=[
        "Turn starts reliably when user message is sent; turn ends when assistantComplete arrives or timeout triggers.",
        "TurnRecord captures event ID ranges, timestamps, and context snapshot references for replay.",
        "Late events after turn end attach to the closed turn with a warning badge."
    ],
    nonfunctional=["Turn detection must be consistent between live mode and replay mode for determinism.","State machine must handle out-of-order events gracefully."],
    steps=[
        "Create TurnBoundaryDetector class with state machine: Idle -> Active (on user message) -> Finalizing (on assistantComplete) -> Completed.",
        "Integrate detector into Router event pipeline; emit TurnStarted/TurnEnded to stores.",
        "Add configurable timeout (default 300s) for stuck turns; emit warning and force-close."
    ],
    edge_cases=[
        "AssistantComplete never arrives due to crash → force-close turn on next user message or app shutdown.",
        "Multiple user messages before assistantComplete (retries) → each starts a new turn; prior turn auto-closes.",
        "Events arrive after turn is closed → attach to closed turn with 'late' flag and log warning."
    ],
    failure_modes=["Turn boundaries overlap due to concurrent sessions → isolate by sessionId; reject cross-session attachment."],
    rollback_plan="If turn detection is unreliable, disable replay UI features and show 'Turn detection unstable' warning.",
    acceptance_tests=["Simulate 5 turns; verify 5 TurnRecords with correct event ranges.","Simulate timeout; verify turn closes with warning."],
    acceptance_criteria=[
        "Turn boundaries are deterministic and stable across runs.",
        "TurnRecords have complete event ID ranges and timestamps.",
        "Telemetry emitted reliably on turn start/end."
    ],
    dod_criteria=["TurnBoundaryDetector implemented with unit tests for all state transitions.","Integration test with fixture replay."],
    completed_when="Turns are tracked reliably with deterministic boundaries.",
    completed_evidence="Debug view showing numbered turns with start/end timestamps and event counts."
),
make_atom(
    id="E008-F002-S001-T001-A001",
    severity="P1",
    epic_id="E008", feature_id="E008-F002", story_id="E008-F002-S001", task_id="E008-F002-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Session recording to disk",
    story="Sessions are recorded as append-only NDJSON with manifest and index for replay",
    story_desc="To replay deterministically, record the raw NDJSON stream, a session manifest (metadata), and periodic index checkpoints for seeking. Files must be crash-safe.",
    task="Implement SessionRecorder with atomic writes and checkpoint index",
    task_desc="Create `.blaze/sessions/<sessionId>/` folder with events.ndjson (append-only), manifest.json (session metadata), and index.jsonl (periodic checkpoints for seeking).",
    atom="SessionRecorder persistence engine",
    atom_desc="Append raw NDJSON lines in order; write manifest on start and update on end; create index checkpoint every N events or T seconds.",
    phase="Phase 7", area="Core", risk="high", priority="must", est_days=2.5,
    deps="Requires sessionId from runtimeInfo and raw NDJSON access in parser.",
    dep_ids=["E002-F001-S001-T002-A001","E008-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6"],
    open_questions=["Checkpoint frequency: every 100 events or every 30 seconds?","Compression for large sessions?"],
    files_touched=["Blaze/Sources/App/AppState.swift","Blaze/Sources/Engine/NDJSONParser.swift"],
    new_files=["Blaze/Sources/Replay/SessionRecorder.swift","Blaze/Sources/Replay/SessionManifest.swift"],
    data_model_changes=["SessionManifest model with sessionId, startTime, endTime, eventCount, modelId, claudeCodeVersion"],
    event_contracts=["Recorder hooks into NDJSONParser raw line emission before parsing."],
    telemetry_events=["session_recording_started","session_recording_stopped","session_recording_checkpoint","session_recording_failed"],
    metrics=[{"name":"session_recording_failures","type":"counter","unit":"count","target":"0","notes":"Disk failures should be rare."},{"name":"session_events_recorded","type":"counter","unit":"events","target":"N/A","notes":"Total events across sessions."}],
    log_expectations=["INFO session_recording_started sessionId=<id> path=<path>","DEBUG session_recording_checkpoint offset=<n>"],
    functional=[
        "All raw NDJSON lines are recorded in exact order received, preserving original bytes.",
        "Manifest contains session metadata: id, start/end times, event count, CLI version, model.",
        "Index contains periodic checkpoints: (eventNumber, byteOffset, timestamp) for efficient seeking."
    ],
    nonfunctional=["Recording must not block main thread; use buffered async IO with flush on checkpoints.","Writes must be atomic (temp+rename) to prevent corruption.","Handle disk full gracefully with WarningCard."],
    steps=[
        "Create SessionRecorder class with start(sessionId)/append(line)/checkpoint()/stop() methods.",
        "Hook recorder at NDJSONParser raw line boundary (before JSON parsing) for byte-exact fidelity.",
        "Implement atomic write for manifest/index using temp file + rename pattern.",
        "Add checkpoint logic: every 100 events or 30 seconds, whichever comes first."
    ],
    edge_cases=[
        "Disk write permission denied → disable recording, show WarningCard, continue session without recording.",
        "Session ends abruptly (crash/force quit) → on next launch, detect incomplete manifest and mark as 'partial'.",
        "Very large session (100k+ events) → implement optional rotation or streaming export."
    ],
    failure_modes=["Non-atomic writes corrupt file on crash → always use temp+rename pattern.","Buffered IO loses data on crash → flush buffer on each checkpoint."],
    rollback_plan="If recorder causes performance issues, feature-flag it off and rely on fixture-based testing only.",
    acceptance_tests=["Run session with 50 events; verify events.ndjson has 50 lines; manifest has correct count.","Force-kill app during recording; verify next launch detects partial session."],
    acceptance_criteria=[
        "Session recordings exist on disk after any session.",
        "Manifest and index are present and valid JSON.",
        "Recording failures are visible but non-fatal."
    ],
    dod_criteria=["SessionRecorder implemented with atomic write tests.","Manual verification on disk.","Performance test shows no UI blocking."],
    completed_when="Sessions are recorded locally for replay.",
    completed_evidence="Screenshot of .blaze/sessions/<id>/ folder with events.ndjson, manifest.json, index.jsonl."
),
make_atom(
    id="E008-F003-S001-T001-A001",
    severity="P1",
    epic_id="E008", feature_id="E008-F003", story_id="E008-F003-S001", task_id="E008-F003-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Replay engine with play/pause/seek/speed controls",
    story="Recorded sessions replay through the same pipeline deterministically",
    story_desc="Replay feeds recorded NDJSON lines into NDJSONParser and Router, supporting play, pause, seek (via index), step (single event), and speed control (1x, 2x, 4x, 0.5x).",
    task="Implement ReplayEngine with state machine and playback controls",
    task_desc="Load session folder, parse manifest/index, replay lines with timestamp-based pacing, support seek using index checkpoints, enforce read-only mode.",
    atom="ReplayEngine core implementation",
    atom_desc="State machine: Stopped → Loading → Playing → Paused → Seeking. Uses index for efficient seek. Rebuilds state by replaying from nearest checkpoint.",
    phase="Phase 7", area="Core", risk="high", priority="must", est_days=3.0,
    deps="Requires SessionRecorder artifacts and Router determinism.",
    dep_ids=["E008-F002-S001-T001-A001","E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6"],
    open_questions=["Seek granularity: by timestamp, by turn, or by event number? Start with event number; add turn jump in UI.","How to enforce read-only mode?"],
    files_touched=["Blaze/Sources/App/AppState.swift","Blaze/Sources/Render/RenderIntentRouter.swift"],
    new_files=["Blaze/Sources/Replay/ReplayEngine.swift","Blaze/Sources/Replay/ReplayState.swift"],
    data_model_changes=["ReplayState enum: stopped/loading/playing/paused/seeking","ReplayPosition: eventNumber, timestamp"],
    event_contracts=["ReplayEngine emits same events as live parser; Router cannot distinguish replay from live."],
    ui_states=["Replay Stopped","Replay Loading","Replay Playing","Replay Paused","Replay Seeking"],
    ui_interactions=["Play","Pause","Stop","Seek to turn","Seek to timestamp","Step forward","Speed: 1x/2x/4x/0.5x"],
    ui_copy=["Play","Pause","Stop","Replay","1x","2x","4x","0.5x","Seeking..."],
    telemetry_events=["replay_loaded","replay_started","replay_paused","replay_seek","replay_stopped"],
    metrics=[{"name":"replay_seek_duration_ms","type":"histogram","unit":"ms","target":"<500","notes":"Seek should feel instant."},{"name":"replay_sessions_loaded","type":"counter","unit":"count","target":"N/A","notes":"Usage."}],
    log_expectations=["INFO replay_loaded sessionId=<id> eventCount=<n>","DEBUG replay_seek targetEvent=<n> nearestCheckpoint=<m>"],
    functional=[
        "ReplayEngine loads session from disk, parses manifest/index, and makes events available for playback.",
        "Play emits events with configurable pacing (real-time at 1x, accelerated at 2x/4x, slowed at 0.5x).",
        "Seek uses index to find nearest checkpoint, replays from checkpoint to target, rebuilds all state.",
        "Step advances exactly one event."
    ],
    nonfunctional=["Replay must be deterministic: same session → same state at any given event number.","Read-only mode must prevent any file system writes during replay.","Seek must complete in <500ms for sessions <10k events."],
    steps=[
        "Create ReplayEngine with load(sessionPath)/play()/pause()/seek(eventNumber)/step()/setSpeed() methods.",
        "Implement pacing: calculate delay between events based on timestamps and speed multiplier.",
        "Implement seek: find nearest checkpoint in index, reset stores (Router.resetStores()), replay from checkpoint to target.",
        "Add read-only mode: set flag in AppState that all write tools check before executing."
    ],
    edge_cases=[
        "Session has no index (old format) → full replay from start on seek (slow but functional).",
        "Seek to event past end → clamp to last event.",
        "Replay while live session active → prompt to stop live session first.",
        "Corrupted event line → skip with warning, continue replay."
    ],
    failure_modes=["Non-deterministic state after seek → add state verification checksums; log mismatch as bug.","Speed multiplier causes UI jank → batch events when speed >2x."],
    rollback_plan="If replay is unstable, ship session recording only; disable playback UI.",
    acceptance_tests=["Load recorded session; play to end; verify final state matches original.","Seek to turn 3; verify state matches.","Test all speed settings."],
    acceptance_criteria=[
        "Replay produces identical UI state as original session at any event number.",
        "Seek is fast and reliable.",
        "Read-only mode prevents file modifications."
    ],
    dod_criteria=["ReplayEngine implemented with state machine tests.","Manual verification of all controls.","Determinism verified with fixture."],
    completed_when="Sessions can be replayed with full fidelity.",
    completed_evidence="Screen recording of replay UI with play/pause/seek working."
),
make_atom(
    id="E008-F004-S001-T001-A001",
    severity="P2",
    epic_id="E008", feature_id="E008-F004", story_id="E008-F004-S001", task_id="E008-F004-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Replay UI with turn scrubber",
    story="Users can visually navigate replay with a turn-based scrubber",
    story_desc="Replay UI shows a timeline with turns, allows clicking to jump to any turn, displays current position, and provides playback controls.",
    task="Implement ReplayControlsView with turn timeline scrubber",
    task_desc="Create ReplayControlsView with: turn timeline (horizontal bar with turn markers), current position indicator, play/pause/stop buttons, speed selector, and turn info tooltip.",
    atom="Replay UI controls and scrubber",
    atom_desc="Visual replay controls bound to ReplayEngine state; turn scrubber allows click-to-seek; smooth position indicator animation.",
    phase="Phase 7", area="UI", risk="medium", priority="should", est_days=2.0,
    deps="Requires ReplayEngine and TurnRecords.",
    dep_ids=["E008-F003-S001-T001-A001","E008-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6"],
    open_questions=["Scrubber in right panel or bottom bar? Suggest bottom bar for visibility."],
    files_touched=["Blaze/Sources/App/AppState.swift","Blaze/Sources/UI/Replay/"],
    new_files=["Blaze/Sources/UI/Replay/ReplayControlsView.swift","Blaze/Sources/UI/Replay/TurnScrubberView.swift"],
    ui_states=["Replay idle","Replay playing","Replay paused","Seeking"],
    ui_interactions=["Click turn in scrubber to seek","Click play/pause","Click stop","Select speed from picker","Drag position indicator"],
    ui_copy=["Turn 1","Turn 2","...","Now playing","Paused","1x","2x","4x"],
    telemetry_events=["replay_ui_opened","replay_turn_clicked","replay_speed_changed"],
    metrics=[{"name":"replay_ui_usage","type":"counter","unit":"sessions","target":"N/A","notes":"How often replay is used."}],
    functional=[
        "Turn scrubber displays all turns as segments proportional to duration.",
        "Clicking a turn seeks to its start.",
        "Position indicator updates smoothly during playback.",
        "Speed selector allows 0.5x/1x/2x/4x."
    ],
    nonfunctional=["Scrubber must handle 50+ turns without becoming unusable.","Animations must be 60fps smooth."],
    steps=[
        "Create TurnScrubberView using horizontal bar with turn segments; bind to TurnStore data.",
        "Create ReplayControlsView composing scrubber, play/pause/stop buttons, and speed picker.",
        "Wire controls to ReplayEngine methods; update UI based on ReplayState.",
        "Add smooth position indicator using CADisplayLink or SwiftUI animation."
    ],
    edge_cases=[
        "Session has only 1 turn → show single segment; scrubber still functional.",
        "Very short turns → ensure minimum visual width for clickability.",
        "Replay ends → stop indicator at end; enable restart."
    ],
    failure_modes=["Scrubber updates too frequently during streaming → throttle UI updates to 30fps."],
    rollback_plan="If scrubber is too complex, ship simpler event-number slider first.",
    acceptance_tests=["Open replay; click turn 3; verify jump.","Test all playback controls.","Verify position indicator moves smoothly."],
    acceptance_criteria=[
        "Replay controls are intuitive and responsive.",
        "Turn scrubber accurately represents session structure."
    ],
    dod_criteria=["ReplayControlsView implemented with all controls.","Manual verification of all interactions."],
    completed_when="Users can navigate replay visually.",
    completed_evidence="Screen recording of replay UI with turn navigation."
),
make_atom(
    id="E008-F005-S001-T001-A001",
    severity="P1",
    epic_id="E008", feature_id="E008-F005", story_id="E008-F005-S001", task_id="E008-F005-S001-T001",
    epic="Session Replay & Context Diff",
    feature="Context diff between turns",
    story="Users can see what context changed between any two turns",
    story_desc="For each turn, track context additions (files pinned, CLAUDE.md loaded) and removals. Display diff view comparing Turn N to Turn N-1 or any arbitrary turn pair.",
    task="Implement ContextDiffEngine and ContextDiffView",
    task_desc="Track context items per turn in TurnRecord; compute diff (added/removed/unchanged) between turns; display in collapsible UI.",
    atom="Context diff tracking and UI",
    atom_desc="Store context snapshot IDs in TurnRecord; compute diff on demand; render as +/-/unchanged lists with token estimates.",
    phase="Phase 7", area="Core", risk="medium", priority="must", est_days=2.0,
    deps="Requires TurnRecord and context tracking in ContextStore.",
    dep_ids=["E008-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-6","/mnt/data/blaze-chat-ui-polish-spec (1).md#Context-management"],
    open_questions=["Store full context copy or just IDs? IDs with separate ContextStore lookup preferred."],
    files_touched=["Blaze/Sources/Core/TurnRecord.swift","Blaze/Sources/Context/ContextStore.swift"],
    new_files=["Blaze/Sources/Context/ContextDiffEngine.swift","Blaze/Sources/UI/Context/ContextDiffView.swift"],
    data_model_changes=["Add contextSnapshotId to TurnRecord","Add ContextSnapshot model with item IDs and timestamp"],
    ui_states=["Context diff loading","Context diff ready","No changes"],
    ui_interactions=["Expand context diff","Compare with turn N","Show token impact"],
    ui_copy=["Added","Removed","Unchanged","Context changes between turns"],
    telemetry_events=["context_diff_viewed","context_diff_compared"],
    metrics=[{"name":"context_diff_views","type":"counter","unit":"count","target":"N/A","notes":"Usage."}],
    functional=[
        "Each TurnRecord stores a reference to its context snapshot.",
        "ContextDiffEngine computes added/removed/unchanged items between any two snapshots.",
        "UI displays diff with +/- indicators and token estimates per item."
    ],
    nonfunctional=["Diff computation must be fast (<50ms) for reasonable context sizes (<100 items)."],
    steps=[
        "Add contextSnapshotId to TurnRecord; create snapshot on turn start.",
        "Implement ContextDiffEngine.diff(snapshotA, snapshotB) returning (added, removed, unchanged).",
        "Create ContextDiffView with collapsible sections for added/removed/unchanged items."
    ],
    edge_cases=[
        "First turn has no previous context → show 'Initial context' instead of diff.",
        "Context item deleted from disk between snapshots → show as 'removed (file deleted)'.",
        "Very large diff → paginate or show summary first."
    ],
    failure_modes=["Snapshot storage grows unbounded → implement snapshot retention policy (keep last N or dedupe)."],
    rollback_plan="If diff is unreliable, show raw context list per turn without computed diff.",
    acceptance_tests=["Pin file in turn 1; unpin in turn 2; context diff shows removal.","Compare turn 1 to turn 3; verify cumulative diff."],
    acceptance_criteria=[
        "Context diff accurately shows additions and removals.",
        "UI is clear and navigable."
    ],
    dod_criteria=["ContextDiffEngine implemented with tests.","ContextDiffView renders correctly."],
    completed_when="Users can understand context evolution across turns.",
    completed_evidence="Screenshot of context diff showing added/removed items."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 8 (E009) — Context Window & Token Usage ----------------
md.append("\n# Phase 8 — Context Window & Token Usage\n")
atoms_rest += [
make_atom(
    id="E009-F001-S001-T001-A001",
    severity="P1",
    epic_id="E009", feature_id="E009-F001", story_id="E009-F001-S001", task_id="E009-F001-S001-T001",
    epic="Context Window & Token Usage",
    feature="Token estimation engine",
    story="Users can see estimated token counts for context items before sending",
    story_desc="Implement a fast token estimator using cl100k_base tokenizer (or approximation) for files, snippets, and conversation history. Show running totals and model limit.",
    task="Implement TokenEstimator with cl100k_base tokenizer",
    task_desc="Create TokenEstimator that can estimate tokens for strings, files, and context items. Cache results for unchanged content. Provide budget calculation against model limits.",
    atom="TokenEstimator core implementation",
    atom_desc="Implement estimator with caching, approximation mode for large files, and budget calculation. Expose via AppState.tokenBudget.",
    phase="Phase 8", area="Core", risk="medium", priority="must", est_days=2.0,
    deps="Requires context items from ContextStore.",
    dep_ids=[],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-7"],
    open_questions=["Use actual tiktoken or fast approximation (chars/4)? Start with approximation, add real tokenizer later.","Model limits: hardcode or fetch from CLI?"],
    files_touched=["Blaze/Sources/App/AppState.swift"],
    new_files=["Blaze/Sources/Tokens/TokenEstimator.swift","Blaze/Sources/Tokens/TokenBudget.swift"],
    data_model_changes=["TokenBudget model with: estimated, limit, remaining, categories breakdown"],
    telemetry_events=["token_estimate_computed","token_budget_warning"],
    metrics=[{"name":"token_estimate_cache_hits","type":"counter","unit":"count","target":"N/A","notes":"Caching effectiveness."},{"name":"token_budget_warnings","type":"counter","unit":"count","target":"N/A","notes":"When users approach limits."}],
    log_expectations=["DEBUG token_estimate_computed items=<n> total=<tokens>"],
    functional=[
        "TokenEstimator provides estimate(String) and estimate(ContextItem) methods.",
        "Estimates are cached by content hash for unchanged items.",
        "TokenBudget aggregates all context items and compares to model limit."
    ],
    nonfunctional=["Estimation must complete in <100ms for typical context sizes.","Cache must be bounded to prevent memory bloat."],
    steps=[
        "Create TokenEstimator using character/4 approximation initially (good enough for estimates).",
        "Implement caching keyed by content hash; evict LRU entries.",
        "Create TokenBudget that sums estimates and compares to configurable model limit.",
        "Emit warning when budget > 80% of limit."
    ],
    edge_cases=[
        "Binary file in context → return 0 tokens with 'binary file' note.",
        "Very large file → estimate from first N chars and extrapolate.",
        "Model limit unknown → show 'Unknown limit' and hide percentage."
    ],
    failure_modes=["Estimates are wildly inaccurate → add calibration tests against real tokenizer."],
    rollback_plan="If estimation is unreliable, hide percentages and show only raw estimates with disclaimer.",
    acceptance_tests=["Estimate 1000-char string; verify ~250 tokens (±20%).","Add 5 context items; verify budget sums correctly."],
    acceptance_criteria=[
        "Token estimates are computed and cached efficiently.",
        "Budget shows clear running total and remaining capacity."
    ],
    dod_criteria=["TokenEstimator implemented with accuracy tests.","TokenBudget wired to AppState."],
    completed_when="Token estimates are available throughout the app.",
    completed_evidence="Screenshot of Tokens panel showing breakdown."
),
make_atom(
    id="E009-F002-S001-T001-A001",
    severity="P1",
    epic_id="E009", feature_id="E009-F002", story_id="E009-F002-S001", task_id="E009-F002-S001-T001",
    epic="Context Window & Token Usage",
    feature="Token usage sidebar view",
    story="Tokens panel shows clear breakdown with categories and warnings",
    story_desc="TokensSidebarView displays: total usage, model limit, breakdown by category (system prompt, CLAUDE.md, MCP injection, conversation, tool outputs), and threshold warnings.",
    task="Implement TokensSidebarView with category breakdown and warnings",
    task_desc="Create or update TokensSidebarView to show usage breakdown, progress bar, category chips, and warning banners when approaching limits.",
    atom="Tokens panel UI implementation",
    atom_desc="Bind to TokenBudget state; render progress bar, category breakdown, and threshold warnings with hysteresis.",
    phase="Phase 8", area="UI", risk="low", priority="must", est_days=1.5,
    deps="Requires TokenEstimator.",
    dep_ids=["E009-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-7"],
    open_questions=["Show percentages or raw token counts? Both, with toggle."],
    files_touched=["Blaze/Sources/UI/Sidebars/TokensSidebarView.swift"],
    new_files=[],
    ui_states=["Tokens: OK","Tokens: Warning (>80%)","Tokens: Critical (>95%)"],
    ui_interactions=["Expand category details","Toggle percentage/raw view","Clear conversation to free tokens"],
    ui_copy=["Token Usage","System Prompt","CLAUDE.md","Context","Conversation","Remaining","Warning: Approaching limit"],
    telemetry_events=["tokens_panel_opened","tokens_warning_shown"],
    metrics=[{"name":"tokens_panel_views","type":"counter","unit":"count","target":"N/A","notes":"Usage."}],
    functional=[
        "Progress bar shows usage vs limit with color-coded states (green/yellow/red).",
        "Category breakdown shows token count per category with percentage.",
        "Warnings appear at 80% (yellow) and 95% (red) thresholds with hysteresis (clear at 75%/90%)."
    ],
    nonfunctional=["Panel must render quickly; avoid recomputing on every frame."],
    steps=[
        "Update TokensSidebarView to consume TokenBudget from AppState.",
        "Create progress bar with color states based on thresholds.",
        "Add category breakdown as collapsible sections.",
        "Implement warning banners with hysteresis to prevent flicker."
    ],
    edge_cases=[
        "Model limit unknown → hide progress bar; show only raw totals.",
        "All categories at 0 → show 'No content in context'.",
        "User oscillates around threshold → hysteresis prevents flicker."
    ],
    failure_modes=["Warnings spam due to rapid updates → throttle updates to 500ms."],
    rollback_plan="Ship simple numeric display without progress bar if styling is problematic.",
    acceptance_tests=["Add content until 85% → warning appears.","Remove content to 70% → warning clears."],
    acceptance_criteria=[
        "Tokens panel provides at-a-glance understanding of context usage.",
        "Warnings are helpful, not noisy."
    ],
    dod_criteria=["TokensSidebarView updated and styled.","Hysteresis verified."],
    completed_when="Users can quickly assess context budget.",
    completed_evidence="Screenshot of Tokens panel with breakdown and warning."
),
make_atom(
    id="E009-F003-S001-T001-A001",
    severity="P2",
    epic_id="E009", feature_id="E009-F003", story_id="E009-F003-S001", task_id="E009-F003-S001-T001",
    epic="Context Window & Token Usage",
    feature="Enhanced context sidebar with token counts",
    story="Context list shows per-item token estimates with pin/unpin actions",
    story_desc="EnhancedContextSidebarView displays each context item with its token estimate, pin/unpin actions, and immediate totals update.",
    task="Add token counts and pin/unpin actions to context sidebar",
    task_desc="Update EnhancedContextSidebarView to show token estimate per item, pin/unpin buttons, and updated totals on action.",
    atom="Context sidebar with token counts",
    atom_desc="Each context row shows: name, token estimate (or 'Estimating...'), pin/unpin button. Actions update TokenBudget immediately.",
    phase="Phase 8", area="UI", risk="medium", priority="should", est_days=2.0,
    deps="Requires TokenEstimator and ContextStore.",
    dep_ids=["E009-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-7"],
    open_questions=["Multi-select pin/unpin? Start with single-item."],
    files_touched=["Blaze/Sources/UI/Sidebars/EnhancedContextSidebarView.swift","Blaze/Sources/Context/ContextStore.swift"],
    ui_states=["Item pinned","Item unpinned","Estimating..."],
    ui_interactions=["Pin item","Unpin item","View item details"],
    ui_copy=["Pin","Unpin","In Context","~X tokens"],
    telemetry_events=["context_item_pinned","context_item_unpinned"],
    metrics=[{"name":"context_pin_actions","type":"counter","unit":"count","target":"N/A","notes":"Usage."}],
    functional=[
        "Each context item row displays token estimate (or placeholder while computing).",
        "Pin/unpin actions update ContextStore and TokenBudget immediately.",
        "Totals at bottom update in real-time."
    ],
    nonfunctional=["Actions must feel instant; any IO is async."],
    steps=[
        "Add token count label to each context row from TokenEstimator.",
        "Implement pin/unpin buttons wired to ContextStore.pin()/unpin().",
        "Ensure TokenBudget recalculates on context changes."
    ],
    edge_cases=[
        "Token estimate unavailable (binary/huge file) → show '—' with tooltip.",
        "Pinned file deleted from disk → show warning badge and allow unpin.",
        "Rapid pin/unpin → debounce budget recalculation."
    ],
    failure_modes=["Pin/unpin causes crashes due to concurrent modifications → ensure thread-safe ContextStore."],
    rollback_plan="Ship token counts read-only; delay pin/unpin actions if unstable.",
    acceptance_tests=["Pin file; token total increases.","Unpin file; token total decreases."],
    acceptance_criteria=[
        "Token counts visible per context item.",
        "Pin/unpin works and updates totals."
    ],
    dod_criteria=["Context sidebar updated.","Actions verified."],
    completed_when="Users can manage context with token visibility.",
    completed_evidence="Screenshot of context sidebar with token counts and pin buttons."
),
make_atom(
    id="E009-F004-S001-T001-A001",
    severity="P2",
    epic_id="E009", feature_id="E009-F004", story_id="E009-F004-S001", task_id="E009-F004-S001-T001",
    epic="Context Window & Token Usage",
    feature="Token usage from CLI events",
    story="Actual token usage from CLI is displayed alongside estimates",
    story_desc="When CLI provides token usage in events (cache hits, actual tokens used), display both estimated and actual values for comparison and calibration.",
    task="Parse CLI token usage events and display in Tokens panel",
    task_desc="Add TokenUsage event parsing; display 'Actual: X' alongside 'Estimated: Y' in Tokens panel; calibrate estimator if delta is large.",
    atom="CLI token usage integration",
    atom_desc="Parse usage events; update TokenBudget with actual values; show comparison in UI; log calibration opportunities.",
    phase="Phase 8", area="Core", risk="low", priority="should", est_days=1.0,
    deps="Requires TokensSidebarView and event parsing.",
    dep_ids=["E009-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-7"],
    open_questions=["What event type contains token usage? Check system.result or similar."],
    files_touched=["Blaze/Sources/Engine/ClaudeEventMapper.swift","Blaze/Sources/Tokens/TokenBudget.swift"],
    telemetry_events=["token_usage_received","token_calibration_needed"],
    metrics=[{"name":"token_estimate_error_pct","type":"gauge","unit":"percent","target":"<20","notes":"How far off estimates are from actual."}],
    functional=[
        "Actual token usage from CLI is parsed and stored.",
        "Tokens panel shows both estimated and actual when available.",
        "Large discrepancies are logged for estimator calibration."
    ],
    nonfunctional=["Parsing must not slow down event processing."],
    steps=[
        "Identify token usage fields in CLI events; add to NormalizedEvent.",
        "Update TokenBudget with actual usage when available.",
        "Display 'Est: X / Actual: Y' in UI when both present."
    ],
    edge_cases=[
        "CLI doesn't provide usage (older version) → show only estimates.",
        "Usage arrives after turn ends → update retroactively."
    ],
    failure_modes=["Parsing wrong field → validate with fixture; log schema version."],
    rollback_plan="If CLI events don't have usage, feature is simply dormant.",
    acceptance_tests=["Replay fixture with usage events; verify actual values displayed."],
    acceptance_criteria=[
        "Actual usage displayed when available.",
        "Estimates and actuals compared for user awareness."
    ],
    dod_criteria=["Event parsing added.","UI updated."],
    completed_when="Users see both estimated and actual token usage.",
    completed_evidence="Screenshot showing 'Est: 1200 / Actual: 1180'."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 9 (E010) — Dry Run / Preview Impact & Reruns ----------------
md.append("\n# Phase 9 — Dry Run / Preview Impact & Reruns\n")
atoms_rest += [
make_atom(
    id="E010-F001-S001-T001-A001",
    severity="P1",
    epic_id="E010", feature_id="E010-F001", story_id="E010-F001-S001", task_id="E010-F001-S001-T001",
    epic="Dry Run / Preview Impact",
    feature="Preview engine with scratch workspace",
    story="Users can preview risky changes without modifying the real workspace",
    story_desc="Preview mode redirects file writes to a scratch directory, computes diffs against the real workspace, and allows inspection before applying.",
    task="Implement PreviewEngine with path redirection and diff computation",
    task_desc="Create scratch directory per preview session (.blaze/preview/<id>/), redirect all file writes, compute diff vs real workspace, store as FileDiff for display.",
    atom="PreviewEngine scratch workspace implementation",
    atom_desc="Implement path redirection layer, scratch directory management, diff computation against real workspace, and 'Apply' action.",
    phase="Phase 9", area="Core", risk="high", priority="must", est_days=3.0,
    deps="Requires DiffService and TurnRecord.",
    dep_ids=["E006-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-8"],
    open_questions=["Use full copy or sparse copy (only touched files)?","How to handle tools that read files - from real or scratch?"],
    files_touched=["Blaze/Sources/Engine/ClaudeCodeAdapter.swift"],
    new_files=["Blaze/Sources/Preview/PreviewEngine.swift","Blaze/Sources/Preview/ScratchWorkspace.swift"],
    data_model_changes=["PreviewSession model with id, scratchPath, originalPaths, computedDiffs"],
    event_contracts=["PreviewEngine intercepts file write events and redirects to scratch."],
    ui_states=["Preview mode active","Preview running","Preview ready","Preview failed"],
    ui_interactions=["Enable preview mode","Inspect preview diff","Apply changes","Cancel preview"],
    ui_copy=["Preview Mode","Preview changes","Apply","Cancel","Preview failed"],
    telemetry_events=["preview_started","preview_completed","preview_failed","preview_applied","preview_cancelled"],
    metrics=[{"name":"preview_duration_ms","type":"histogram","unit":"ms","target":"<5000","notes":"User-perceived preview time."},{"name":"preview_apply_rate","type":"gauge","unit":"ratio","target":"N/A","notes":"How often users apply vs cancel."}],
    log_expectations=["INFO preview_started id=<id>","INFO preview_completed diffs=<n>"],
    functional=[
        "Preview mode intercepts all file writes and redirects to scratch directory.",
        "Computed diffs show what would change in the real workspace.",
        "Apply action copies scratch changes to real workspace atomically.",
        "Cancel cleans up scratch directory."
    ],
    nonfunctional=["Path redirection must be bulletproof; no writes escape to real workspace in preview mode.","Scratch cleanup must not leave orphaned directories."],
    steps=[
        "Create ScratchWorkspace class managing .blaze/preview/<id>/ directories.",
        "Implement path mapping: when preview active, map real paths to scratch equivalents.",
        "Hook into tool execution layer to intercept file writes.",
        "Compute diff between scratch files and real workspace using DiffService.",
        "Implement Apply: validate unchanged state, copy files atomically, clean scratch."
    ],
    edge_cases=[
        "Tool tries to write absolute path outside workspace → block and show ErrorCard.",
        "Scratch disk full → fail gracefully with error message.",
        "File deleted in real workspace after preview started → show conflict warning.",
        "Tool reads file → reads from real workspace (preview only affects writes)."
    ],
    failure_modes=["Path mapping bug leaks writes to real workspace → add comprehensive path guard tests; treat as P0 if occurs."],
    rollback_plan="Ship preview as read-only inspection (no Apply) initially if Apply path is risky.",
    acceptance_tests=["Enable preview; run edit command; verify real file unchanged; verify scratch has edit.","Apply preview; verify real file now changed."],
    acceptance_criteria=[
        "Preview mode completely isolates writes from real workspace.",
        "Diffs accurately represent what Apply would do.",
        "Apply is safe and atomic."
    ],
    dod_criteria=["PreviewEngine implemented with path guard tests.","Manual verification of isolation."],
    completed_when="Users can safely preview risky changes.",
    completed_evidence="Screen recording: enable preview, run edit, inspect diff, cancel (file unchanged)."
),
make_atom(
    id="E010-F002-S001-T001-A001",
    severity="P1",
    epic_id="E010", feature_id="E010-F002", story_id="E010-F002-S001", task_id="E010-F002-S001-T001",
    epic="Dry Run / Preview Impact",
    feature="Preview diff UI and apply flow",
    story="Preview diffs are displayed clearly with Apply/Cancel controls",
    story_desc="PreviewDiffView shows the computed diffs in DiffCard format with a 'Preview' badge, Apply button (with confirmation), and Cancel button.",
    task="Implement PreviewDiffView with Apply/Cancel controls",
    task_desc="Create PreviewDiffView embedding DiffCard for each file, 'Preview' badge, Apply button with PromptPolicy confirmation, Cancel button.",
    atom="Preview diff UI implementation",
    atom_desc="UI shows preview state, allows per-file inspection, provides gated Apply action, handles conflicts.",
    phase="Phase 9", area="UI", risk="high", priority="must", est_days=2.0,
    deps="Requires PreviewEngine.",
    dep_ids=["E010-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-8"],
    open_questions=["Show all files in one card or one card per file? One summary card with expandable per-file details."],
    files_touched=["Blaze/Sources/UI/Cards/DiffCard.swift"],
    new_files=["Blaze/Sources/UI/Preview/PreviewDiffView.swift"],
    ui_states=["Preview ready","Applying","Applied","Cancelled","Conflict detected"],
    ui_interactions=["Inspect file diff","Apply all changes","Cancel preview","Handle conflict"],
    ui_copy=["Preview","Apply changes","Cancel","Applying...","Applied successfully","Conflict: file changed since preview"],
    telemetry_events=["preview_ui_apply_clicked","preview_ui_cancel_clicked","preview_conflict_shown"],
    metrics=[{"name":"preview_conflicts","type":"counter","unit":"count","target":"N/A","notes":"How often conflicts occur."}],
    functional=[
        "PreviewDiffView shows all preview diffs with 'Preview' badge.",
        "Apply button triggers PromptPolicy check, then PreviewEngine.apply().",
        "Conflict detection shows warning and allows skip/retry.",
        "Cancel cleans up preview state."
    ],
    nonfunctional=["Apply must be gated by PromptPolicy confirmation for risky changes."],
    steps=[
        "Create PreviewDiffView composing DiffCard rows with 'Preview' badge overlay.",
        "Wire Apply button to PromptPolicy check then PreviewEngine.apply().",
        "Implement conflict detection: hash real file before apply, compare to preview-start hash.",
        "Handle Apply failure: show ErrorCard with retry option."
    ],
    edge_cases=[
        "Real file changed since preview (conflict) → show 'Conflict' badge, allow skip or re-run preview.",
        "Apply partially fails (some files succeed) → show partial report, allow retry for failed.",
        "Very large diff → paginate or summarize."
    ],
    failure_modes=["Apply without confirmation → enforce PromptPolicy gating."],
    rollback_plan="If Apply is unstable, hide Apply button and show 'Copy diff to clipboard' instead.",
    acceptance_tests=["Preview edit; Apply; verify file changed.","Preview edit; modify file externally; Apply; verify conflict warning."],
    acceptance_criteria=[
        "Preview UI is clear and trustworthy.",
        "Apply is safe with confirmation.",
        "Conflicts are handled gracefully."
    ],
    dod_criteria=["PreviewDiffView implemented.","Conflict handling tested."],
    completed_when="Users can preview and apply changes confidently.",
    completed_evidence="Screen recording: preview → Apply → success."
),
make_atom(
    id="E010-F003-S001-T001-A001",
    severity="P2",
    epic_id="E010", feature_id="E010-F003", story_id="E010-F003-S001", task_id="E010-F003-S001-T001",
    epic="Dry Run / Preview Impact",
    feature="Rerun with context fixes",
    story="Users can attach missing context and rerun the last prompt",
    story_desc="If a run fails due to missing context (file not provided, unclear instructions), users can attach additional files/notes and rerun the prompt as a new turn.",
    task="Implement RerunFlow with context attachment",
    task_desc="Store last user prompt; provide UI to attach additional context items; rerun creates new TurnRecord with updated context.",
    atom="Rerun with context fixes implementation",
    atom_desc="Store prompt, allow context addition, trigger new CLI run (or guide user), create new turn.",
    phase="Phase 9", area="UX", risk="medium", priority="should", est_days=2.0,
    deps="Requires ContextStore and TurnRecord.",
    dep_ids=["E008-F001-S001-T001-A001","E009-F003-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-8"],
    open_questions=["Does CLI support rerun programmatically? If not, guide user to copy prompt and add context manually."],
    files_touched=["Blaze/Sources/App/AppState.swift"],
    new_files=["Blaze/Sources/UI/Rerun/RerunFlowView.swift"],
    data_model_changes=["Store lastUserPrompt and lastContextSnapshot in AppState"],
    ui_states=["Rerun ready","Adding context","Rerun in progress","Rerun completed"],
    ui_interactions=["Click 'Rerun with fixes'","Attach file","Add note","Execute rerun"],
    ui_copy=["Rerun with added context","Attach files","Add note","Rerunning...","Rerun as new turn"],
    telemetry_events=["rerun_started","rerun_context_added","rerun_completed"],
    metrics=[{"name":"rerun_success_rate","type":"gauge","unit":"ratio","target":">=0.8","notes":"Should improve outcomes."}],
    functional=[
        "Last user prompt and context snapshot are stored.",
        "Rerun UI allows attaching additional context items.",
        "Rerun executes as a new turn with merged context.",
        "New turn is clearly labeled as 'Rerun of Turn N'."
    ],
    nonfunctional=["Rerun must not mutate prior turn records; audit history preserved."],
    steps=[
        "Store lastUserPrompt and lastContextSnapshot in AppState on each user message.",
        "Create RerunFlowView with: context picker, file attachment, note addition.",
        "On execute: merge context, trigger new CLI run (or show guided prompt), record new turn."
    ],
    edge_cases=[
        "Last prompt not available (app restarted) → disable rerun button with explanation.",
        "Attached file is very large → warn about token impact before rerun.",
        "CLI not connected → show 'Connect to Claude Code first'."
    ],
    failure_modes=["Rerun uses stale context → always show 'Context to include' review before executing."],
    rollback_plan="If CLI automation not possible, ship as guided checklist only.",
    acceptance_tests=["After error, click rerun, attach file, execute; verify new turn created with updated context."],
    acceptance_criteria=[
        "Rerun flow exists and creates auditable new turn.",
        "Context additions are visible and token-impact shown."
    ],
    dod_criteria=["RerunFlowView implemented.","Turn labeling verified."],
    completed_when="Users can easily retry with corrections.",
    completed_evidence="Screenshot of rerun UI and resulting new turn."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 10 (E011) — Diagnostics & Error UX ----------------
md.append("\n# Phase 10 — Diagnostics & Error UX\n")
atoms_rest += [
make_atom(
    id="E011-F001-S001-T001-A001",
    severity="P1",
    epic_id="E011", feature_id="E011-F001", story_id="E011-F001-S001", task_id="E011-F001-S001-T001",
    epic="Diagnostics & Error UX",
    feature="ErrorCard and WarningCard components",
    story="Failures are shown as clear, actionable cards in chat",
    story_desc="When something fails (parse error, tool failure, permission denial), show a compact card with: what happened, suggested fix, and 'Inspect raw' link to right panel.",
    task="Implement ErrorCard and WarningCard UI components",
    task_desc="Create card components with severity styling (error=red, warning=yellow), summary text, suggestion text, and 'Inspect raw' action.",
    atom="ErrorCard/WarningCard implementation",
    atom_desc="Structured error cards with severity icon, summary, suggestion, expandable details, and inspect raw link.",
    phase="Phase 10", area="UI", risk="medium", priority="must", est_days=2.0,
    deps="Requires right panel raw inspector and Router error mapping.",
    dep_ids=["E003-F005-S001-T001-A001","E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-9","/mnt/data/blaze-chat-ui-polish-spec (1).md#Errors-warnings"],
    open_questions=["Categorize errors (parse/tool/command/MCP)? Yes, show category in subtitle."],
    files_touched=["Blaze/Sources/UI/Cards/"],
    new_files=["Blaze/Sources/UI/Cards/ErrorCard.swift","Blaze/Sources/UI/Cards/WarningCard.swift"],
    ui_states=["Collapsed","Expanded details"],
    ui_interactions=["Expand details","Inspect raw","Copy error summary","Dismiss warning"],
    ui_copy=["What happened","Suggested fix","Inspect raw","Copy","Dismiss"],
    telemetry_events=["error_card_shown","error_card_expanded","error_inspect_clicked"],
    metrics=[{"name":"error_cards_shown","type":"counter","unit":"count","target":"N/A","notes":"Error frequency."},{"name":"error_inspect_rate","type":"gauge","unit":"ratio","target":"N/A","notes":"How often users inspect."}],
    log_expectations=["DEBUG error_card_shown type=<category> eventId=<id>"],
    functional=[
        "Errors render as compact cards with actionable text and do not spam chat.",
        "Cards show severity icon, category, summary, and suggestion.",
        "Inspect raw opens right panel inspector for the originating event.",
        "Cards are expandable for additional details."
    ],
    nonfunctional=["Do not include sensitive payload content in main card; keep in inspector.","Cards must not block chat scrolling."],
    steps=[
        "Create ErrorCard.swift with severity styling, icon, summary, suggestion, expand button, inspect action.",
        "Create WarningCard.swift with similar structure but warning styling.",
        "Add mapping from error RenderIntent to card type in ChatTimelineView.",
        "Wire inspect action to select raw event ID in right panel store."
    ],
    edge_cases=[
        "No raw payload available → disable inspect button and show 'Raw unavailable'.",
        "Multiple errors in one turn → bundle under summary with 'N errors' and expandable list.",
        "Very long error message → truncate with 'Show more'."
    ],
    failure_modes=["Overly noisy errors → implement error noise gate: suppress repeated identical errors."],
    rollback_plan="If cards clutter chat, collapse into single banner linking to right panel diagnostics.",
    acceptance_tests=["Trigger parse error; ErrorCard appears; inspect shows raw payload.","Trigger warning; WarningCard appears and is dismissible."],
    acceptance_criteria=[
        "Errors are visible, clear, and actionable.",
        "Raw payload accessible via right panel.",
        "Cards don't overwhelm chat."
    ],
    dod_criteria=["ErrorCard/WarningCard implemented.","Manual verification with fixture."],
    completed_when="Failures have a human-friendly UI.",
    completed_evidence="Screenshot: ErrorCard in chat + right panel raw inspector."
),
make_atom(
    id="E011-F002-S001-T001-A001",
    severity="P2",
    epic_id="E011", feature_id="E011-F002", story_id="E011-F002-S001", task_id="E011-F002-S001-T001",
    epic="Diagnostics & Error UX",
    feature="Diagnostics bundle export",
    story="Users can export a diagnostics bundle for support",
    story_desc="'Copy diagnostics bundle' action collects last N events, runtimeInfo, TurnRecords, stderr (if captured), and session metadata into a zip file for sharing.",
    task="Implement DiagnosticsExporter and UI action",
    task_desc="Create exporter that gathers diagnostics, writes to temp zip, copies path to clipboard, and optionally redacts sensitive data.",
    atom="Diagnostics bundle exporter",
    atom_desc="Exporter collects artifacts, writes zip atomically, provides clipboard copy and optional redaction.",
    phase="Phase 10", area="Core", risk="medium", priority="should", est_days=2.0,
    deps="Requires runtimeInfo, TurnRecords, and right panel timeline store.",
    dep_ids=["E002-F001-S001-T002-A001","E008-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-9"],
    open_questions=["Zip or folder? Zip for easy sharing.","Auto-redact secrets?"],
    files_touched=["Blaze/Sources/App/AppState.swift"],
    new_files=["Blaze/Sources/Diagnostics/DiagnosticsExporter.swift"],
    data_model_changes=["DiagnosticsBundle model with paths and metadata"],
    ui_states=["Exporting","Export complete","Export failed"],
    ui_interactions=["Click 'Copy diagnostics bundle'","Enable/disable redaction"],
    ui_copy=["Copy diagnostics bundle","Exporting...","Diagnostics saved to...","Enable redaction"],
    telemetry_events=["diagnostics_export_started","diagnostics_export_completed","diagnostics_export_failed"],
    metrics=[{"name":"diagnostics_exports","type":"counter","unit":"count","target":"N/A","notes":"Support usage."}],
    functional=[
        "Exporter collects: last 100 raw events, runtimeInfo, TurnRecords summary, stderr log (if available).",
        "Outputs to .blaze/diagnostics/<timestamp>.zip with atomic write.",
        "Copies path to clipboard; shows success toast.",
        "Optional redaction removes potential secrets (API keys, tokens)."
    ],
    nonfunctional=["Export must not block UI; run async with progress indicator.","Zip should be <10MB for typical sessions."],
    steps=[
        "Create DiagnosticsExporter with async export(redact: Bool) method.",
        "Collect artifacts from AppState stores; write to temp folder.",
        "Compress to zip with atomic temp+rename.",
        "Add redaction pass scanning for API_KEY, TOKEN, PASSWORD patterns."
    ],
    edge_cases=[
        "No events to export → create zip with just runtimeInfo and note.",
        "Very large session → cap events at last 100 with note.",
        "Disk permission error → show ErrorCard with fallback to clipboard JSON."
    ],
    failure_modes=["Exporter blocks UI → ensure fully async.","Zip corrupted → validate after write."],
    rollback_plan="If zip fails, offer 'Copy JSON to clipboard' as fallback.",
    acceptance_tests=["Click export; verify zip created with expected files.","Enable redaction; verify secrets removed."],
    acceptance_criteria=[
        "Diagnostics bundle is easy to create and share.",
        "Bundle contains useful debugging artifacts.",
        "Redaction option works."
    ],
    dod_criteria=["DiagnosticsExporter implemented.","Manual verification."],
    completed_when="Support bundles can be created from UI.",
    completed_evidence="Screenshot of export success + zip contents."
),
make_atom(
    id="E011-F003-S001-T001-A001",
    severity="P2",
    epic_id="E011", feature_id="E011-F003", story_id="E011-F003-S001", task_id="E011-F003-S001-T001",
    epic="Diagnostics & Error UX",
    feature="Right panel diagnostics drill-down",
    story="Right panel provides deep diagnostics view for any error",
    story_desc="Enhanced right panel inspector with: error stack view, related events, and suggested debugging steps.",
    task="Add diagnostics tab to right panel with error detail view",
    task_desc="Create DiagnosticsTabView in right panel showing: selected error details, related events, stack trace (if available), and debugging suggestions.",
    atom="Right panel diagnostics view",
    atom_desc="Tab view with error details, related event links, stack info, and fix suggestions.",
    phase="Phase 10", area="UI", risk="low", priority="should", est_days=1.5,
    deps="Requires right panel and ErrorCard.",
    dep_ids=["E011-F001-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-9"],
    files_touched=["Blaze/Sources/UI/RightPanel/"],
    new_files=["Blaze/Sources/UI/RightPanel/DiagnosticsTabView.swift"],
    ui_states=["No error selected","Error selected","Related events loaded"],
    ui_interactions=["Select error from list","Jump to related event","Copy stack trace"],
    ui_copy=["Diagnostics","Error Details","Related Events","Stack Trace","Suggested Fix"],
    telemetry_events=["diagnostics_tab_opened","diagnostics_error_selected"],
    metrics=[{"name":"diagnostics_tab_usage","type":"counter","unit":"count","target":"N/A","notes":"Debugging tool usage."}],
    functional=[
        "Diagnostics tab shows list of errors/warnings from session.",
        "Selecting an error shows full details, stack trace, and related events.",
        "Suggested fix section provides actionable debugging guidance."
    ],
    nonfunctional=["Tab must handle many errors without lag."],
    steps=[
        "Create DiagnosticsTabView with error list and detail pane.",
        "Implement error-to-related-events linking via event ID ranges.",
        "Add suggested fix templates based on error category."
    ],
    edge_cases=[
        "No errors in session → show 'No errors' with success icon.",
        "Stack trace unavailable → hide section.",
        "Many errors → paginate list."
    ],
    failure_modes=["Related event linking broken → fall back to showing raw error only."],
    rollback_plan="Ship as simple error list without related events if linking is complex.",
    acceptance_tests=["Trigger error; open diagnostics tab; verify error details shown with related events."],
    acceptance_criteria=[
        "Diagnostics tab provides debugging value.",
        "Related events help understand context."
    ],
    dod_criteria=["DiagnosticsTabView implemented.","Manual verification."],
    completed_when="Debugging is easier via right panel.",
    completed_evidence="Screenshot of diagnostics tab with error selected."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 11 (E012) — Todo System UX (NEW) ----------------
md.append("\n# Phase 11 — Todo System UX\n")
atoms_rest += [
make_atom(
    id="E012-F001-S001-T001-A001",
    severity="P1",
    epic_id="E012", feature_id="E012-F001", story_id="E012-F001-S001", task_id="E012-F001-S001-T001",
    epic="Todo System UX",
    feature="Todo store and model",
    story="Claude's TodoWrite events are captured and displayed in structured view",
    story_desc="Parse TodoWrite tool events from the CLI, store todo items with status (pending/in_progress/completed), and provide reactive updates for UI.",
    task="Implement TodoStore with TodoItem model and event integration",
    task_desc="Create TodoStore managing TodoItems; parse TodoWrite events; support status updates, ordering, and linking back to originating events.",
    atom="TodoStore implementation",
    atom_desc="TodoItem model with id, content, activeForm, status, sourceEventId. TodoStore with add/update/remove and reactive publishing.",
    phase="Phase 11", area="Core", risk="low", priority="must", est_days=1.5,
    deps="Requires event parsing from ClaudeEventMapper.",
    dep_ids=["E002-F001-S001-T002-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#TodoWrite","/mnt/data/feature-roadmap.md#Phase-5"],
    open_questions=["How to identify TodoWrite events? Check for tool_use with name='TodoWrite'."],
    files_touched=["Blaze/Sources/Engine/ClaudeEventMapper.swift","Blaze/Sources/App/AppState.swift"],
    new_files=["Blaze/Sources/Todo/TodoStore.swift","Blaze/Sources/Todo/TodoItem.swift"],
    data_model_changes=["TodoItem: id, content, activeForm, status (pending/in_progress/completed), sourceEventId, createdAt, updatedAt"],
    event_contracts=["ClaudeEventMapper emits TodoWriteEvent when TodoWrite tool_use detected."],
    telemetry_events=["todo_item_created","todo_item_updated","todo_item_completed"],
    metrics=[{"name":"todo_items_total","type":"gauge","unit":"items","target":"N/A","notes":"Current count."},{"name":"todo_completion_rate","type":"gauge","unit":"ratio","target":"N/A","notes":"Completed vs total."}],
    log_expectations=["DEBUG todo_item_created id=<id> content=<...>"],
    functional=[
        "TodoWrite events are parsed and stored as TodoItems.",
        "Items have status: pending, in_progress, completed.",
        "Items link back to originating event for provenance.",
        "TodoStore publishes changes reactively."
    ],
    nonfunctional=["Store must handle 100+ items without performance issues."],
    steps=[
        "Create TodoItem model with all fields.",
        "Create TodoStore with add/update/remove and @Published items.",
        "Add TodoWrite event detection in ClaudeEventMapper; create TodoWriteEvent.",
        "Wire TodoWriteEvent to TodoStore updates in Router or AppState."
    ],
    edge_cases=[
        "TodoWrite with empty items array → clear all items.",
        "Duplicate item IDs → update existing item.",
        "Item with missing content → log warning and skip."
    ],
    failure_modes=["TodoWrite parsing fails → log error and continue without updating store."],
    rollback_plan="If parsing is unreliable, show raw TodoWrite in right panel instead of structured view.",
    acceptance_tests=["Replay fixture with TodoWrite events; verify TodoStore has correct items."],
    acceptance_criteria=[
        "TodoWrite events are parsed correctly.",
        "TodoStore reflects current state accurately."
    ],
    dod_criteria=["TodoStore implemented with unit tests.","Event parsing verified."],
    completed_when="Todo items are tracked from CLI events.",
    completed_evidence="Debug view showing TodoStore contents."
),
make_atom(
    id="E012-F002-S001-T001-A001",
    severity="P1",
    epic_id="E012", feature_id="E012-F002", story_id="E012-F002-S001", task_id="E012-F002-S001-T001",
    epic="Todo System UX",
    feature="Todo panel in right sidebar",
    story="Users have a dedicated Todo panel showing current task state",
    story_desc="Right panel includes Todo tab with: sections for Now/Next/Later (or In Progress/Pending/Completed), each item linked to originating message/tool call.",
    task="Implement TodoPanelView in right sidebar",
    task_desc="Create TodoPanelView with: section headers, TodoItemRow with status icon and provenance link, clear completed action.",
    atom="Todo panel UI",
    atom_desc="Right panel tab with grouped todo items, status icons, and navigation to source event.",
    phase="Phase 11", area="UI", risk="low", priority="must", est_days=1.5,
    deps="Requires TodoStore.",
    dep_ids=["E012-F001-S001-T001-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#TodoWrite"],
    files_touched=["Blaze/Sources/UI/RightPanel/RightPanelView.swift"],
    new_files=["Blaze/Sources/UI/RightPanel/TodoPanelView.swift","Blaze/Sources/UI/Components/TodoItemRow.swift"],
    ui_states=["No todos","Has pending todos","Has in_progress todo","All completed"],
    ui_interactions=["Click item to expand","Jump to source event","Clear completed","Collapse section"],
    ui_copy=["Todos","In Progress","Pending","Completed","No todos yet","Clear completed","Jump to source"],
    telemetry_events=["todo_panel_opened","todo_item_clicked","todo_source_jumped"],
    metrics=[{"name":"todo_panel_views","type":"counter","unit":"count","target":"N/A","notes":"Usage."}],
    functional=[
        "Todo panel shows items grouped by status: In Progress, Pending, Completed.",
        "Each item shows content/activeForm based on status.",
        "Clicking item expands details and shows 'Jump to source' action.",
        "'Clear completed' removes completed items from view."
    ],
    nonfunctional=["Panel must handle 50+ items without lag."],
    steps=[
        "Add 'Todos' tab to RightPanelView.",
        "Create TodoPanelView with sections and TodoItemRow components.",
        "Wire 'Jump to source' to select sourceEventId in timeline.",
        "Add 'Clear completed' action (hide in UI, keep in store)."
    ],
    edge_cases=[
        "No todos → show 'No todos yet' with icon.",
        "Very long item content → truncate with expand.",
        "Source event no longer in timeline → show 'Source not available'."
    ],
    failure_modes=["Panel doesn't update when store changes → ensure proper binding."],
    rollback_plan="If panel is unstable, show raw JSON list of todos.",
    acceptance_tests=["View todo panel; see items grouped correctly; click item and jump to source."],
    acceptance_criteria=[
        "Todo panel is accessible in 1 click.",
        "Items are grouped and navigable.",
        "Provenance linking works."
    ],
    dod_criteria=["TodoPanelView implemented.","Manual verification."],
    completed_when="Users have a dedicated todo view.",
    completed_evidence="Screenshot of todo panel with items grouped."
),
make_atom(
    id="E012-F003-S001-T001-A001",
    severity="P2",
    epic_id="E012", feature_id="E012-F003", story_id="E012-F003-S001", task_id="E012-F003-S001-T001",
    epic="Todo System UX",
    feature="Todo update toast in chat",
    story="Todo changes are summarized in chat without spamming",
    story_desc="Instead of showing full todo list in chat, show a compact toast: 'Todo updated: +2 / -1' that links to Todo panel.",
    task="Implement TodoUpdateToast for chat timeline",
    task_desc="Create compact toast card showing todo change summary; clicking opens Todo panel in right sidebar.",
    atom="Todo update toast in chat",
    atom_desc="Compact notification with +added/-removed counts and link to full panel.",
    phase="Phase 11", area="UI", risk="low", priority="should", est_days=1.0,
    deps="Requires TodoStore and TodoPanel.",
    dep_ids=["E012-F001-S001-T001-A001","E012-F002-S001-T001-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#TodoWrite"],
    files_touched=["Blaze/Sources/UI/Chat/ChatTimelineView.swift"],
    new_files=["Blaze/Sources/UI/Cards/TodoUpdateToast.swift"],
    ui_states=["Toast visible","Toast fading"],
    ui_interactions=["Click toast to open Todo panel"],
    ui_copy=["Todo updated: +2 / -1","View todos"],
    telemetry_events=["todo_toast_shown","todo_toast_clicked"],
    metrics=[{"name":"todo_toast_click_rate","type":"gauge","unit":"ratio","target":"N/A","notes":"Engagement."}],
    functional=[
        "TodoWrite events produce toast instead of full todo list in chat.",
        "Toast shows change summary: +N added, -M removed, =P unchanged.",
        "Clicking toast opens Todo panel."
    ],
    nonfunctional=["Toast should be visually distinct but not disruptive."],
    steps=[
        "Create TodoUpdateToast component with summary text and click action.",
        "Router emits toast intent instead of full todo content for chat.",
        "Wire click to open right panel Todo tab."
    ],
    edge_cases=[
        "Only status changes (no add/remove) → show 'Todo updated' without counts.",
        "Many updates in rapid succession → debounce toasts.",
        "Todo panel already open → clicking just ensures tab selected."
    ],
    failure_modes=["Toast spams chat → implement debouncing with 1s window."],
    rollback_plan="If toast is distracting, remove and rely solely on panel badge.",
    acceptance_tests=["TodoWrite event; verify toast appears; click opens panel."],
    acceptance_criteria=[
        "Chat is not spammed with full todo lists.",
        "Toast provides at-a-glance update info."
    ],
    dod_criteria=["TodoUpdateToast implemented.","Debouncing verified."],
    completed_when="Todo updates are non-disruptive.",
    completed_evidence="Screenshot of compact toast in chat."
),
make_atom(
    id="E012-F004-S001-T001-A001",
    severity="P2",
    epic_id="E012", feature_id="E012-F004", story_id="E012-F004-S001", task_id="E012-F004-S001-T001",
    epic="Todo System UX",
    feature="Todo panel badge with pending count",
    story="Right panel tab shows badge with pending todo count",
    story_desc="The Todo tab in right panel shows a badge with the count of non-completed items, making it easy to see at a glance if there are pending tasks.",
    task="Add badge to Todo tab showing pending count",
    task_desc="Right panel Tab for Todos shows badge with count of pending + in_progress items.",
    atom="Todo tab badge",
    atom_desc="Badge component bound to TodoStore filtered count.",
    phase="Phase 11", area="UI", risk="low", priority="should", est_days=0.5,
    deps="Requires TodoPanelView.",
    dep_ids=["E012-F002-S001-T001-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#TodoWrite"],
    files_touched=["Blaze/Sources/UI/RightPanel/RightPanelView.swift"],
    ui_states=["Badge hidden (0)","Badge visible (N)"],
    ui_interactions=["View badge count"],
    ui_copy=["1","2","...","99+"],
    telemetry_events=["N/A"],
    metrics=[{"name":"N/A","type":"none","unit":"N/A","target":"N/A","notes":"N/A"}],
    functional=[
        "Badge shows count of pending + in_progress items.",
        "Badge hidden when count is 0.",
        "Badge updates reactively as TodoStore changes."
    ],
    nonfunctional=["Badge must not cause layout shift."],
    steps=[
        "Add badge overlay to Todo tab in RightPanelView.",
        "Bind badge count to TodoStore.items.filter { $0.status != .completed }.count."
    ],
    edge_cases=[
        "Count > 99 → show '99+'.",
        "All completed → hide badge."
    ],
    failure_modes=["Badge doesn't update → ensure proper @Published binding."],
    rollback_plan="If badge causes layout issues, show count in tab title instead.",
    acceptance_tests=["Add pending item; badge shows 1.","Complete item; badge hides."],
    acceptance_criteria=[
        "Badge accurately reflects pending count.",
        "Badge is visually clear."
    ],
    dod_criteria=["Badge implemented.","Manual verification."],
    completed_when="Users can see pending todo count at a glance.",
    completed_evidence="Screenshot of tab with badge."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 12 (E013) — Polish Pass + Release Readiness ----------------
md.append("\n# Phase 12 — Polish Pass + Release Readiness\n")
atoms_rest += [
make_atom(
    id="E013-F001-S001-T001-A001",
    severity="P2",
    epic_id="E013", feature_id="E013-F001", story_id="E013-F001-S001", task_id="E013-F001-S001-T001",
    epic="Polish Pass + Release Readiness",
    feature="Motion and feedback polish",
    story="UI feels premium with consistent hover/pressed states and smooth animations",
    story_desc="Apply consistent interaction feedback (hover, pressed, selected) across all cards/buttons. Add smooth expand/collapse animations without heavy dependencies.",
    task="Implement CardStyle and ButtonStyle modifiers with animations",
    task_desc="Create shared style modifiers; apply across all cards/buttons; add expand/collapse with easeInOut; respect Reduced Motion setting.",
    atom="Interaction polish implementation",
    atom_desc="Shared CardStyle, PrimaryButtonStyle with hover/pressed states; expand/collapse animations; Reduced Motion support.",
    phase="Phase 12", area="UX", risk="low", priority="should", est_days=2.0,
    deps="Requires existing card implementations.",
    dep_ids=["E004-F002-S001-T001-A001","E006-F001-S001-T001-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#Motion-+-feedback","/mnt/data/feature-roadmap.md#Phase-10"],
    open_questions=["Use spring or easeInOut? EaseInOut per spec."],
    files_touched=["Blaze/Sources/UI/Styles/","Blaze/Sources/UI/Cards/"],
    new_files=["Blaze/Sources/UI/Styles/CardStyle.swift","Blaze/Sources/UI/Styles/BlazeButtonStyle.swift"],
    ui_states=["Default","Hover","Pressed","Expanded"],
    ui_interactions=["Hover","Press","Expand/collapse"],
    ui_copy=["N/A"],
    telemetry_events=["N/A"],
    metrics=[{"name":"N/A","type":"none","unit":"N/A","target":"N/A","notes":"Polish only."}],
    functional=[
        "All cards have consistent hover highlight and pressed state.",
        "Expand/collapse animations are smooth (0.15s easeInOut).",
        "Reduced Motion accessibility setting disables animations."
    ],
    nonfunctional=["Avoid spring chaos; use subtle, predictable easing.","No heavy animation libraries."],
    steps=[
        "Create CardStyle ViewModifier with @Environment(\\.isHovered) and pressed state styling.",
        "Create BlazeButtonStyle with hover glow and pressed feedback.",
        "Apply styles across all existing cards/buttons.",
        "Add expand/collapse animation with .animation(.easeInOut(duration: 0.15)).",
        "Check for Reduced Motion with UIAccessibility/NSAccessibility."
    ],
    edge_cases=[
        "Rapid expand/collapse during streaming → stabilize with view identity.",
        "Many cards expanding simultaneously → stagger if needed.",
        "Reduced Motion enabled → skip all animations."
    ],
    failure_modes=["Animations cause re-render storms → measure with Instruments; simplify if needed."],
    rollback_plan="If animations cause issues in long sessions, disable and keep only static hover states.",
    acceptance_tests=["Hover over card; see highlight.","Expand/collapse; animation is smooth.","Enable Reduced Motion; no animations."],
    acceptance_criteria=[
        "UI feels responsive and premium.",
        "No animation-induced glitches."
    ],
    dod_criteria=["Styles implemented and applied.","Accessibility verified."],
    completed_when="Polish feels complete.",
    completed_evidence="Screen recording showing hover + expand/collapse smoothness."
),
make_atom(
    id="E013-F002-S001-T001-A001",
    severity="P2",
    epic_id="E013", feature_id="E013-F002", story_id="E013-F002-S001", task_id="E013-F002-S001-T001",
    epic="Polish Pass + Release Readiness",
    feature="Keyboard shortcuts system",
    story="Power users can navigate with keyboard shortcuts",
    story_desc="Add keyboard shortcuts for common actions: toggle terminal (⌘J), toggle right panel (⌘⇧K), undo last turn (⌘Z with confirmation).",
    task="Implement Commands menu with keyboard shortcuts",
    task_desc="Create BlazeCommands using SwiftUI Commands; define shortcuts; wire to AppState actions; document shortcuts.",
    atom="Keyboard shortcuts implementation",
    atom_desc="Commands menu with shortcuts for panel toggles, undo, search focus.",
    phase="Phase 12", area="UX", risk="low", priority="should", est_days=2.0,
    deps="Requires panel toggles and undo engine.",
    dep_ids=["E003-F005-S001-T001-A001","E006-F003-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-10"],
    open_questions=["Command palette now or later? Later."],
    files_touched=["Blaze/Sources/App/BlazeApp.swift"],
    new_files=["Blaze/Sources/App/Commands/BlazeCommands.swift"],
    ui_states=["N/A"],
    ui_interactions=["Press ⌘J","Press ⌘⇧K","Press ⌘Z"],
    ui_copy=["Toggle Terminal","Toggle Right Panel","Undo Last Turn"],
    telemetry_events=["shortcut_used"],
    metrics=[{"name":"shortcut_usage","type":"counter","unit":"count","target":"N/A","notes":"Shortcut adoption."}],
    functional=[
        "⌘J toggles terminal visibility.",
        "⌘⇧K toggles right panel visibility.",
        "⌘Z triggers undo with confirmation (same as button).",
        "Shortcuts visible in menu."
    ],
    nonfunctional=["Shortcuts must not conflict with system defaults."],
    steps=[
        "Create BlazeCommands using SwiftUI Commands.",
        "Define CommandGroup for Navigation with panel toggles.",
        "Define CommandGroup for Edit with Undo Last Turn (gated by confirmation).",
        "Wire commands to AppState flags."
    ],
    edge_cases=[
        "Focus in text field → shortcuts may not trigger; use Commands to ensure global.",
        "Undo triggered twice rapidly → gate with confirmation and disable during undo."
    ],
    failure_modes=["Shortcut bypasses safety confirmation → enforce gate in engine."],
    rollback_plan="If conflicts occur, ship menu items without shortcuts.",
    acceptance_tests=["Press ⌘J; terminal toggles.","Press ⌘Z; confirmation appears."],
    acceptance_criteria=[
        "Shortcuts work reliably.",
        "Safety gates enforced."
    ],
    dod_criteria=["BlazeCommands implemented.","Manual verification."],
    completed_when="Power users can navigate efficiently.",
    completed_evidence="Screen recording using shortcuts."
),
make_atom(
    id="E013-F003-S001-T001-A001",
    severity="P1",
    epic_id="E013", feature_id="E013-F003", story_id="E013-F003-S001", task_id="E013-F003-S001-T001",
    epic="Polish Pass + Release Readiness",
    feature="Performance audit and optimization",
    story="Long sessions remain fast and smooth",
    story_desc="Profile with Instruments; identify hotspots in Router, terminal output, and timeline list; implement virtualization and throttling.",
    task="Run performance audit and fix top hotspots",
    task_desc="Use Instruments to profile; ensure LazyVStack usage; add throttling for streaming updates; cap displayed items with 'Load more'.",
    atom="Performance audit and fixes",
    atom_desc="Profiling, virtualization verification, throttling for streaming, capped lists with load more.",
    phase="Phase 12", area="Infra", risk="medium", priority="must", est_days=2.5,
    deps="Requires core UI components.",
    dep_ids=["E003-F005-S001-T001-A001"],
    source_refs=["/mnt/data/feature-roadmap.md#Phase-10"],
    open_questions=["Cap right panel events at 500 with Load more?"],
    telemetry_events=["perf_audit_completed"],
    metrics=[{"name":"ui_frame_drops","type":"gauge","unit":"count","target":"0","notes":"Subjective + Instruments."},{"name":"timeline_render_ms","type":"histogram","unit":"ms","target":"<16","notes":"Frame budget."}],
    functional=[
        "Long sessions (1000+ events) scroll smoothly.",
        "Streaming updates don't cause UI freezes.",
        "Lists are virtualized with caps and 'Load more'."
    ],
    nonfunctional=["Throttle Router intent emissions to 50ms batches.","Never drop events; caps are display-only."],
    steps=[
        "Profile with Instruments during long replay session.",
        "Ensure all long lists use LazyVStack.",
        "Add throttling to TerminalStore and Router publishing (50ms batches).",
        "Cap timeline to last 500 events with 'Load more' button."
    ],
    edge_cases=[
        "Very large terminal output → ring buffer with virtualized line rendering.",
        "User scrolls to top during streaming → pause scroll-follow.",
        "'Load more' fails → show error and retry."
    ],
    failure_modes=["Capping drops events from storage → only cap display; keep storage intact."],
    rollback_plan="If virtualization regressions appear, revert to previous list rendering.",
    acceptance_tests=["Replay 2000-event session; scroll remains smooth.","CPU reasonable."],
    acceptance_criteria=[
        "App responsive in long sessions.",
        "No event loss."
    ],
    dod_criteria=["Audit completed; hotspots fixed.","Manual long-session test passes."],
    completed_when="Performance is production-ready.",
    completed_evidence="Instruments screenshot + manual test notes."
),
make_atom(
    id="E013-F004-S001-T001-A001",
    severity="P1",
    epic_id="E013", feature_id="E013-F004", story_id="E013-F004-S001", task_id="E013-F004-S001-T001",
    epic="Polish Pass + Release Readiness",
    feature="Release build and signing verification",
    story="App builds, signs, and notarizes correctly for distribution",
    story_desc="Verify Developer ID signing, notarization workflow, DMG creation, and update check mechanism.",
    task="Verify release build pipeline",
    task_desc="Run full release build; verify signing with codesign; submit for notarization; create DMG; test fresh install.",
    atom="Release pipeline verification",
    atom_desc="Full build → sign → notarize → DMG → install test cycle.",
    phase="Phase 12", area="Infra", risk="high", priority="must", est_days=2.0,
    deps="Requires app feature-complete.",
    dep_ids=[],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#Distribution"],
    open_questions=["Auto-update mechanism? Sparkle or manual for v1."],
    files_touched=["Build settings","Scripts/build-release.sh"],
    new_files=["Scripts/notarize.sh"],
    telemetry_events=["release_build_completed"],
    metrics=[{"name":"notarization_failures","type":"counter","unit":"count","target":"0","notes":"Must be 0 for release."}],
    functional=[
        "Release build compiles without warnings.",
        "Signing with Developer ID certificate succeeds.",
        "Notarization succeeds with Apple.",
        "DMG installs cleanly on fresh Mac."
    ],
    nonfunctional=["Build must be reproducible (same commit → same binary hash after signing)."],
    steps=[
        "Create build-release.sh script: clean → archive → export.",
        "Create notarize.sh: submit → wait → staple.",
        "Create DMG with create-dmg or custom script.",
        "Test install on clean macOS VM or fresh user account."
    ],
    edge_cases=[
        "Notarization fails due to code issues → fix and re-submit.",
        "Certificate expired → renew and update pipeline.",
        "Gatekeeper blocks after install → investigate signing."
    ],
    failure_modes=["Notarization timeout → add retry logic with exponential backoff."],
    rollback_plan="If notarization consistently fails, ship as signed-only for testing; fix before public release.",
    acceptance_tests=["Run full pipeline; install DMG on test machine; app launches."],
    acceptance_criteria=[
        "Release pipeline produces installable DMG.",
        "App passes Gatekeeper on first launch."
    ],
    dod_criteria=["Pipeline scripts created.","Full cycle tested."],
    completed_when="App is ready for distribution.",
    completed_evidence="Screenshot of successful notarization + DMG install."
),
make_atom(
    id="E013-F005-S001-T001-A001",
    severity="P2",
    epic_id="E013", feature_id="E013-F005", story_id="E013-F005-S001", task_id="E013-F005-S001-T001",
    epic="Polish Pass + Release Readiness",
    feature="Release documentation and changelog",
    story="Release includes user-facing documentation and changelog",
    story_desc="Prepare CHANGELOG.md, user documentation (Getting Started, Features), and in-app help/about screen.",
    task="Write release documentation and implement About screen",
    task_desc="Create CHANGELOG.md from git history; write Getting Started doc; implement About screen with version, links.",
    atom="Release documentation",
    atom_desc="CHANGELOG, docs, About screen with version and support links.",
    phase="Phase 12", area="Docs", risk="low", priority="should", est_days=1.5,
    deps="Requires feature completion.",
    dep_ids=[],
    source_refs=["/mnt/data/feature-roadmap.md"],
    files_touched=["CHANGELOG.md","README.md"],
    new_files=["Blaze/Sources/UI/About/AboutView.swift","docs/getting-started.md"],
    ui_states=["About screen open"],
    ui_interactions=["Open About","Copy version","Open support link"],
    ui_copy=["About Blaze","Version","Check for updates","Report issue","Documentation"],
    telemetry_events=["about_opened"],
    metrics=[{"name":"about_views","type":"counter","unit":"count","target":"N/A","notes":"Usage."}],
    functional=[
        "CHANGELOG documents all significant changes.",
        "Getting Started doc helps new users.",
        "About screen shows version, links to docs and support."
    ],
    nonfunctional=["Docs must be up-to-date with shipped features."],
    steps=[
        "Generate CHANGELOG from git log, organized by version.",
        "Write getting-started.md with installation and first-use instructions.",
        "Implement AboutView with app version, build info, and links.",
        "Add About to app menu."
    ],
    edge_cases=[
        "Version string empty → show 'Development build'.",
        "Support link unreachable → open system browser; link may fail later."
    ],
    failure_modes=["Docs out of sync with features → review docs in release checklist."],
    rollback_plan="Ship with minimal docs; expand post-release.",
    acceptance_tests=["Open About; see correct version.","Open Getting Started; verify accuracy."],
    acceptance_criteria=[
        "Documentation exists and is accurate.",
        "About screen is accessible and informative."
    ],
    dod_criteria=["Docs written.","About implemented."],
    completed_when="Release is documented.",
    completed_evidence="Screenshot of About screen + CHANGELOG excerpt."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# ---------------- Phase 13 (E016-E018) ----------------
md.append("\n# Phase 13 — Missing UI Components\n")
atoms_rest += [
make_atom(
    id="E016-F001-S001-T001-A001",
    severity="P1",
    epic_id="E016", feature_id="E016-F001", story_id="E016-F001-S001", task_id="E016-F001-S001-T001",
    epic="File Snippet Cards",
    feature="FileSnippetCard component",
    story="File reads are shown as compact, actionable cards in chat",
    story_desc="When Claude reads a file, show a FileSnippetCard with path, line range, short excerpt, and Open/Copy/Pin actions. Full content goes to right panel.",
    task="Implement FileSnippetCard UI component",
    task_desc="Create FileSnippetCard with path display, line range badge, excerpt preview (5-10 lines max), and action buttons (Open in editor, Copy path, Pin to context).",
    atom="FileSnippetCard implementation",
    atom_desc="Compact card showing file path, line range, and excerpt. Actions: Open, Copy, Pin. Expand shows more; right panel shows full file.",
    phase="Phase 13", area="UI", risk="low", priority="must", est_days=2.0,
    deps="Requires RenderIntent routing for Read tool events.",
    dep_ids=["E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#E-File-reads"],
    open_questions=["Max excerpt lines in collapsed state? 5 lines.","Show syntax highlighting in excerpt? Yes if <100 lines."],
    files_touched=["Blaze/Sources/UI/ChatTimelineView.swift"],
    new_files=["Blaze/Sources/UI/Cards/FileSnippetCard.swift"],
    data_model_changes=["FileSnippet model with: path, startLine, endLine, content, language"],
    ui_states=["Collapsed (5 lines)","Expanded (full excerpt)","Loading"],
    ui_interactions=["Expand/collapse","Open in editor","Copy path","Pin to context"],
    ui_copy=["Open","Copy Path","Pin","lines"],
    telemetry_events=["file_snippet_expanded","file_snippet_opened","file_snippet_pinned"],
    metrics=[{"name":"file_snippet_opens","type":"counter","unit":"count","target":"N/A","notes":"File open usage."}],
    functional=[
        "FileSnippetCard displays file path, line range badge, and syntax-highlighted excerpt.",
        "Collapse shows 5 lines max; expand shows full excerpt.",
        "Open action launches file in system editor at specified line.",
        "Copy Path copies absolute path to clipboard.",
        "Pin adds file to context sidebar."
    ],
    nonfunctional=["Syntax highlighting must not block UI; use async if large.","Excerpt must render quickly even for large files."],
    steps=[
        "Create FileSnippet model with path, lineRange, content, language detection.",
        "Create FileSnippetCard view with header (path, line badge), excerpt view, and action buttons.",
        "Wire Open action to NSWorkspace.open with line number URL scheme if supported.",
        "Wire Copy Path to pasteboard.",
        "Wire Pin to ContextStore.addItem()."
    ],
    edge_cases=[
        "Binary file → show 'Binary file' placeholder, no excerpt.",
        "File deleted since read → show warning badge.",
        "Very long path → truncate middle with ellipsis.",
        "Language unknown → render as plain text."
    ],
    failure_modes=["Open fails (no editor association) → show error toast with path."],
    rollback_plan="If syntax highlighting causes issues, ship with plain text excerpts.",
    acceptance_tests=["Read file; card shows path and excerpt.","Click Open; file opens in editor.","Click Pin; file appears in context sidebar."],
    acceptance_criteria=[
        "File reads appear as compact cards with actionable buttons.",
        "Excerpts are syntax-highlighted and expandable."
    ],
    dod_criteria=["FileSnippetCard implemented.","Actions verified working."],
    completed_when="File reads are first-class UI citizens.",
    completed_evidence="Screenshot of FileSnippetCard with syntax highlighting and actions."
),
make_atom(
    id="E017-F001-S001-T001-A001",
    severity="P1",
    epic_id="E017", feature_id="E017-F001", story_id="E017-F001-S001", task_id="E017-F001-S001-T001",
    epic="Web Results Cards",
    feature="WebResultsCard component",
    story="WebSearch and WebFetch results are shown as organized results cards",
    story_desc="When Claude searches the web or fetches a URL, show a WebResultsCard with 3-5 bullet summary, source list with clickable links, and actions to open sources or view raw extraction.",
    task="Implement WebResultsCard UI component",
    task_desc="Create WebResultsCard with summary bullets, source links (favicon + title + URL), and action buttons (Open All Sources, View Raw Extraction).",
    atom="WebResultsCard implementation",
    atom_desc="Card showing web search/fetch results with summary, sources, and actions. Sources open in browser; raw extraction shows in right panel.",
    phase="Phase 13", area="UI", risk="low", priority="must", est_days=2.0,
    deps="Requires RenderIntent routing for WebSearch/WebFetch events.",
    dep_ids=["E003-F002-S001-T001-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#I-WebSearch-WebFetch"],
    open_questions=["Show favicons? Yes if available, fallback to domain icon.","Max sources shown? 5 collapsed, all on expand."],
    files_touched=["Blaze/Sources/UI/ChatTimelineView.swift"],
    new_files=["Blaze/Sources/UI/Cards/WebResultsCard.swift"],
    data_model_changes=["WebResult model with: query, summary, sources[]{title, url, snippet}"],
    ui_states=["Collapsed (3 sources)","Expanded (all sources)"],
    ui_interactions=["Click source link","Open All Sources","View Extraction","Expand/collapse"],
    ui_copy=["Sources","Open All","View Raw","from"],
    telemetry_events=["web_source_clicked","web_results_expanded","web_extraction_viewed"],
    metrics=[{"name":"web_source_clicks","type":"counter","unit":"count","target":"N/A","notes":"Link usage."}],
    functional=[
        "WebResultsCard displays query, 3-5 bullet summary, and source links.",
        "Each source shows title (clickable), domain, and optional snippet.",
        "Open All Sources opens all links in browser tabs.",
        "View Raw Extraction opens raw content in right panel inspector."
    ],
    nonfunctional=["Links must open quickly; no blocking UI.","Favicon loading must not delay card render."],
    steps=[
        "Create WebResult model with query, summary bullets, and sources array.",
        "Create WebResultsCard view with header (query), summary list, and sources list.",
        "Implement source row with favicon, title link, and domain label.",
        "Wire source click to NSWorkspace.open(url).",
        "Wire Open All to batch-open sources.",
        "Wire View Raw to right panel raw inspector."
    ],
    edge_cases=[
        "No results → show 'No results found' placeholder.",
        "Source URL invalid → show warning and disable click.",
        "Very long title → truncate with ellipsis.",
        "Favicon fails to load → show generic web icon."
    ],
    failure_modes=["Browser fails to open → show error toast."],
    rollback_plan="If favicons cause issues, ship with domain text only.",
    acceptance_tests=["WebSearch; card shows summary and sources.","Click source; browser opens.","Click Open All; all sources open."],
    acceptance_criteria=[
        "Web results are organized and actionable.",
        "Sources are easy to review and open."
    ],
    dod_criteria=["WebResultsCard implemented.","Actions verified working."],
    completed_when="Web results are first-class UI citizens.",
    completed_evidence="Screenshot of WebResultsCard with sources and actions."
),
make_atom(
    id="E018-F001-S001-T001-A001",
    severity="P2",
    epic_id="E018", feature_id="E018-F001", story_id="E018-F001-S001", task_id="E018-F001-S001-T001",
    epic="Streaming Indicators",
    feature="StreamingIndicator component",
    story="Users know when Claude is actively generating a response",
    story_desc="Show a subtle 'Now writing...' indicator with shimmer animation while Claude is streaming a response. Must be non-intrusive and disappear immediately when streaming stops.",
    task="Implement StreamingIndicator UI component",
    task_desc="Create StreamingIndicator with animated ellipsis or shimmer effect. Display in chat timeline during active streaming. Respect Reduced Motion accessibility setting.",
    atom="StreamingIndicator implementation",
    atom_desc="Subtle animated indicator shown during streaming. Shimmer or ellipsis animation. Respects Reduced Motion.",
    phase="Phase 13", area="UI", risk="low", priority="should", est_days=1.0,
    deps="Requires streaming state from AppState.isProcessing.",
    dep_ids=["E003-F001-S001-T001-A001"],
    source_refs=["/mnt/data/blaze-chat-ui-polish-spec (1).md#Streaming-indicator"],
    open_questions=["Shimmer or ellipsis? Shimmer for polish; ellipsis for simplicity. Start with ellipsis."],
    files_touched=["Blaze/Sources/UI/ChatTimelineView.swift"],
    new_files=["Blaze/Sources/UI/Components/StreamingIndicator.swift"],
    data_model_changes=[],
    ui_states=["Streaming active","Streaming stopped"],
    ui_interactions=["N/A (passive indicator)"],
    ui_copy=["Now writing...","Thinking..."],
    telemetry_events=["N/A"],
    metrics=[{"name":"N/A","type":"none","unit":"N/A","target":"N/A","notes":"Passive indicator."}],
    functional=[
        "StreamingIndicator appears at bottom of chat during active streaming.",
        "Animated ellipsis (or shimmer) provides visual feedback.",
        "Indicator disappears immediately when streaming stops.",
        "Respects Reduced Motion: static text only if enabled."
    ],
    nonfunctional=["Animation must not cause CPU spikes.","Transition must be instant (no fade delay on stop)."],
    steps=[
        "Create StreamingIndicator view with animated ellipsis (3 dots cycling).",
        "Bind visibility to AppState.isProcessing.",
        "Check @Environment(\\.accessibilityReduceMotion) and disable animation if true.",
        "Add to ChatTimelineView at scroll-bottom position."
    ],
    edge_cases=[
        "Rapid start/stop streaming → no flicker (debounce if needed).",
        "Very long streaming → indicator stays visible without timeout.",
        "Reduced Motion enabled → show static 'Thinking...' text."
    ],
    failure_modes=["Animation causes memory leak → use @State and simple withAnimation."],
    rollback_plan="If animation issues, ship with static 'Writing...' text.",
    acceptance_tests=["Send message; indicator appears while streaming.","Streaming stops; indicator disappears immediately.","Enable Reduced Motion; no animation."],
    acceptance_criteria=[
        "Users can see when Claude is actively working.",
        "Indicator is subtle and non-intrusive."
    ],
    dod_criteria=["StreamingIndicator implemented.","Reduced Motion verified."],
    completed_when="Streaming state is visually clear.",
    completed_evidence="Screen recording showing indicator during streaming."
)
]
for a in atoms_rest:
    md.append(atom_block(a)); md.append("\n")
atoms_rest = []

# Add explicit "Feature Tradeoffs" section adapted from original roadmap
md.append("\n---\n")
md.append("## Feature tradeoffs (explicit 'no' for now)\n")
md.append("- Full interactive AskUserQuestion round-trips that require SDK-only streaming semantics.\n")
md.append("- Dynamic per-tool permissioning (SDK-only `canUseTool` style).\n")
md.append("- Fork/resume-at-message and rich session forking controls (SDK-only).\n")
md.append("\n---\n")
md.append("## Final notes\n")
md.append("- Keep chat narrative-first; right panel is for detail.\n")
md.append("- Prefer deterministic behavior (replayability) over fancy UI.\n")
md.append("- Always implement safety gates (PromptPolicy + confirmations) before destructive actions.\n")

content = "\n".join(md)

out_path = Path("/mnt/data/feature-roadmap2.md")
out_path.write_text(content, encoding="utf-8")
str(out_path), len(content.splitlines()), out_path.stat().st_size
