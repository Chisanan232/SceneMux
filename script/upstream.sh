#!/bin/bash
# Verify, repair and inspect the upstream boundary described in docs/development/upstream-sync.md.
#
#   script/upstream.sh check    # assert the boundary is intact (offline)
#   script/upstream.sh history  # the provenance half of check: no remotes needed, so CI can run it
#   script/upstream.sh setup    # create or repair the upstream remote, idempotently
#   script/upstream.sh fetch    # fetch upstream without tags, then report divergence
#   script/upstream.sh status   # how far SceneMux and upstream have diverged
#
# The derivation baseline is read from docs/legal/ORIGIN.md rather than duplicated here:
# provenance has exactly one source of truth.
set -euo pipefail
cd "$(dirname "$0")/.."

readonly ORIGIN_URL="https://github.com/Chisanan232/SceneMux.git"
readonly UPSTREAM_URL="https://github.com/ZimengXiong/winmux.git"
readonly UPSTREAM_PUSH_URL="DISABLED_no_push_to_upstream"
readonly ORIGIN_DOC="docs/legal/ORIGIN.md"

failures=0

ok() { echo "ok       $1"; }
fail() { echo "FAIL     $1" >&2; failures=$((failures + 1)); }
info() { echo "         $1"; }

baseline-sha() {
    # The row reads: | Derivation baseline commit | `<sha>` |
    local sha
    # shellcheck disable=SC2016  # the backticks are Markdown in the pattern, not a subshell
    sha=$(sed -n 's/^| Derivation baseline commit | `\([0-9a-f]\{40\}\)` |$/\1/p' "$ORIGIN_DOC")
    if [ -z "$sha" ]; then
        echo "Could not read the derivation baseline commit from $ORIGIN_DOC" >&2
        exit 1
    fi
    echo "$sha"
}

remote-url() { git remote get-url "$1" 2>/dev/null || true; }
push-url() { git remote get-url --push "$1" 2>/dev/null || true; }

# The history half of `check`: it needs a full clone but no remote configuration, so it is the
# part that can run in CI. A recorded baseline SHA is only immutable if something fails when it
# stops being an ancestor of main.
cmd-history() {
    local baseline
    baseline=$(baseline-sha)

    if [ "$(git cat-file -t "$baseline" 2>/dev/null || true)" = "commit" ]; then
        ok "derivation baseline $baseline is present"
    else
        fail "derivation baseline $baseline is missing — is this a shallow clone?"
        return
    fi

    if git merge-base --is-ancestor "$baseline" HEAD; then
        ok "derivation baseline is an ancestor of HEAD"
    else
        fail "derivation baseline is NOT an ancestor of HEAD — the inherited history is broken"
    fi

    local inherited
    inherited=$(git tag --list 'v0.[1-5].*' | grep -vxE 'v0\.1\.0' || true)
    if [ -z "$inherited" ]; then
        ok "no inherited upstream release tag is present"
    else
        fail "inherited upstream tags found: $(echo "$inherited" | tr '\n' ' ')"
    fi
}

cmd-check() {
    if [ "$(remote-url origin)" = "$ORIGIN_URL" ]; then
        ok "origin is $ORIGIN_URL"
    else
        fail "origin is '$(remote-url origin)', expected $ORIGIN_URL"
    fi

    if [ "$(remote-url upstream)" = "$UPSTREAM_URL" ]; then
        ok "upstream is $UPSTREAM_URL"
    else
        fail "upstream is '$(remote-url upstream)', expected $UPSTREAM_URL — run: script/upstream.sh setup"
    fi

    # Pushing SceneMux work into the project it derives from must not be one typo away.
    if [ "$(push-url upstream)" = "$UPSTREAM_PUSH_URL" ]; then
        ok "upstream push URL is disabled"
    else
        fail "upstream push URL is '$(push-url upstream)', expected $UPSTREAM_PUSH_URL — run: script/upstream.sh setup"
    fi

    # Without --no-tags, a routine fetch drags upstream's v0.5.x tags into SceneMux's
    # release namespace, where 0.5.4 outranks every version SceneMux will publish for years.
    if [ "$(git config --get remote.upstream.tagOpt || true)" = "--no-tags" ]; then
        ok "upstream tag fetching is disabled"
    else
        fail "remote.upstream.tagOpt is not --no-tags — run: script/upstream.sh setup"
    fi

    cmd-history
}

cmd-setup() {
    if [ -z "$(remote-url upstream)" ]; then
        git remote add upstream "$UPSTREAM_URL"
        info "added upstream"
    else
        git remote set-url upstream "$UPSTREAM_URL"
        info "reset the upstream fetch URL"
    fi
    git remote set-url --push upstream "$UPSTREAM_PUSH_URL"
    git config remote.upstream.tagOpt --no-tags
    info "disabled upstream push and tag fetching"
    cmd-check
}

cmd-fetch() {
    git fetch --no-tags upstream
    cmd-status
}

cmd-status() {
    local baseline upstream_ref
    baseline=$(baseline-sha)
    upstream_ref=refs/remotes/upstream/main

    if ! git rev-parse --verify --quiet "$upstream_ref" >/dev/null; then
        info "upstream/main has not been fetched yet — run: script/upstream.sh fetch"
        return
    fi

    local counts
    counts=$(git rev-list --left-right --count "$upstream_ref...HEAD")
    info "upstream/main is at $(git rev-parse --short "$upstream_ref")"
    info "commits on upstream/main not in HEAD:  $(echo "$counts" | cut -f1)"
    info "commits on HEAD not in upstream/main:  $(echo "$counts" | cut -f2)"
    info "SceneMux-owned commits since baseline: $(git rev-list --count "$baseline..HEAD")"
}

case "${1:-check}" in
    check) cmd-check ;;
    history) cmd-history ;;
    setup) cmd-setup ;;
    fetch) cmd-fetch ;;
    status) cmd-status ;;
    *)
        echo "Usage: script/upstream.sh <check|history|setup|fetch|status>" >&2
        exit 1
        ;;
esac

if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed" >&2
    exit 1
fi
