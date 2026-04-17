# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Code plugin** - a collection of production-ready agents, skills, hooks, commands, rules, and MCP configurations. The project provides battle-tested workflows for software development using Claude Code.

## Core Project Rules & Anti-Deception Policies

- **Core Algorithm Safeguards:** Before modifying any core algorithmic logic, you MUST invoke the testing agent (e.g., `@tdd-guide`) to run existing unit tests. Refactoring foundational algorithms without test coverage is strictly prohibited.
- **Naming & Documentation:** All new or modified functions must strictly use `snake_case`. Each function must include detailed **English comments (docstrings)** at the header that strictly comply with the **Google Style Guide**. You must clearly define input parameters (Args), output results (Returns/Yields), and any memory/edge-case handling logic.
- **Execution & OS Awareness:** You are operating in a **Windows** environment (e.g., PowerShell). Do NOT use Linux-specific Bash commands. Before executing any system-level commands, you must pause and request explicit user confirmation.
- **Anti-Deception & Write Verification:** Never claim to have modified, updated, or written code if you only performed read/search operations. You must explicitly verify that the file-writing process was actually executed and saved to the disk. Do not hallucinate task completions; if a write operation fails or is skipped, you must report it honestly.

## Medical Imaging Development Rules (Project-Specific)

When working with BrachyPlan or any medical imaging module in this repository:

1. **Context-Aware Analysis:** Always read the full context of the code before making changes. Understand the systemic impact of any modification to avoid unintended side effects.

2. **Official Documentation First:** Before modifying any code, consult official documentation (3D Slicer API, nnU-Net v2 docs, etc.) to verify that functions, methods, and attributes are correct. Do not assume or fabricate API details.

3. **Plan Before Action:** Always create a detailed, feasible plan before modifying any code. The plan must include the rationale, specific changes, and verification steps.

## Code Modification Workflow

- **Build Directory Priority:** When modifying code, always edit the version in the build directory first (`c:\Zhiyaun\r\Slicer-build\...`). Sync to source directory only upon explicit user request.
- **Comments in English:** All code comments must be written in English, regardless of the user's language preference.
- **Sync When Requested:** Do NOT automatically sync changes to source directories. Wait for the user to explicitly request synchronization.

## Running Tests

```bash
# Run all tests
node tests/run-all.js

# Run individual test files
node tests/lib/utils.test.js
node tests/lib/package-manager.test.js
node tests/hooks/hooks.test.js
```

## Architecture

The project is organized into several core components:

- **agents/** - Specialized subagents for delegation (planner, code-reviewer, tdd-guide, etc.)
- **skills/** - Workflow definitions and domain knowledge (coding standards, patterns, testing)
- **commands/** - Slash commands invoked by users (/tdd, /plan, /e2e, etc.)
- **hooks/** - Trigger-based automations (session persistence, pre/post-tool hooks)
- **rules/** - Always-follow guidelines (security, coding style, testing requirements)
- **mcp-configs/** - MCP server configurations for external integrations
- **scripts/** - Cross-platform Node.js utilities for hooks and setup
- **tests/** - Test suite for scripts and utilities

## Key Commands

- `/tdd` - Test-driven development workflow
- `/plan` - Implementation planning
- `/e2e` - Generate and run E2E tests
- `/code-review` - Quality review
- `/build-fix` - Fix build errors
- `/learn` - Extract patterns from sessions
- `/skill-create` - Generate skills from git history

## Development Notes

- Package manager detection: npm, pnpm, yarn, bun (configurable via `CLAUDE_PACKAGE_MANAGER` env var or project config)
- Cross-platform: Windows, macOS, Linux support via Node.js scripts
- Agent format: Markdown with YAML frontmatter (name, description, tools, model)
- Skill format: Markdown with clear sections for when to use, how it works, examples
- Skill placement: Curated in skills/; generated/imported under ~/.claude/skills/. See docs/SKILL-PLACEMENT-POLICY.md
- Hook format: JSON with matcher conditions and command/notification hooks

## Contributing

Follow the formats in CONTRIBUTING.md:
- Agents: Markdown with frontmatter (name, description, tools, model)
- Skills: Clear sections (When to Use, How It Works, Examples)
- Commands: Markdown with description frontmatter
- Hooks: JSON with matcher and hooks array

File naming: lowercase with hyphens (e.g., `python-reviewer.md`, `tdd-workflow.md`)

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `README.md` | `/readme` |
| `.github/workflows/*.yml` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
