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

@test "reverse alpha: --key=-a" {
  input=$'* a\n* b\n* z\n'
  expected=$'* z\n* b\n* a\n'
  output="$(printf "%s" "$input" | run_sort --key=-a)"
  assert_eq "$expected" "$output"
}

@test "TODO order wiht just DONE and TODO and blank" {
  # Hardcoded sequence in script:
  # TODO INPROGRESS NEEDSREVIEW WAITING HOLD SOMEDAY | DONE CANCELLED
  input=$'* DONE Trip to the moon\n* DONE Write blog post\n* TODO Plan vacation\n* TODO Learn Spanish\n* TODO Old project\n* DONE Some other thing\n'
  # Expect all "open" (TODO/SOMEDAY) before "closed" (DONE/CANCELLED),
  # preserving relative order within each group (no alpha unless we add --key=a)
  expected=$'* retard\n* TODO Learn Spanish\n* TODO Old project\n* TODO Plan vacation\n* DONE Some other thing\n* DONE Trip to the moon\n* DONE Write blog post\n'
  output="$(printf "%s" "$input" | run_sort --key=o)"
  assert_eq "$expected" "$output"
}

@test "TODO order: uses hardcoded sequence (o = TODO order)" {
  # Hardcoded sequence in script:
  # TODO INPROGRESS NEEDSREVIEW WAITING HOLD SOMEDAY | DONE CANCELLED
  input=$'* CANCELLED Trip to the moon\n* DONE Write blog post\n* TODO Plan vacation\n* SOMEDAY Learn Spanish\n* CANCELLED Old project\n* DONE Some other thing\n'
  # Expect all "open" (TODO/SOMEDAY) before "closed" (DONE/CANCELLED),
  # preserving relative order within each group (no alpha unless we add --key=a)
  expected=$'* TODO Plan vacation\n* SOMEDAY Learn Spanish\n* DONE Write blog post\n* DONE Some other thing\n* CANCELLED Old project\n* CANCELLED Trip to the moon\n'
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
  expected=$'** TODO two\n** SOMEDAY three\n** DONE one\n** CANCELLED four\n'
  output="$(printf "%s" "$input" | run_sort --key=o)"
  assert_eq "$expected" "$output"
}

@test "TODO order reversed: --key=-o" {
  input=$'* DONE A\n* TODO B\n* SOMEDAY C\n* CANCELLED D\n'
  expected=$'* DONE A\n* CANCELLED D\n* TODO B\n* SOMEDAY C\n'
  output="$(printf "%s" "$input" | run_sort --key=-o)"
  assert_eq "$expected" "$output"
}

@test "TODO then alpha inside groups: --key=o --key=a" {
  input=$'* SOMEDAY Zzz\n* TODO zebra\n* DONE b\n* TODO alpha\n* SOMEDAY beta\n* CANCELLED c\n'
  expected=$'* TODO alpha\n* TODO zebra\n* SOMEDAY beta\n* SOMEDAY Zzz\n* DONE b\n* CANCELLED c\n'
  output="$(printf "%s" "$input" | run_sort --key=o --key=a)"
  assert_eq "$expected" "$output"
}

@test "timestamp in headline (t = timestamp): ascending then reversed" {
  input=$'* A <2025-03-01 Sat>\n* B <2024-12-25 Wed>\n* C <2026-01-01 Thu>\n'
  expected_asc=$'* B <2024-12-25 Wed>\n* A <2025-03-01 Sat>\n* C <2026-01-01 Thu>\n'
  expected_desc=$'* C <2026-01-01 Thu>\n* A <2025-03-01 Sat>\n* B <2024-12-25 Wed>\n'
  out_asc="$(printf "%s" "$input" | run_sort --key=t)"
  out_desc="$(printf "%s" "$input" | run_sort --key=-t)"
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
  input=$'* A\n  DEADLINE: <2025-08-28 Thu>\n* B\n  DEADLINE: <2025-01-01 Wed>\n* C\n'
  expected=$'* B\n  DEADLINE: <2025-01-01 Wed>\n* A\n  DEADLINE: <2025-08-28 Thu>\n* C\n'
  output="$(printf "%s" "$input" | run_sort --key=d)"
  assert_eq "$expected" "$output"
}

@test "priority key (p): [#A] < [#B] < none" {
  input=$'* [#B] b\n* plain\n* [#A] a\n'
  expected=$'* [#A] a\n* [#B] b\n* plain\n'
  output="$(printf "%s" "$input" | run_sort --key=p)"
  assert_eq "$expected" "$output"
}

@test "handles buffers starting at level-2 (treats first heading level as sibling set)" {
  input=$'** z\n** a\n** b\n'
  expected=$'** a\n** b\n** z\n'
  output="$(printf "%s" "$input" | run_sort --key=a)"
  assert_eq "$expected" "$output"
}

@test "multi-key stability: o then -a (alpha descending within TODO buckets)" {
  input=$'* SOMEDAY A\n* SOMEDAY Z\n* TODO B\n* TODO A\n* DONE M\n* DONE Z\n'
  expected=$'* TODO Z\n* TODO A\n* SOMEDAY Z\n* SOMEDAY A\n* DONE Z\n* DONE M\n'
  output="$(printf "%s" "$input" | run_sort --key=o --key=-a)"
  assert_eq "$expected" "$output"
}
