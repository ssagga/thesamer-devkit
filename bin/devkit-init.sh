#!/usr/bin/env bash
# devkit-init.sh — scaffold the agent-dev system into a target repo.
# Usage: devkit-init.sh [options] [TARGET_DIR]
# See --help for details.
set -euo pipefail

# ---------------------------------------------------------------------------
# Self-locate the kit root (script lives at <kit>/bin/devkit-init.sh)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DRY_RUN=false
FORCE=false
INTEGRATION_BRANCH="main"
NO_GIT=false
TARGET_DIR=""

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
COUNT_CREATED=0
COUNT_SKIPPED=0
COUNT_WOULD_CREATE=0

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
info()    { printf '[INFO]  %s\n' "$*"; }
warn()    { printf '[WARN]  %s\n' "$*" >&2; }
note()    { printf '[NOTE]  %s\n' "$*"; }
ok()      { printf '[OK]    %s\n' "$*"; }
dry()     { printf '[DRY]   %s\n' "$*"; }
err()     { printf '[ERROR] %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: devkit-init.sh [options] [TARGET_DIR]

Scaffold the agent-dev system (CLAUDE.md, docs/, .claude/, .github/) into a
target repository. TARGET_DIR defaults to the current working directory.

Options:
  -h, --help                Print this help and exit.
  --dry-run                 Print intended actions; write NOTHING.
  --force                   Overwrite existing files (default: skip with warning).
  --integration-branch NAME Integration branch name (default: main).
  --no-git                  Skip all git-related guidance.

EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage; exit 0 ;;
    --dry-run)
      DRY_RUN=true; shift ;;
    --force)
      FORCE=true; shift ;;
    --integration-branch)
      [[ $# -ge 2 ]] || { err "--integration-branch requires a NAME argument"; usage; exit 1; }
      INTEGRATION_BRANCH="$2"; shift 2 ;;
    --no-git)
      NO_GIT=true; shift ;;
    -*)
      err "Unknown option: $1"; usage; exit 1 ;;
    *)
      if [[ -z "${TARGET_DIR}" ]]; then
        TARGET_DIR="$1"; shift
      else
        err "Unexpected argument: $1"; usage; exit 1
      fi ;;
  esac
done

TARGET_DIR="${TARGET_DIR:-${PWD}}"
TARGET_DIR="$(cd "${TARGET_DIR}" && pwd)"  # canonicalize

PROJECT_NAME="$(basename "${TARGET_DIR}")"
TODAY="$(date +%F)"

info "Kit root  : ${KIT_ROOT}"
info "Target    : ${TARGET_DIR}"
info "Project   : ${PROJECT_NAME}"
info "Branch    : ${INTEGRATION_BRANCH}"
info "Dry-run   : ${DRY_RUN}"
info "Force     : ${FORCE}"
echo ""

# ---------------------------------------------------------------------------
# copy_file <src> <dst>
#   Honours --dry-run and --force; updates counters.
# ---------------------------------------------------------------------------
copy_file() {
  local src="$1"
  local dst="$2"

  if [[ "${DRY_RUN}" == true ]]; then
    dry "Would create: ${dst}"
    COUNT_WOULD_CREATE=$(( COUNT_WOULD_CREATE + 1 ))
    return
  fi

  if [[ -e "${dst}" && "${FORCE}" == false ]]; then
    warn "Skipping (exists): ${dst}"
    COUNT_SKIPPED=$(( COUNT_SKIPPED + 1 ))
    return
  fi

  mkdir -p "$(dirname "${dst}")"
  cp "${src}" "${dst}"
  ok "Created: ${dst}"
  COUNT_CREATED=$(( COUNT_CREATED + 1 ))
}

# ---------------------------------------------------------------------------
# write_file <dst> <content-via-stdin>
#   Writes a generated (in-memory) file; same dry-run/force logic.
# ---------------------------------------------------------------------------
write_file() {
  local dst="$1"
  local content
  content="$(cat)"   # read from stdin

  if [[ "${DRY_RUN}" == true ]]; then
    dry "Would create: ${dst}"
    COUNT_WOULD_CREATE=$(( COUNT_WOULD_CREATE + 1 ))
    return
  fi

  if [[ -e "${dst}" && "${FORCE}" == false ]]; then
    warn "Skipping (exists): ${dst}"
    COUNT_SKIPPED=$(( COUNT_SKIPPED + 1 ))
    return
  fi

  mkdir -p "$(dirname "${dst}")"
  printf '%s\n' "${content}" > "${dst}"
  ok "Created: ${dst}"
  COUNT_CREATED=$(( COUNT_CREATED + 1 ))
}

