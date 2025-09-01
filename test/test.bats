#!/usr/bin/env bats

# Config
setup() {
  # Allow overriding which Emacs to use
  EMACS_BIN="${EMACS:-emacs}"
  SCRIPT="${SCRIPT:-./org-sort.el}"

  if [[ ! -f "$SCRIPT" ]]; then
    echo "Missing $SCRIPT (set SCRIPT=… if needed)" >&2
    exit 1
  fi
}

# Helpers
run_sort() {
  # Usage: run_sort --key=… [--key=…]
  # Reads stdin, writes stdout
  "$EMACS_BIN" -Q --script "$SCRIPT" -- "$@"
}

normalize() {
  # strip trailing spaces; ensure single final newline
  sed -e 's/[[:space:]]\+$//' -e '$a\' 
}

assert_eq() {  # $1 expected, $2 actual
  diff -u <(printf "%s" "$1" | normalize) <(printf "%s" "$2" | normalize)
}

@test "alpha: sorts simple top-level headings A→Z" {
  input=$'* z\n* a\n* b\n'
  expected=$'* a\n* b\n* z\n'
  output="$(printf "%s" "$input" | run_sort)"
  assert_eq "$expected" "$output"
}

@test "reverse alpha: --key=A" {
  input=$'* a\n* b\n* z\n'
  expected=$'* z\n* b\n* a\n'
  output="$(printf "%s" "$input" | run_sort --key=A)"
  assert_eq "$expected" "$output"
}

@test "TODO order with just DONE and TODO and blank" {
  # Hardcoded sequence in script:
  # TODO INPROGRESS NEEDSREVIEW WAITING HOLD SOMEDAY | DONE CANCELLED
  input=$'* DONE Trip to the moon\n* DONE Write blog post\n* TODO Plan vacation\n* TODO Learn Spanish\n* Retard\n* TODO Old project\n* DONE Some other thing\n'
  # Expect all "open" (TODO/SOMEDAY) before "closed" (DONE/CANCELLED),
  # preserving relative order within each group (no alpha unless we add --key=a)
  expected=$'* TODO Plan vacation\n* TODO Learn Spanish\n* TODO Old project\n* Retard\n* DONE Trip to the moon\n* DONE Write blog post\n* DONE Some other thing\n'
  output="$(printf "%s" "$input" | run_sort --key=o)"
  assert_eq "$expected" "$output"
}

@test "TODO order: uses hardcoded sequence of TODO states)" {
  # Hardcoded sequence in script:
  # TODO INPROGRESS NEEDSREVIEW WAITING HOLD SOMEDAY | DONE CANCELLED
  input=$'* CANCELLED Trip to the moon\n* DONE Write blog post\n* TODO Plan vacation\n* SOMEDAY Learn Spanish\n* CANCELLED Old project\n* DONE Some other thing\n'
  # Expect all "open" (TODO/SOMEDAY) before "closed" (DONE/CANCELLED),
  # preserving relative order within each group (no alpha unless we add --key=a)
  expected=$'* TODO Plan vacation\n* SOMEDAY Learn Spanish\n* CANCELLED Trip to the moon\n* CANCELLED Old project\n* DONE Write blog post\n* DONE Some other thing\n'
  output="$(printf "%s" "$input" | run_sort --key=o)"
  assert_eq "$expected" "$output"
}

@test "headings starting at level 2 are sorted correctly" {
  input=$'** z\n** a\n** b\n'
  expected=$'** a\n** b\n** z\n'
  output="$(printf "%s" "$input" | run_sort --key=a)"
  assert_eq "$expected" "$output"
}

@test "TODO order works with level 2 headings" {
  input=$'** DONE one\n** TODO two\n** SOMEDAY three\n** CANCELLED four\n'
  expected=$'** TODO two\n** SOMEDAY three\n** CANCELLED four\n** DONE one\n'
  output="$(printf "%s" "$input" | run_sort --key=o)"
  assert_eq "$expected" "$output"
}

@test "TODO order reversed: --key=O" {
  input=$'* DONE A\n* TODO B\n* SOMEDAY C\n* CANCELLED D\n'
  expected=$'* DONE A\n* CANCELLED D\n* SOMEDAY C\n* TODO B\n'
  output="$(printf "%s" "$input" | run_sort --key=O)"
  assert_eq "$expected" "$output"
}

