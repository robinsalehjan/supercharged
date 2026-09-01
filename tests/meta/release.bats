#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  RELEASE_SCRIPT="$PROJECT_ROOT/scripts/release.sh"
}

teardown() {
  teardown_test_env
}

# release.sh preflights a clean tree and an in-sync origin, so it is exercised
# against a throwaway repository with a bare remote rather than the checkout the
# tests happen to be running in.
#
# The script resolves its version with `node`. setup_test_env repoints HOME at a
# temp directory, which hides an asdf-managed node, so the real HOME is passed
# back in for the invocation only.
run_release() {
  run env HOME="$ORIGINAL_HOME" "$FIXTURE_REPO/scripts/release.sh" "$@"
}

make_fixture_repo() {
  FIXTURE_REPO="$TEST_TEMP_DIR/repo"
  mkdir -p "$FIXTURE_REPO/scripts/utils"
  cp "$PROJECT_ROOT/scripts/release.sh" "$FIXTURE_REPO/scripts/"
  cp "$PROJECT_ROOT/scripts/utils.sh" "$FIXTURE_REPO/scripts/"
  cp "$PROJECT_ROOT"/scripts/utils/*.sh "$FIXTURE_REPO/scripts/utils/"

  printf '%s\n' '{"name":"supercharged","version":"1.3.0"}' > "$FIXTURE_REPO/package.json"
  printf '%s\n' '{"name":"supercharged","version":"1.3.0","lockfileVersion":3,"packages":{"":{"version":"1.3.0"}}}' \
    > "$FIXTURE_REPO/package-lock.json"
  cat > "$FIXTURE_REPO/README.md" <<'EOF'
# supercharged

```bash
git clone --branch v1.3.0 --depth 1 git@github.com:robinsalehjan/supercharged.git
cd supercharged && npm run setup
```
EOF

  git -C "$FIXTURE_REPO" init -q -b main
  git -C "$FIXTURE_REPO" config user.email "test@example.com"
  git -C "$FIXTURE_REPO" config user.name "Test"
  git -C "$FIXTURE_REPO" add -A
  git -C "$FIXTURE_REPO" commit -qm "initial"

  git init -q --bare "$TEST_TEMP_DIR/origin.git"
  git -C "$FIXTURE_REPO" remote add origin "$TEST_TEMP_DIR/origin.git"
  git -C "$FIXTURE_REPO" push -q -u origin main
}

@test "release.sh is executable" {
  [ -x "$RELEASE_SCRIPT" ]
}

@test "release.sh requires a bump argument" {
  run "$RELEASE_SCRIPT" --dry-run

  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing bump argument"* ]]
}

@test "release.sh rejects an invalid bump" {
  make_fixture_repo

  run_release --dry-run sideways

  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid bump"* ]]
}

@test "release.sh computes the next version without writing" {
  make_fixture_repo

  run_release --dry-run minor

  [ "$status" -eq 0 ]
  [[ "$output" == *"Current version: 1.3.0"* ]]
  [[ "$output" == *"New version: 1.4.0 (tag: v1.4.0)"* ]]
  [[ "$output" == *"Dry run"* ]]
  [ "$(node -p "require('$FIXTURE_REPO/package.json').version")" = "1.3.0" ]
  grep -Fq 'git clone --branch v1.3.0 ' "$FIXTURE_REPO/README.md"
}

@test "release.sh refuses to release from a dirty tree" {
  make_fixture_repo
  printf 'dirty\n' > "$FIXTURE_REPO/stray.txt"
  git -C "$FIXTURE_REPO" add stray.txt

  run_release --yes patch

  [ "$status" -ne 0 ]
  [[ "$output" == *"Working tree not clean"* ]]
}

@test "release.sh bumps the version, rewrites the README pin, and tags" {
  make_fixture_repo

  run_release --yes minor

  [ "$status" -eq 0 ]
  [ "$(node -p "require('$FIXTURE_REPO/package.json').version")" = "1.4.0" ]
  # The Quick Start clone must advertise the tag being released.
  grep -Fq 'git clone --branch v1.4.0 --depth 1 git@github.com:robinsalehjan/supercharged.git' \
    "$FIXTURE_REPO/README.md"
  [ "$(grep -c 'v1.3.0' "$FIXTURE_REPO/README.md")" -eq 0 ]
  # Surrounding README content is untouched.
  grep -Fq 'cd supercharged && npm run setup' "$FIXTURE_REPO/README.md"
  # Tag and commit reached the remote.
  git -C "$FIXTURE_REPO" rev-parse v1.4.0 >/dev/null
  git -C "$TEST_TEMP_DIR/origin.git" rev-parse v1.4.0 >/dev/null
  git -C "$FIXTURE_REPO" log -1 --pretty=%s | grep -Fq 'chore(release): v1.4.0'
}

@test "release.sh refuses to reuse an existing tag" {
  make_fixture_repo
  git -C "$FIXTURE_REPO" tag -a v1.4.0 -m "existing"

  run_release --yes minor

  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "the README Quick Start tag matches the tracked package version" {
  readme="$PROJECT_ROOT/README.md"
  version=$(node -p "require('$PROJECT_ROOT/package.json').version")

  pinned=$(grep -oE '^git clone --branch v[0-9]+\.[0-9]+\.[0-9]+ ' "$readme" | awk '{print $4}')

  [ "$pinned" = "v$version" ]
}

@test "the release workflow pins action-gh-release to an immutable SHA" {
  workflow="$PROJECT_ROOT/.github/workflows/release.yml"

  run grep -E 'uses: softprops/action-gh-release@[a-f0-9]{40} # v[0-9]+\.[0-9]+\.[0-9]+' "$workflow"
  [ "$status" -eq 0 ]
}