# ---------------------------------------------------------------------------
# Stack detection
# ---------------------------------------------------------------------------
STACK_LANG=""
STACK_FRAMEWORK=""
STACK_PKG_MANAGER=""
STACK_INSTALL_CMD=""
STACK_DEV_CMD=""
STACK_BUILD_CMD=""
STACK_TEST_CMD=""
STACK_STORE="none"
STACK_DEPLOY=""

detect_stack() {
  local t="${TARGET_DIR}"

  # Node / JavaScript / TypeScript
  if [[ -f "${t}/package.json" ]]; then
    STACK_LANG="TypeScript/JavaScript"

    # Package manager from lockfile
    if [[ -f "${t}/pnpm-lock.yaml" ]]; then
      STACK_PKG_MANAGER="pnpm"
    elif [[ -f "${t}/yarn.lock" ]]; then
      STACK_PKG_MANAGER="yarn"
    else
      STACK_PKG_MANAGER="npm"
    fi

    # Framework hints (grep without -P for portability)
    if grep -q '"next"' "${t}/package.json" 2>/dev/null; then
      STACK_FRAMEWORK="Next.js"
    elif grep -q '"vite"' "${t}/package.json" 2>/dev/null; then
      STACK_FRAMEWORK="Vite"
    elif grep -q '"svelte"' "${t}/package.json" 2>/dev/null; then
      STACK_FRAMEWORK="Svelte"
    elif grep -q '"react"' "${t}/package.json" 2>/dev/null; then
      STACK_FRAMEWORK="React"
    elif grep -q '"vue"' "${t}/package.json" 2>/dev/null; then
      STACK_FRAMEWORK="Vue"
    elif grep -q '"express"' "${t}/package.json" 2>/dev/null; then
      STACK_FRAMEWORK="Express"
    fi

    # Commands — prefer scripts block in package.json, then defaults
    local pm="${STACK_PKG_MANAGER}"

    STACK_INSTALL_CMD="${pm} install"

    if grep -q '"dev"' "${t}/package.json" 2>/dev/null; then
      STACK_DEV_CMD="${pm} run dev"
    fi
    if grep -q '"build"' "${t}/package.json" 2>/dev/null; then
      STACK_BUILD_CMD="${pm} run build"
    fi
    if grep -q '"test"' "${t}/package.json" 2>/dev/null; then
      STACK_TEST_CMD="${pm} run test"
    elif grep -q '"test:run"' "${t}/package.json" 2>/dev/null; then
      STACK_TEST_CMD="${pm} run test:run"
    fi

  # Python
  elif [[ -f "${t}/pyproject.toml" ]] || [[ -f "${t}/requirements.txt" ]]; then
    STACK_LANG="Python"
    if [[ -f "${t}/pyproject.toml" ]]; then
      STACK_INSTALL_CMD="pip install -e ."
    else
      STACK_INSTALL_CMD="pip install -r requirements.txt"
    fi
    STACK_BUILD_CMD="python -m build"
    STACK_TEST_CMD="pytest"

  # Go
  elif [[ -f "${t}/go.mod" ]]; then
    STACK_LANG="Go"
    STACK_INSTALL_CMD="go mod download"
    STACK_BUILD_CMD="go build ./..."
    STACK_TEST_CMD="go test ./..."

  # Rust
  elif [[ -f "${t}/Cargo.toml" ]]; then
    STACK_LANG="Rust"
    STACK_INSTALL_CMD="cargo fetch"
    STACK_BUILD_CMD="cargo build --release"
    STACK_TEST_CMD="cargo test"

  # Ruby
  elif [[ -f "${t}/Gemfile" ]]; then
    STACK_LANG="Ruby"
    STACK_INSTALL_CMD="bundle install"
    STACK_BUILD_CMD="rake build"
    STACK_TEST_CMD="bundle exec rspec"
  fi

  # Build stack description string
  local parts=()
  [[ -n "${STACK_FRAMEWORK}" ]] && parts+=("${STACK_FRAMEWORK}")
  [[ -n "${STACK_LANG}" ]]      && parts+=("${STACK_LANG}")
  [[ -n "${STACK_PKG_MANAGER}" && "${STACK_PKG_MANAGER}" != "npm" ]] && parts+=("${STACK_PKG_MANAGER}")

  # Persistent store detection
  if [[ -f "${t}/prisma/schema.prisma" ]]; then
    STACK_STORE="Prisma"
  elif ls "${t}"/drizzle.config.* >/dev/null 2>&1; then
    STACK_STORE="Drizzle"
  elif ls "${t}"/*.sqlite "${t}"/*.db >/dev/null 2>&1; then
    STACK_STORE="SQLite"
  elif [[ -d "${t}/supabase" ]]; then
    STACK_STORE="Supabase"
  elif [[ -d "${t}/migrations" ]]; then
    STACK_STORE="database (migrations dir found)"
  elif ls "${t}"/docker-compose*.yml "${t}"/docker-compose*.yaml >/dev/null 2>&1; then
    if grep -qiE 'postgres|mysql|mongo|mariadb' "${t}"/docker-compose*.yml "${t}"/docker-compose*.yaml 2>/dev/null; then
      STACK_STORE="docker-compose DB service"
    fi
  fi

  # Deploy detection
  if [[ -f "${t}/vercel.json" ]] || [[ -d "${t}/.vercel" ]]; then
    STACK_DEPLOY="Vercel"
  elif [[ -f "${t}/netlify.toml" ]]; then
    STACK_DEPLOY="Netlify"
  elif [[ -f "${t}/fly.toml" ]]; then
    STACK_DEPLOY="Fly.io"
  elif [[ -f "${t}/render.yaml" ]]; then
    STACK_DEPLOY="Render"
  elif [[ -f "${t}/Dockerfile" ]]; then
    STACK_DEPLOY="Docker"
  elif ls "${t}"/.github/workflows/*.yml "${t}"/.github/workflows/*.yaml >/dev/null 2>&1; then
    if grep -qiE 'deploy|release|publish' "${t}"/.github/workflows/*.yml "${t}"/.github/workflows/*.yaml 2>/dev/null; then
      STACK_DEPLOY="CI/CD (workflow detected)"
    fi
  fi

  STACK_DESCRIPTION="${parts[*]:-}"
}

detect_stack

info "Stack     : ${STACK_DESCRIPTION:-unknown}"
info "Store     : ${STACK_STORE}"
info "Deploy    : ${STACK_DEPLOY:-unknown}"
echo ""

# ---------------------------------------------------------------------------
# Build CLAUDE.md with placeholders replaced/annotated
# ---------------------------------------------------------------------------
build_claude_md() {
  local raw
  raw="$(cat "${KIT_ROOT}/CLAUDE.template.md")"

  # Strip the leading HTML comment block (<!-- ... --> at top)
  # Use a Python/awk fallback-safe approach via sed on ranges
  raw="$(printf '%s\n' "${raw}" | sed '/^<!--$/,/^-->$/d')"
  # Drop any leading blank lines left behind by the strip.
  raw="$(printf '%s\n' "${raw}" | sed '/./,$!d')"

  # Project name
  raw="${raw//<PROJECT NAME>/${PROJECT_NAME}}"

  # Stack line
  local stack_val
  if [[ -n "${STACK_DESCRIPTION}" ]]; then
    stack_val="${STACK_DESCRIPTION}"
  else
    stack_val="<framework + language + styling + notable libs> <!-- TODO: devkit-init could not infer; fill in -->"
  fi
  raw="${raw//<framework + language + styling + notable libs>/${stack_val}}"

  # Persistent state line
  local store_val
  if [[ "${STACK_STORE}" == "none" ]]; then
    store_val="none"
  else
    store_val="${STACK_STORE}"
  fi
  raw="${raw//<database \/ volume \/ uploads — or \"none\">/${store_val}}"

  # Deploy line
  local deploy_val
  if [[ -n "${STACK_DEPLOY}" ]]; then
    deploy_val="${STACK_DEPLOY} (branch: ${INTEGRATION_BRANCH} → ${STACK_DEPLOY}) <!-- TODO: confirm branch/target -->"
  else
    deploy_val="<how it ships — branch, CI, target> <!-- TODO: devkit-init could not infer; fill in -->"
  fi
  raw="${raw//<how it ships — branch, CI, target>/${deploy_val}}"

  # Commands block — replace the long-form comment placeholder with the detected value or a
  # TODO marker. We do a single substitution keyed on the unique long-form text so there is
  # no risk of the replacement text being re-matched.
  local install_todo="<!-- TODO: devkit-init could not infer install cmd; fill in -->"
  local dev_todo="<!-- TODO: devkit-init could not infer dev cmd; fill in -->"
  local build_todo="<!-- TODO: devkit-init could not infer build cmd; fill in -->"
  local test_todo="<!-- TODO: devkit-init could not infer test cmd; fill in -->"

  # When a value is detected, substitute both the long-form comment occurrence and any bare
  # occurrence. When no value is detected, only replace the long-form occurrence (whose unique
  # surrounding text ensures one match); the bare form is gone after that, so no second pass.
  if [[ -n "${STACK_INSTALL_CMD}" ]]; then
    raw="${raw//<install>      # e.g. pnpm install/${STACK_INSTALL_CMD}}"
    raw="${raw//<install>/${STACK_INSTALL_CMD}}"
  else
    raw="${raw//<install>      # e.g. pnpm install/${install_todo}}"
  fi

  if [[ -n "${STACK_DEV_CMD}" ]]; then
    raw="${raw//<dev>          # e.g. pnpm dev  → http:\/\/localhost:3000/${STACK_DEV_CMD}}"
    raw="${raw//<dev>/${STACK_DEV_CMD}}"
  else
    raw="${raw//<dev>          # e.g. pnpm dev  → http:\/\/localhost:3000/${dev_todo}}"
  fi

  if [[ -n "${STACK_BUILD_CMD}" ]]; then
    raw="${raw//<build>        # e.g. pnpm build/${STACK_BUILD_CMD}}"
    raw="${raw//<build>/${STACK_BUILD_CMD}}"
  else
    raw="${raw//<build>        # e.g. pnpm build/${build_todo}}"
  fi

  if [[ -n "${STACK_TEST_CMD}" ]]; then
    raw="${raw//<test>         # e.g. pnpm test   (or: \"no tests — verify via preview\")/${STACK_TEST_CMD}}"
    raw="${raw//<test>/${STACK_TEST_CMD}}"
  else
    raw="${raw//<test>         # e.g. pnpm test   (or: \"no tests — verify via preview\")/${test_todo}}"
  fi

  # other — always a TODO
  raw="${raw//<other>        # project-specific scripts worth knowing/<other> <!-- TODO: add project-specific scripts worth knowing -->}"

  # Branch model placeholders
  raw="${raw//<integration-branch>/${INTEGRATION_BRANCH}}"

  # live-branch: if we have a deploy target, suggest a separate 'prod'/'release'; else default to integration
  local live_br_name
  if [[ -n "${STACK_DEPLOY}" ]]; then
    live_br_name="<live-branch> <!-- TODO: devkit-init could not determine live branch; common values: prod, release, main -->"
  else
    live_br_name="${INTEGRATION_BRANCH}"
  fi
  raw="${raw//<live-branch>/${live_br_name}}"

  # Remaining prose placeholders — annotate with TODO markers
  local ph_desc="<one-sentence description of the project and who it's for>"
  local ph_gotcha="<anything non-obvious that has bitten work before — env quirks, fragile areas, \"don't touch X\">"
  raw="${raw//${ph_desc}/${ph_desc} <!-- TODO: devkit-init could not infer; fill in -->}"
  raw="${raw//<area \/ dir>/<area \/ dir> <!-- TODO: fill in -->}"
  raw="${raw//<what lives here, one line>/<what lives here, one line> <!-- TODO: fill in -->}"
  raw="${raw//<…>/<…> <!-- TODO: fill in -->}"
  raw="${raw//<project conventions — match surrounding code, formatter, etc.>/<project conventions — match surrounding code, formatter, etc.> <!-- TODO: fill in -->}"
  raw="${raw//${ph_gotcha}/${ph_gotcha} <!-- TODO: fill in -->}"

  # Persistent store references in Data-safety section
  if [[ "${STACK_STORE}" != "none" ]]; then
    raw="${raw//<the persistent store>/${STACK_STORE}}"
    raw="${raw//<the store>/${STACK_STORE}}"
    raw="${raw//<boot\/deploy>/boot or deploy}"
  fi

  printf '%s\n' "${raw}"
}

# ---------------------------------------------------------------------------
# Build ci.yml with placeholders replaced
# ---------------------------------------------------------------------------
build_ci_yml() {
  local raw
  raw="$(cat "${KIT_ROOT}/templates/.github/workflows/ci.yml")"

  raw="${raw//<INTEGRATION_BRANCH>/${INTEGRATION_BRANCH}}"

  # Replace each placeholder once. When a value was detected, substitute both the
  # long-form comment occurrence and any bare occurrence. When no value was detected,
  # only replace the long-form occurrence with a TODO marker (bare form no longer
  # exists after that replacement, so no second pass needed).
  local ci_install_todo="# TODO: devkit-init could not infer; fill in"
  local ci_build_todo="# TODO: devkit-init could not infer; fill in — REQUIRED: this is the gate"
  local ci_test_todo="# TODO: devkit-init could not infer; fill in (or delete this step)"

  if [[ -n "${STACK_INSTALL_CMD}" ]]; then
    raw="${raw//<INSTALL_CMD>        # e.g. pnpm install --frozen-lockfile/${STACK_INSTALL_CMD}}"
    raw="${raw//<INSTALL_CMD>/${STACK_INSTALL_CMD}}"
  else
    raw="${raw//<INSTALL_CMD>        # e.g. pnpm install --frozen-lockfile/${ci_install_todo}}"
  fi

  if [[ -n "${STACK_BUILD_CMD}" ]]; then
    raw="${raw//<BUILD_CMD>          # e.g. pnpm build   — REQUIRED: this is the gate/${STACK_BUILD_CMD}}"
    raw="${raw//<BUILD_CMD>/${STACK_BUILD_CMD}}"
  else
    raw="${raw//<BUILD_CMD>          # e.g. pnpm build   — REQUIRED: this is the gate/${ci_build_todo}}"
  fi

  if [[ -n "${STACK_TEST_CMD}" ]]; then
    raw="${raw//<TEST_CMD>           # e.g. pnpm test    — or delete this step if there are no tests/${STACK_TEST_CMD}}"
    raw="${raw//<TEST_CMD>/${STACK_TEST_CMD}}"
  else
    raw="${raw//<TEST_CMD>           # e.g. pnpm test    — or delete this step if there are no tests/${ci_test_todo}}"
  fi

  local pm_val="${STACK_PKG_MANAGER:-}"
  if [[ -n "${pm_val}" ]]; then
    raw="${raw//<PKG_MANAGER>/${pm_val}}"
  fi

  printf '%s\n' "${raw}"
}

# ---------------------------------------------------------------------------
# Build decisions/0001 with today's date
# ---------------------------------------------------------------------------
build_decision_0001() {
  local raw
  raw="$(cat "${KIT_ROOT}/templates/docs/decisions/0001-adopt-agent-dev-system.md")"
  raw="${raw//<YYYY-MM-DD — set at install>/${TODAY}}"
  printf '%s\n' "${raw}"
}

# ---------------------------------------------------------------------------
# Scaffold files
# ---------------------------------------------------------------------------
info "--- Scaffolding files ---"

# CLAUDE.md (generated)
write_file "${TARGET_DIR}/CLAUDE.md" <<EOF
$(build_claude_md)
EOF

# docs/ tree — plain copies except decisions/0001
copy_file "${KIT_ROOT}/templates/docs/roadmap.md"                    "${TARGET_DIR}/docs/roadmap.md"
copy_file "${KIT_ROOT}/templates/docs/features/_template.md"         "${TARGET_DIR}/docs/features/_template.md"
copy_file "${KIT_ROOT}/templates/docs/decisions/_template.md"        "${TARGET_DIR}/docs/decisions/_template.md"

# decisions/0001 — generated with today's date
write_file "${TARGET_DIR}/docs/decisions/0001-adopt-agent-dev-system.md" <<EOF
$(build_decision_0001)
EOF

# .claude/agents/
copy_file "${KIT_ROOT}/templates/.claude/agents/explorer.md"         "${TARGET_DIR}/.claude/agents/explorer.md"
copy_file "${KIT_ROOT}/templates/.claude/agents/planner.md"          "${TARGET_DIR}/.claude/agents/planner.md"
copy_file "${KIT_ROOT}/templates/.claude/agents/implementer.md"      "${TARGET_DIR}/.claude/agents/implementer.md"
copy_file "${KIT_ROOT}/templates/.claude/agents/reviewer.md"         "${TARGET_DIR}/.claude/agents/reviewer.md"

# .claude/skills/pre-pr-review/
copy_file "${KIT_ROOT}/templates/.claude/skills/pre-pr-review/SKILL.md"  "${TARGET_DIR}/.claude/skills/pre-pr-review/SKILL.md"

# .github/
copy_file "${KIT_ROOT}/templates/.github/pull_request_template.md"   "${TARGET_DIR}/.github/pull_request_template.md"

# ci.yml (generated)
write_file "${TARGET_DIR}/.github/workflows/ci.yml" <<EOF
$(build_ci_yml)
EOF

echo ""

# ---------------------------------------------------------------------------
# Data-safety notice (when store = none)
# ---------------------------------------------------------------------------
if [[ "${STACK_STORE}" == "none" ]]; then
  note "No persistent store detected."
  note "The 'Data safety' section in CLAUDE.md should be deleted if this project truly has no state."
  note "Edit ${TARGET_DIR}/CLAUDE.md and remove the section marked:"
  note "  ## Data safety <!-- delete this whole section if the project has no persistent state -->"
  echo ""
fi

# ---------------------------------------------------------------------------
# Git guidance (unless --no-git)
# ---------------------------------------------------------------------------
if [[ "${NO_GIT}" == false ]]; then
  info "--- Git guidance ---"
  if ! git -C "${TARGET_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
    note "Target is NOT a git repo."
    note "Run: git -C '${TARGET_DIR}' init && git -C '${TARGET_DIR}' checkout -b ${INTEGRATION_BRANCH}"
  else
    if git -C "${TARGET_DIR}" show-ref --verify --quiet "refs/heads/${INTEGRATION_BRANCH}" 2>/dev/null; then
      ok "Branch '${INTEGRATION_BRANCH}' exists."
    else
      note "Integration branch '${INTEGRATION_BRANCH}' does not exist yet."
      note "Run: git -C '${TARGET_DIR}' checkout -b ${INTEGRATION_BRANCH}"
    fi
  fi
  echo ""
fi

# ---------------------------------------------------------------------------
# Collect TODO placeholders for final report
# ---------------------------------------------------------------------------
collect_todos() {
  local todos=()
  [[ -z "${STACK_DESCRIPTION}" ]]                       && todos+=("CLAUDE.md: Stack (framework/language) — unknown; fill in manually.")
  [[ -z "${STACK_DEPLOY}" ]]                             && todos+=("CLAUDE.md: Deploy target — unknown; fill in manually.")
  [[ -z "${STACK_DEV_CMD}" && -n "${STACK_LANG}" ]]      && todos+=("CLAUDE.md / ci.yml: <dev> command — not found in package.json.")
  [[ -z "${STACK_BUILD_CMD}" && -z "${STACK_LANG}" ]]    && todos+=("CLAUDE.md / ci.yml: <build> command — stack undetected; fill in manually.")
  [[ -z "${STACK_TEST_CMD}" ]]                           && todos+=("CLAUDE.md / ci.yml: <test> command — not found; fill in or delete step.")
  [[ "${STACK_STORE}" != "none" ]]                       && todos+=("CLAUDE.md: Data-safety section — store is '${STACK_STORE}'; review <boot/deploy> placeholder.")
  [[ "${STACK_STORE}" == "none" ]]                       && todos+=("CLAUDE.md: Delete the Data-safety section (no persistent store detected).")
  todos+=("CLAUDE.md: One-sentence project description — fill in manually.")
  todos+=("CLAUDE.md: Architecture map (<area/dir> entries) — fill in manually.")
  todos+=("CLAUDE.md: Conventions / gotchas — fill in manually.")
  if [[ -n "${STACK_DEPLOY}" ]]; then
    todos+=("CLAUDE.md: <live-branch> — a deploy target was detected; confirm the live branch name.")
  fi
  for t in "${todos[@]}"; do
    note "TODO: ${t}"
  done
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
info "--- Summary ---"
if [[ "${DRY_RUN}" == true ]]; then
  info "DRY RUN — no files written. Would create: ${COUNT_WOULD_CREATE}"
else
  info "Created : ${COUNT_CREATED}"
  info "Skipped : ${COUNT_SKIPPED}"
fi
echo ""
info "--- How we work here (5 core habits) ---"
cat <<'HABITS'
  1. Repo is the memory; conversation is disposable.
     → Before ending a session, write any surviving state to a file.
  2. One unit of work = one conversation = one branch.
     → Don't build multiple features in one chat.
  3. Don't re-explore the whole repo.
     → Delegate searches to Explorer; get conclusions, not file dumps.
  4. Match the model to the task.
     → Haiku for mechanical work; Sonnet for implementation; Opus for architecture/review.
  5. Docs currency is part of done.
     → Update CLAUDE.md, roadmap, and decision log in the same PR as the change.

  Branch model: feat/<name> → PR → <integration> → human merges
HABITS
echo ""
info "--- Branch model ---"
info "  feat/<name>  →  PR  →  ${INTEGRATION_BRANCH}  (CI validates)  →  human merges"
echo ""
info "--- TODOs for the operator to resolve ---"
collect_todos
echo ""
ok "devkit-init complete."