@test "TODO then alpha inside groups: --key=o --key=a" {
  input=$'* SOMEDAY Zzz\n* TODO zebra\n* DONE b\n* TODO alpha\n* SOMEDAY beta\n* CANCELLED c\n'
  expected=$'* TODO alpha\n* TODO zebra\n* SOMEDAY beta\n* SOMEDAY Zzz\n* CANCELLED c\n* DONE b\n'
  output="$(printf "%s" "$input" | run_sort --key=o --key=a)"
  assert_eq "$expected" "$output"
}

@test "TODO then alpha inside groups: -k oa" {
  input=$'* SOMEDAY Zzz\n* TODO zebra\n* DONE b\n* TODO alpha\n* SOMEDAY beta\n* CANCELLED c\n'
  expected=$'* TODO alpha\n* TODO zebra\n* SOMEDAY beta\n* SOMEDAY Zzz\n* CANCELLED c\n* DONE b\n'
  output="$(printf "%s" "$input" | run_sort -k oa)"
  assert_eq "$expected" "$output"
}

@test "timestamp in headline (t = timestamp): ascending then reversed" {
  input=$'* A <2025-03-01 Sat>\n* B <2024-12-25 Wed>\n* C <2026-01-01 Thu>\n'
  expected_asc=$'* B <2024-12-25 Wed>\n* A <2025-03-01 Sat>\n* C <2026-01-01 Thu>\n'
  expected_desc=$'* C <2026-01-01 Thu>\n* A <2025-03-01 Sat>\n* B <2024-12-25 Wed>\n'
  out_asc="$(printf "%s" "$input" | run_sort --key=t)"
  out_desc="$(printf "%s" "$input" | run_sort --key=T)"
  assert_eq "$expected_asc" "$out_asc"
  assert_eq "$expected_desc" "$out_desc"
}

@test "scheduled key (s): uses SCHEDULED drawer if present" {
  input=$'* A\n  SCHEDULED: <2025-08-28 Thu>\n* B\n  SCHEDULED: <2025-01-01 Wed>\n* C\n'
  expected=$'* B\n  SCHEDULED: <2025-01-01 Wed>\n* A\n  SCHEDULED: <2025-08-28 Thu>\n* C\n'
  output="$(printf "%s" "$input" | run_sort --key=s)"
  assert_eq "$expected" "$output"
}

@test "deadline key (d): uses DEADLINE drawer if present" {
  skip
  input=$'* A\n  DEADLINE: <2025-08-28 Thu>\n* B\n  DEADLINE: <2025-01-01 Wed>\n* C\n'
  expected=$'* B\n  DEADLINE: <2025-01-01 Wed>\n* A\n  DEADLINE: <2025-08-28 Thu>\n* C\n'
  output="$(printf "%s" "$input" | run_sort --key=d)"
  assert_eq "$expected" "$output"
}

@test "priority key (p): [#A] < [#B] < none" {
  skip
  input=$'* [#B] b\n* plain\n* [#A] a\n'
  expected=$'* [#A] a\n* [#B] b\n* plain\n'
  output="$(printf "%s" "$input" | run_sort --key=p)"
  assert_eq "$expected" "$output"
}

@test "handles buffers starting at level-2 (treats first heading level as sibling set)" {
  skip
  input=$'** z\n** a\n** b\n'
  expected=$'** a\n** b\n** z\n'
  output="$(printf "%s" "$input" | run_sort --key=a)"
  assert_eq "$expected" "$output"
}

@test "multi-key stability: o then -a (alpha descending within TODO buckets)" {
  skip
  input=$'* SOMEDAY A\n* SOMEDAY Z\n* TODO B\n* TODO A\n* DONE M\n* DONE Z\n'
  expected=$'* TODO Z\n* TODO A\n* SOMEDAY Z\n* SOMEDAY A\n* DONE Z\n* DONE M\n'
  output="$(printf "%s" "$input" | run_sort --key=o --key=-a)"
  assert_eq "$expected" "$output"
}
