#!/usr/bin/env bash
set -euo pipefail

# Usage: ./run-eval.sh <eval-dir>
# Example: ./run-eval.sh evals/hello-world-typescript

# Track worktrees for cleanup
WORKTREES_TO_CLEAN=()

# Store evaluation result file paths per variant
declare -A EVAL_RESULT_FILES

validate_eval_dir() {
  local eval_dir="$1"
  for f in scenario.json task.md criteria.json; do
    if [[ ! -f "${eval_dir}/${f}" ]]; then
      echo "Error: ${eval_dir}/${f} not found"
      exit 1
    fi
  done
}

parse_scenario() {
  local eval_dir="$1"
  REF=$(jq -r '.fixture.ref' "${eval_dir}/scenario.json")
  EXCLUDES=$(jq -r '.fixture.exclude // [] | .[]' "${eval_dir}/scenario.json")
  EVAL_NAME="$(basename "${eval_dir}")"
  EVAL_DIR_ABS="$(cd "${eval_dir}" && pwd)"
}

create_worktree() {
  local variant="$1"
  local tmpdir
  tmpdir="$(mktemp -d)"
  WORKTREE_DIR="${tmpdir}/eval-${EVAL_NAME}-${variant}"
  WORKTREES_TO_CLEAN+=("${WORKTREE_DIR}" "${tmpdir}")

  echo "==> Creating worktree at ref ${REF} in ${WORKTREE_DIR}"
  git worktree add "${WORKTREE_DIR}" "${REF}"
}

confirm_and_remove() {
  local resolved="$1"
  local exclude="$2"

  echo "    will remove: ${resolved}"
  read -r -p "    Proceed? [y/N] " confirm < /dev/tty
  if [[ "${confirm}" =~ ^[Yy]$ ]]; then
    rm -rf "${resolved}"
    echo "    removed: ${exclude}"
  else
    echo "    skipped: ${exclude}"
  fi
}

apply_excludes() {
  local worktree_dir="$1"

  echo "==> Removing excluded files/dirs..."
  while IFS= read -r exclude; do
    # Portable alternative to GNU realpath -m (not available on macOS)
    local resolved="${worktree_dir}/${exclude}"
    # Prevent path traversal outside worktree
    if [[ "${resolved}" != "${worktree_dir}"/* ]]; then
      echo "    SKIPPED (path traversal): ${exclude}"
      continue
    fi
    confirm_and_remove "${resolved}" "${exclude}"
  done <<< "${EXCLUDES}"
}

prepare_worktree() {
  local worktree_dir="$1"
  local variant="$2"

  if [[ "${variant}" == "with-context" ]]; then
    cp "${REPO_ROOT}/CLAUDE.md" "${worktree_dir}/CLAUDE.md"
    echo "==> Copied CLAUDE.md into worktree"
  fi
}

run_task() {
  local worktree_dir="$1"
  local variant="$2"

  echo ""
  echo "==> Running task (${variant})"
  (cd "${worktree_dir}" && claude "complete the task described in ${EVAL_DIR_ABS}/task.md in the current directory")
}

run_evaluation() {
  local worktree_dir="$1"
  local variant="$2"

  local run_date
  run_date="$(date +%Y%m%d-%H%M%S)"
  local runs_dir="${EVAL_DIR_ABS}/runs"
  mkdir -p "${runs_dir}"
  local result_file="${runs_dir}/${run_date}-${variant}.md"
  EVAL_RESULT_FILES["${variant}"]="${result_file}"

  echo ""
  echo "==> Evaluating (${variant})"
  (cd "${worktree_dir}" && claude "evaluate the solution against the criteria described in ${EVAL_DIR_ABS}/criteria.json. Write your evaluation results to ${result_file}")
}

run_variant() {
  local variant="$1"
  local should_exclude="$2"

  echo ""
  echo "========================================"
  echo "==> Variant: ${variant}"
  echo "========================================"

  create_worktree "${variant}"

  if [[ "${should_exclude}" == "true" && -n "${EXCLUDES}" ]]; then
    apply_excludes "${WORKTREE_DIR}"
  else
    echo "==> Keeping all files (no excludes applied)"
  fi

  prepare_worktree "${WORKTREE_DIR}" "${variant}"
  run_task "${WORKTREE_DIR}" "${variant}"
  run_evaluation "${WORKTREE_DIR}" "${variant}"
}

compare_results() {
  echo ""
  echo "========================================"
  echo "==> Comparison of evaluation results"
  echo "========================================"

  for variant in "${!EVAL_RESULT_FILES[@]}"; do
    echo ""
    echo "--- ${variant} ---"
    cat "${EVAL_RESULT_FILES["${variant}"]}"
  done

  local with_context without_context
  with_context="$(cat "${EVAL_RESULT_FILES["with-context"]}")"
  without_context="$(cat "${EVAL_RESULT_FILES["without-context"]}")"

  echo ""
  echo "--- Summary ---"
  claude "Compare the following two evaluation results and summarize the differences:

=== with-context ===
${with_context}

=== without-context ===
${without_context}"
}

cleanup() {
  echo ""
  echo "==> Cleaning up worktrees..."
  for path in "${WORKTREES_TO_CLEAN[@]+"${WORKTREES_TO_CLEAN[@]}"}"; do
    [[ -z "${path}" ]] && continue
    if git worktree list | grep -q "${path}"; then
      git worktree remove --force "${path}" 2>/dev/null || true
    else
      rm -rf "${path}" 2>/dev/null || true
    fi
  done
}

# --- Main ---

EVAL_DIR="${1:?Usage: $0 <eval-dir>}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

validate_eval_dir "${EVAL_DIR}"
parse_scenario "${EVAL_DIR}"

trap cleanup EXIT

run_variant "with-context" "false"
run_variant "without-context" "true"

compare_results
