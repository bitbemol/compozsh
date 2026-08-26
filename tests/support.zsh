# Minimal dependency-free test support for native Zsh configuration.

typeset -ga TEST_CASE_NAMES=()
typeset -ga TEST_CASE_FUNCTIONS=()
typeset -g TEST_TMP_DIR=''
typeset -gr TEST_ZSH_BIN=${commands[zsh]:-/bin/zsh}

test_case() {
  (( $# == 2 )) || {
    print -u2 -r -- 'test_case requires a description and function name'
    return 2
  }
  TEST_CASE_NAMES+=("$1")
  TEST_CASE_FUNCTIONS+=("$2")
}

test_fail() {
  print -u2 -r -- "      $*"
  return 1
}

test_assert_equal() {
  local expected=$1 actual=$2 label=${3:-values differ}
  [[ $actual == "$expected" ]] && return 0
  print -u2 -r -- "      ${label}"
  print -u2 -r -- "      expected: ${(qqq)expected}"
  print -u2 -r -- "      actual:   ${(qqq)actual}"
  return 1
}

test_assert_contains() {
  local text=$1 fragment=$2 label=${3:-missing expected text}
  [[ $text == *"$fragment"* ]] && return 0
  print -u2 -r -- "      ${label}: ${(qqq)fragment}"
  print -u2 -r -- "      actual: ${(qqq)text}"
  return 1
}

test_make_temp_dir() {
  local base=${TMPDIR:-/tmp}
  TEST_TMP_DIR=$(command mktemp -d "${base%/}/my-zsh-tests.XXXXXX") ||
    test_fail 'could not create a temporary test directory'
}

test_cleanup_temp() {
  [[ -n $TEST_TMP_DIR && -d $TEST_TMP_DIR &&
     ${TEST_TMP_DIR:t} == my-zsh-tests.* ]] || return 0
  command rm -rf -- "$TEST_TMP_DIR"
  TEST_TMP_DIR=''
}

test_write_file() {
  local file_path=$1 content=$2
  command mkdir -p "${file_path:h}" || return 1
  print -r -- "$content" >| "$file_path"
}

# Execute a completely isolated Zsh. Only the tool path and temporary home are
# inherited; the real user configuration and private add-ons are unreachable.
test_run_zsh() {
  local home=$1 mode=$2 script=$3
  shift 3
  command mkdir -p "$home" || return 1
  command env -i \
    PATH="$PATH" \
    HOME="$home" \
    ZDOTDIR="$home" \
    TERM=xterm-256color \
    TMPDIR="${TMPDIR:-/tmp}" \
    LC_ALL=C \
    "$TEST_ZSH_BIN" "$mode" -c "$script" tests "$@"
}

test_run_interactive() {
  local home=$1 script=$2
  shift 2
  test_run_zsh "$home" -dfi "$script" "$@"
}

test_run_noninteractive() {
  local home=$1 script=$2
  shift 2
  test_run_zsh "$home" -df "$script" "$@"
}
