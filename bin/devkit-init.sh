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
STACK_STORE_CERTAIN=true   # false ⇒ inferred from a dependency only; needs human confirmation
STACK_STORE_EVIDENCE=""    # human-readable why, e.g. "data/app.db" or "better-sqlite3 dependency"
STACK_DEPLOY=""
STACK_LIVE_BRANCH=""       # branch a deploy workflow ships from, when it differs from integration

# Emit candidate branch names (one per line) referenced by a workflow file: `refs/heads/<x>`
# guards and `on.push.branches` lists (inline `[a, b]` or block `- a`). Quotes/spaces are cleaned
# by the caller; this only locates the tokens.
extract_wf_branches() {
  awk '
    {
      tmp = $0
      while (match(tmp, /refs\/heads\/[A-Za-z0-9._\/-]+/)) {
        b = substr(tmp, RSTART, RLENGTH); sub(/refs\/heads\//, "", b); print b
        tmp = substr(tmp, RSTART + RLENGTH)
      }
    }
    /branches:/ {
      # Inline list anywhere on the line: branches: [a, b]  (incl. compact flow style).
      if (match($0, /\[[^]]*\]/)) {
        inner = substr($0, RSTART + 1, RLENGTH - 2)
        n = split(inner, a, ","); for (i = 1; i <= n; i++) print a[i]
        inblock = 0
      } else if ($0 ~ /^[[:space:]]*branches:[[:space:]]*$/) {
        inblock = 1   # block style: `branches:` then `- name` lines below
      }
      next
    }
    inblock == 1 {
      if ($0 ~ /^[[:space:]]*-[[:space:]]*/) {
        v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v); sub(/[[:space:]]*#.*/, "", v); print v
      } else if ($0 ~ /[^[:space:]]/) inblock = 0
    }
  ' "$1" 2>/dev/null
}

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

  # Persistent store detection — recursive + dependency-aware.
  #
  # Precedence (highest confidence first): ORM/config schema → on-disk DB file (root + common
  # subdirs) → dependency inference → migrations/docker hints. A store found on disk or via ORM
  # config is *certain*; a store inferred from a dependency only is flagged "(inferred — confirm)".
  # We NEVER advise deleting the Data-safety section on a false negative — see the notice + TODOs
  # below, which key off STACK_STORE_CERTAIN.

  # Look for a SQLite-style DB file in the root and the common store subdirs (not a deep find —
  # that would wander into node_modules and build output).
  local found_db=""
  local d dir f
  for d in "" data db .data prisma var storage; do
    dir="${t}${d:+/$d}"
    [[ -d "${dir}" ]] || continue
    for f in "${dir}"/*.sqlite "${dir}"/*.sqlite3 "${dir}"/*.db; do
      [[ -e "${f}" ]] || continue   # literal glob when nothing matches
      found_db="${f}"
      break 2
    done
  done

  # Map a package.json dependency to a store name (first match wins).
  local dep_store="" dep_name=""
  if [[ -f "${t}/package.json" ]]; then
    local pj="${t}/package.json"
    if   grep -qE '"(better-sqlite3|sqlite3|@libsql/client)"' "${pj}" 2>/dev/null; then
      dep_store="SQLite";     dep_name="$(grep -oE 'better-sqlite3|sqlite3|@libsql/client' "${pj}" | head -1)"
    elif grep -qE '"drizzle-orm"' "${pj}" 2>/dev/null; then
      dep_store="Drizzle";    dep_name="drizzle-orm"
    elif grep -qE '"@prisma/client"' "${pj}" 2>/dev/null; then
      dep_store="Prisma";     dep_name="@prisma/client"
    elif grep -qE '"(pg|postgres)"' "${pj}" 2>/dev/null; then
      dep_store="PostgreSQL"; dep_name="$(grep -oE '"(pg|postgres)"' "${pj}" | head -1 | tr -d '"')"
    elif grep -qE '"(mysql|mysql2)"' "${pj}" 2>/dev/null; then
      dep_store="MySQL";      dep_name="$(grep -oE 'mysql2|mysql' "${pj}" | head -1)"
    elif grep -qE '"(mongodb|mongoose)"' "${pj}" 2>/dev/null; then
      dep_store="MongoDB";    dep_name="$(grep -oE 'mongoose|mongodb' "${pj}" | head -1)"
    elif grep -qE '"(redis|ioredis)"' "${pj}" 2>/dev/null; then
      dep_store="Redis";      dep_name="$(grep -oE 'ioredis|redis' "${pj}" | head -1)"
    fi
  fi

  if [[ -f "${t}/prisma/schema.prisma" ]]; then
    STACK_STORE="Prisma"; STACK_STORE_CERTAIN=true; STACK_STORE_EVIDENCE="prisma/schema.prisma"
  elif ls "${t}"/drizzle.config.* >/dev/null 2>&1; then
    STACK_STORE="Drizzle"; STACK_STORE_CERTAIN=true; STACK_STORE_EVIDENCE="drizzle.config"
  elif [[ -n "${found_db}" ]]; then
    STACK_STORE="SQLite"; STACK_STORE_CERTAIN=true
    STACK_STORE_EVIDENCE="${found_db#"${t}"/}"   # show the path relative to the target
  elif [[ -d "${t}/supabase" ]]; then
    STACK_STORE="Supabase"; STACK_STORE_CERTAIN=true; STACK_STORE_EVIDENCE="supabase/ directory"
  elif [[ -n "${dep_store}" ]]; then
    # No on-disk artifact, but a store client is a dependency — infer and flag for confirmation.
    STACK_STORE="${dep_store}"; STACK_STORE_CERTAIN=false
    STACK_STORE_EVIDENCE="${dep_name} dependency"
  elif [[ -d "${t}/migrations" ]]; then
    STACK_STORE="database (migrations dir found)"; STACK_STORE_CERTAIN=true
    STACK_STORE_EVIDENCE="migrations/ directory"
  else
    # docker-compose with a DB service. Collect the files that actually exist first — a bare
    # `ls a.yml a.yaml` returns non-zero if EITHER operand is an unmatched literal, which would
    # false-negative a project that uses only the .yaml spelling.
    local dc_files=()
    for f in "${t}"/docker-compose*.yml "${t}"/docker-compose*.yaml; do
      [[ -e "${f}" ]] && dc_files+=("${f}")
    done
    if [[ ${#dc_files[@]} -gt 0 ]] && grep -qiE 'postgres|mysql|mongo|mariadb' "${dc_files[@]}" 2>/dev/null; then
      STACK_STORE="docker-compose DB service"; STACK_STORE_CERTAIN=true
      STACK_STORE_EVIDENCE="${dc_files[0]#"${t}"/}"
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
  else
    # GitHub Actions deploy workflow. Same .yml/.yaml glob hazard as above — collect existing
    # files first so a `.yaml`-only workflow dir isn't missed.
    local wf_files=()
    for f in "${t}"/.github/workflows/*.yml "${t}"/.github/workflows/*.yaml; do
      [[ -e "${f}" ]] && wf_files+=("${f}")
    done
    if [[ ${#wf_files[@]} -gt 0 ]] && grep -qiE 'deploy|release|publish' "${wf_files[@]}" 2>/dev/null; then
      STACK_DEPLOY="CI/CD (workflow detected)"
    fi
  fi

  # Live/deploy-branch inference. If a deploy-flavored workflow ships from a branch other than the
  # integration branch, surface it (real-world: main = CI, production = deploy). Best-effort; the
  # default assumption stays live == integration when nothing distinct is found.
  local wf_all=()
  for f in "${t}"/.github/workflows/*.yml "${t}"/.github/workflows/*.yaml; do
    [[ -e "${f}" ]] && wf_all+=("${f}")
  done
  if [[ ${#wf_all[@]} -gt 0 ]]; then
    local brs="" known cand=""
    for f in "${wf_all[@]}"; do
      grep -qiE 'deploy|release|publish' "${f}" 2>/dev/null || continue
      brs+="$(extract_wf_branches "${f}" | sed "s/[\"' ]//g")"$'\n'
    done
    # Prefer a well-known live-branch name; otherwise take the first non-integration candidate.
    for known in production prod release live stable deploy master main; do
      [[ "${known}" == "${INTEGRATION_BRANCH}" ]] && continue
      if printf '%s\n' "${brs}" | grep -qxF "${known}"; then cand="${known}"; break; fi
    done
    if [[ -z "${cand}" ]]; then
      # `|| true`: grep exits 1 when nothing remains after excluding the integration branch, which
      # would abort the script under `set -euo pipefail`. Empty cand is the correct outcome there.
      cand="$(printf '%s\n' "${brs}" | grep -vxF "${INTEGRATION_BRANCH}" | sed '/^[[:space:]]*$/d' | head -1 || true)"
    fi
    [[ -n "${cand}" ]] && STACK_LIVE_BRANCH="${cand}"
  fi

  STACK_DESCRIPTION="${parts[*]:-}"
}

detect_stack

info "Stack     : ${STACK_DESCRIPTION:-unknown}"
if [[ "${STACK_STORE}" != "none" && "${STACK_STORE_CERTAIN}" == false ]]; then
  info "Store     : ${STACK_STORE} (inferred from ${STACK_STORE_EVIDENCE} — confirm)"
elif [[ "${STACK_STORE}" != "none" ]]; then
  info "Store     : ${STACK_STORE} (${STACK_STORE_EVIDENCE})"
else
  info "Store     : none"
fi
if [[ -n "${STACK_LIVE_BRANCH}" ]]; then
  info "Deploy    : ${STACK_DEPLOY:-unknown} (live branch inferred: ${STACK_LIVE_BRANCH})"
else
  info "Deploy    : ${STACK_DEPLOY:-unknown}"
fi
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
  elif [[ "${STACK_STORE_CERTAIN}" == false ]]; then
    store_val="${STACK_STORE} (inferred from ${STACK_STORE_EVIDENCE} — confirm) <!-- TODO: confirm the store; keep the Data-safety section below unless the project is truly stateless -->"
  else
    store_val="${STACK_STORE}"
  fi
  raw="${raw//<database \/ volume \/ uploads — or \"none\">/${store_val}}"

  # Deploy line
  local deploy_val
  if [[ -n "${STACK_DEPLOY}" && -n "${STACK_LIVE_BRANCH}" ]]; then
    deploy_val="${STACK_DEPLOY} (branch: ${STACK_LIVE_BRANCH} → ${STACK_DEPLOY}) <!-- TODO: confirm — '${STACK_LIVE_BRANCH}' inferred from a deploy workflow -->"
  elif [[ -n "${STACK_DEPLOY}" ]]; then
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

  # live-branch: prefer one inferred from a deploy workflow; else, if a deploy target exists but no
  # distinct branch was found, leave a TODO; else default to the integration branch.
  local live_br_name
  if [[ -n "${STACK_LIVE_BRANCH}" ]]; then
    live_br_name="${STACK_LIVE_BRANCH}"
  elif [[ -n "${STACK_DEPLOY}" ]]; then
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

  # --- Toolchain setup: a real, runnable block for the detected stack -------------------------
  # For Node we `corepack enable` first, which activates the pnpm/yarn version pinned in
  # package.json's "packageManager" field. That is why we do NOT also pin a version in a
  # pnpm/action-setup step — the two together fail with ERR_PNPM_BAD_PM_VERSION.
  local toolchain
  case "${STACK_LANG}" in
    "TypeScript/JavaScript")
      case "${STACK_PKG_MANAGER}" in
        pnpm)
          toolchain="      - name: Enable corepack (activates the pnpm version from package.json \"packageManager\")
        run: corepack enable
      - uses: actions/setup-node@v4
        with:
          node-version: 'lts/*'
          cache: 'pnpm'" ;;
        yarn)
          toolchain="      - name: Enable corepack (activates the yarn version from package.json \"packageManager\")
        run: corepack enable
      - uses: actions/setup-node@v4
        with:
          node-version: 'lts/*'
          cache: 'yarn'" ;;
        *)
          toolchain="      - uses: actions/setup-node@v4
        with:
          node-version: 'lts/*'
          cache: 'npm'" ;;
      esac ;;
    "Python")
      toolchain="      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'" ;;
    "Go")
      toolchain="      - uses: actions/setup-go@v5
        with:
          go-version: 'stable'" ;;
    "Rust")
      toolchain="      # Rust stable toolchain is preinstalled on ubuntu-latest runners — no setup step needed." ;;
    "Ruby")
      toolchain="      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.x'
          bundler-cache: true" ;;
    *)
      toolchain="      # TODO: devkit-init could not infer the toolchain — add the setup step for your stack." ;;
  esac
  raw="${raw//      # <<DEVKIT_TOOLCHAIN>>/${toolchain}}"

  # --- Install / Build commands --------------------------------------------------------------
  local ci_install_todo="# TODO: devkit-init could not infer; fill in"
  local ci_build_todo="# TODO: devkit-init could not infer; fill in — REQUIRED: this is the gate"

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

  # --- Test step: emit a real step only when a test command was detected ----------------------
  # (An empty `run:` is invalid, so omit the step entirely rather than leave a TODO placeholder.)
  local test_step
  if [[ -n "${STACK_TEST_CMD}" ]]; then
    test_step="
      - name: Test
        run: ${STACK_TEST_CMD}"
  else
    test_step="      # No test command detected — add a Test step here when you have one."
  fi
  raw="${raw//      # <<DEVKIT_TEST_STEP>>/${test_step}}"

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
copy_file "${KIT_ROOT}/templates/.claude/agents/plan-presenter.md"   "${TARGET_DIR}/.claude/agents/plan-presenter.md"

# .claude/skills/
copy_file "${KIT_ROOT}/templates/.claude/skills/pre-pr-review/SKILL.md"  "${TARGET_DIR}/.claude/skills/pre-pr-review/SKILL.md"
copy_file "${KIT_ROOT}/templates/.claude/skills/status/SKILL.md"         "${TARGET_DIR}/.claude/skills/status/SKILL.md"
copy_file "${KIT_ROOT}/templates/.claude/skills/preview/SKILL.md"        "${TARGET_DIR}/.claude/skills/preview/SKILL.md"

# .github/
copy_file "${KIT_ROOT}/templates/.github/pull_request_template.md"   "${TARGET_DIR}/.github/pull_request_template.md"

# ci.yml (generated)
write_file "${TARGET_DIR}/.github/workflows/ci.yml" <<EOF
$(build_ci_yml)
EOF

echo ""

# ---------------------------------------------------------------------------
# Data-safety notice
# ---------------------------------------------------------------------------
if [[ "${STACK_STORE}" == "none" ]]; then
  # No store detected. This can be a true negative (static site) or a false one (a store we
  # didn't recognise). NEVER tell the operator to delete the section outright — make it conditional.
  note "No persistent store detected — could not find a DB file, ORM config, or store dependency."
  note "If this project is truly stateless, delete the 'Data safety' section in CLAUDE.md:"
  note "  ## Data safety <!-- delete this whole section if the project has no persistent state -->"
  note "If it DOES keep state we missed, KEEP that section and name the store by hand."
  echo ""
elif [[ "${STACK_STORE_CERTAIN}" == false ]]; then
  note "Store inferred as '${STACK_STORE}' from the ${STACK_STORE_EVIDENCE} (no DB file on disk yet)."
  note "Confirm it and complete the 'Data safety' section in CLAUDE.md — do NOT delete it on a guess."
  echo ""
fi

# ---------------------------------------------------------------------------
# Guard: the installer's own files must never be gitignored.
#   A blanket rule like `/.claude/skills/` would gitignore the review gate, so it would vanish on a
#   fresh clone. After scaffolding we check-ignore the critical kit files and, if any are ignored,
#   append narrow negations to .gitignore under a marker (idempotent) and warn loudly.
# ---------------------------------------------------------------------------
guard_against_gitignore() {
  [[ "${DRY_RUN}" == true || "${NO_GIT}" == true ]] && return 0
  git -C "${TARGET_DIR}" rev-parse --git-dir >/dev/null 2>&1 || return 0

  local critical=(
    ".claude/skills/pre-pr-review/SKILL.md"
    ".claude/skills/status/SKILL.md"
    ".claude/skills/preview/SKILL.md"
    ".claude/agents/explorer.md"
    ".claude/agents/plan-presenter.md"
    ".claude/agents/planner.md"
    ".claude/agents/implementer.md"
    ".claude/agents/reviewer.md"
    ".github/workflows/ci.yml"
    ".github/pull_request_template.md"
    "CLAUDE.md"
    "docs/roadmap.md"
  )

  local rel ignored=()
  for rel in "${critical[@]}"; do
    git -C "${TARGET_DIR}" check-ignore -q "${rel}" 2>/dev/null && ignored+=("${rel}")
  done
  if [[ ${#ignored[@]} -eq 0 ]]; then
    ok "Devkit files are all tracked (not gitignored)."
    return 0
  fi

  warn "These installed devkit files are gitignored and would NOT survive a fresh clone:"
  for rel in "${ignored[@]}"; do warn "    ${rel}"; done

  local marker="# devkit-init: keep agent-dev system files tracked (do not remove)"
  if grep -qF "${marker}" "${TARGET_DIR}/.gitignore" 2>/dev/null; then
    warn "A devkit negation block already exists in .gitignore but files are still ignored."
    warn "Resolve by hand — a nested .gitignore or a later rule is re-excluding them."
    return 0
  fi

  # Walk each ignored file's path prefixes; re-include only the prefixes git actually ignores.
  # (Git cannot un-ignore a file whose parent dir is excluded, so parent dirs need negations too.)
  local -a unignore=()
  local prefix seg present q
  for rel in "${ignored[@]}"; do
    prefix=""
    while IFS= read -r seg; do
      [[ -n "${seg}" ]] || continue
      prefix="${prefix}/${seg}"
      git -C "${TARGET_DIR}" check-ignore -q "${prefix#/}" 2>/dev/null || continue
      present=false
      for q in "${unignore[@]}"; do [[ "${q}" == "${prefix}" ]] && { present=true; break; }; done
      [[ "${present}" == false ]] && unignore+=("${prefix}")
    done < <(printf '%s\n' "${rel}" | tr '/' '\n')
  done

  {
    printf '\n%s\n' "${marker}"
    for prefix in "${unignore[@]}"; do
      if [[ -d "${TARGET_DIR}${prefix}" ]]; then
        printf '!%s/\n' "${prefix}"
      else
        printf '!%s\n' "${prefix}"
      fi
    done
  } >> "${TARGET_DIR}/.gitignore"
  ok "Appended narrow .gitignore negations so devkit files stay tracked."

  # Re-verify; if anything is still ignored, the operator must resolve it.
  local still=()
  for rel in "${ignored[@]}"; do
    git -C "${TARGET_DIR}" check-ignore -q "${rel}" 2>/dev/null && still+=("${rel}")
  done
  if [[ ${#still[@]} -gt 0 ]]; then
    warn "Still gitignored after negation — resolve by hand:"
    for rel in "${still[@]}"; do warn "    ${rel}"; done
  fi
}

# ---------------------------------------------------------------------------
# Enforcement honesty.
#   "No unreviewed change reaches the live branch" is ENFORCED only when the integration branch is
#   branch-protected on the remote; otherwise it is convention. We never silently mutate the user's
#   GitHub settings (same stance as "never auto-push / auto-create remotes") — we report what is in
#   effect, print how to enable protection, and offer an inactive local pre-push backstop.
# ---------------------------------------------------------------------------
report_enforcement() {
  [[ "${DRY_RUN}" == true || "${NO_GIT}" == true ]] && return 0
  git -C "${TARGET_DIR}" rev-parse --git-dir >/dev/null 2>&1 || return 0

  info "--- Review-gate enforcement ---"
  note "The branch model is ENFORCED only if '${INTEGRATION_BRANCH}' is branch-protected on the"
  note "remote (required PR + green CI). Without protection it is CONVENTION the agent + human keep."

  if command -v gh >/dev/null 2>&1 && git -C "${TARGET_DIR}" remote get-url origin >/dev/null 2>&1; then
    local vis
    vis="$(gh repo view --json visibility -q .visibility 2>/dev/null || true)"
    case "${vis}" in
      PUBLIC)
        note "Repo is PUBLIC → branch protection is available on the free plan." ;;
      PRIVATE)
        note "Repo is PRIVATE → protection needs GitHub Pro/Team (free-private returns 403)." ;;
      *)
        note "Could not read repo visibility (gh not authed, or no remote yet)." ;;
    esac
    note "Enable protection (one-time, human-authorized) via Settings → Branches, or:"
    note "  gh api -X PUT repos/{owner}/{repo}/branches/${INTEGRATION_BRANCH}/protection ..."
  else
    note "gh CLI or 'origin' remote not available — skipping the remote protection check."
  fi

  # Offer a convention-only pre-push backstop, written INACTIVE so it never surprises a first push.
  local hook="${TARGET_DIR}/.git/hooks/pre-push.devkit-sample"
  if [[ -d "${TARGET_DIR}/.git/hooks" && ! -e "${hook}" ]]; then
    cat > "${hook}" <<HOOK
#!/usr/bin/env bash
# devkit convention backstop — block direct pushes to the protected branch.
# Activate: mv this file to .git/hooks/pre-push and chmod +x. Bypass once: git push --no-verify.
protected="${INTEGRATION_BRANCH}"
while read -r _local_ref _local_sha remote_ref _remote_sha; do
  if [[ "\${remote_ref}" == "refs/heads/\${protected}" ]]; then
    echo "blocked: direct push to '\${protected}'. Open a PR from a feat/ branch." >&2
    exit 1
  fi
done
exit 0
HOOK
    note "Wrote an inactive pre-push backstop: .git/hooks/pre-push.devkit-sample"
    note "Activate it to block direct pushes to '${INTEGRATION_BRANCH}':"
    note "  mv .git/hooks/pre-push.devkit-sample .git/hooks/pre-push && chmod +x .git/hooks/pre-push"
  fi
}

# ---------------------------------------------------------------------------
# Git guidance (unless --no-git)
# ---------------------------------------------------------------------------
if [[ "${NO_GIT}" == false ]]; then
  info "--- Git setup ---"
  if ! git -C "${TARGET_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
    # No repo yet — initialize one on the integration branch (this is part of
    # "init what the system needs"). We never auto-commit; the user reviews first.
    if [[ "${DRY_RUN}" == true ]]; then
      dry "Would run: git init -b ${INTEGRATION_BRANCH}"
    elif git -C "${TARGET_DIR}" init -b "${INTEGRATION_BRANCH}" >/dev/null 2>&1; then
      ok "Initialized empty git repo on branch '${INTEGRATION_BRANCH}'."
    else
      # Older git without `init -b`: init, then point HEAD at the integration branch.
      git -C "${TARGET_DIR}" init >/dev/null 2>&1 || true
      git -C "${TARGET_DIR}" symbolic-ref HEAD "refs/heads/${INTEGRATION_BRANCH}" >/dev/null 2>&1 || true
      ok "Initialized empty git repo on branch '${INTEGRATION_BRANCH}'."
    fi
  else
    # Existing repo — don't touch its branches; just report/advise.
    if git -C "${TARGET_DIR}" show-ref --verify --quiet "refs/heads/${INTEGRATION_BRANCH}" 2>/dev/null; then
      ok "Integration branch '${INTEGRATION_BRANCH}' exists."
    else
      note "Integration branch '${INTEGRATION_BRANCH}' not found in this existing repo."
      note "Create it when ready: git -C '${TARGET_DIR}' checkout -b ${INTEGRATION_BRANCH}"
    fi
  fi
  echo ""

  # The review gate (and the rest of the kit) must survive a fresh clone.
  guard_against_gitignore
  echo ""

  # Be honest about whether the branch model is enforced or merely convention.
  report_enforcement
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
  if [[ "${STACK_STORE}" != "none" && "${STACK_STORE_CERTAIN}" == false ]]; then
    todos+=("CLAUDE.md: Data-safety — store INFERRED as '${STACK_STORE}' from ${STACK_STORE_EVIDENCE}; confirm it and KEEP the section (never delete on a guess).")
  elif [[ "${STACK_STORE}" != "none" ]]; then
    todos+=("CLAUDE.md: Data-safety section — store is '${STACK_STORE}'; review <boot/deploy> placeholder.")
  else
    todos+=("CLAUDE.md: No store detected — if the project is truly stateless, delete the Data-safety section; otherwise KEEP it and name the store.")
  fi
  todos+=("CLAUDE.md: One-sentence project description — fill in manually.")
  todos+=("CLAUDE.md: Architecture map (<area/dir> entries) — fill in manually.")
  todos+=("CLAUDE.md: Conventions / gotchas — fill in manually.")
  if [[ -n "${STACK_LIVE_BRANCH}" ]]; then
    todos+=("CLAUDE.md: live branch inferred as '${STACK_LIVE_BRANCH}' (≠ integration '${INTEGRATION_BRANCH}') from a deploy workflow — confirm.")
  elif [[ -n "${STACK_DEPLOY}" ]]; then
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
info "--- Next steps ---"
if [[ "${DRY_RUN}" == true ]]; then
  info "  (dry run — re-run without --dry-run to apply.)"
else
  info "  1. Finish the brief: open this repo in Claude Code and run /devkit-init,"
  info "     which fills the TODOs above by reading your code. Or edit CLAUDE.md by hand."
  info "  2. Commit the scaffold:  git add -A && git commit -m 'chore: adopt agent-dev system'"
  info "  3. Start your first feature on a branch:  git checkout -b feat/<name>"
fi
echo ""
ok "devkit-init complete."
