_test_xcode_lazy_initial_dashboard_and_scheme_browsing() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local -i captures=0 actions=0 schemes=0
    _xcode_schemes_capture() { _XCODE_SCHEMES=(A B C) }
    _xcode_destinations_capture() {
      (( ++captures ))
      _XCODE_DESTINATION_IDS=(MAC-1)
      _XCODE_DESTINATION_PLATFORMS=(macOS)
      _XCODE_DESTINATION_NAMES=("My Mac")
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=MAC-1,arch=arm64")
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions")
          (( ++actions ))
          (( captures == 0 )) || {
            print -u2 "destination discovery blocked an unresolved Actions screen"; return 8
          }
          [[ $_XCODE_ACTION_CONTEXT != *MAC-1* ]] || return 9
          (( actions <= 3 )) || return 1
          _ZLE_PICKER_SELECTED_VALUE=scheme ;;
        ("Xcode / Scheme")
          (( ++schemes ))
          _ZLE_PICKER_SELECTED_VALUE=$(( schemes % 3 + 1 )) ;;
        (*) return 10 ;;
      esac
      return 0
    }
    _xcode_workspace_controller
    [[ $? == 1 && $actions == 4 && $captures == 0 ]] || exit 1
    print deferred
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal deferred "$output"
}
test_case 'Xcode lazy flow opens Actions and browses uncached schemes without destination discovery' \
  _test_xcode_lazy_initial_dashboard_and_scheme_browsing

_test_xcode_lazy_all_actions_resolve_exact_destination() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local request="" exact="platform=macOS,id=MAC-1,arch=x86_64,variant=Mac Catalyst"
    local -i captures=0 choices=0 dashboards=0
    _xcode_schemes_capture() { _XCODE_SCHEMES=(App) }
    _xcode_destinations_capture() {
      (( ++captures ))
      _XCODE_DESTINATION_IDS=(MAC-1 MAC-1)
      _XCODE_DESTINATION_PLATFORMS=(macOS macOS)
      _XCODE_DESTINATION_NAMES=("My Mac native" "My Mac Catalyst")
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=MAC-1,arch=arm64" "$exact")
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions")
          (( ++dashboards ))
          (( captures == 0 )) || { print -u2 "action $request discovered destinations eagerly"; return 8; }
          _ZLE_PICKER_SELECTED_VALUE=$request ;;
        ("Xcode / Destination")
          (( ++choices ))
          [[ ${_XCODE_PICKER_DETAILS[2]} == *"$exact"* ]] || return 9
          _ZLE_PICKER_SELECTED_VALUE=2 ;;
        (*) return 10 ;;
      esac
      return 0
    }
    for request in build rebuild test rebuild-test analyze clean run rebuild-run; do
      captures=0 choices=0 dashboards=0 _XCODE_REQUEST=""
      _xcode_workspace_controller || exit
      [[ $captures == 1 && $choices == 1 && $dashboards == 1 ]] || {
        print -u2 "action $request did not resolve exactly once"; exit 11
      }
      [[ $_XCODE_REQUEST == $request && $_XCODE_SELECTED_SCHEME == App &&
         $_XCODE_SELECTED_ID == MAC-1 && $_XCODE_SELECTED_PLATFORM == macOS &&
         $_XCODE_SELECTED_SPEC == "$exact" &&
         $_XCODE_SELECTED_DESTINATION == "My Mac Catalyst" ]] || exit 12
    done
    print exact-actions
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal exact-actions "$output"
}
test_case 'Xcode lazy flow resolves one explicitly chosen exact destination for every action' \
  _test_xcode_lazy_all_actions_resolve_exact_destination

_test_xcode_lazy_cancel_pending_action_and_switch_scheme() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local -a captures=()
    local -i dashboards=0 choices=0
    _XCODE_REQUEST=""
    _xcode_schemes_capture() { _XCODE_SCHEMES=(A B) }
    _xcode_destinations_capture() {
      captures+=("$3")
      _XCODE_DESTINATION_IDS=("$3-MAC")
      _XCODE_DESTINATION_PLATFORMS=(macOS)
      _XCODE_DESTINATION_NAMES=("$3 Mac")
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=$3-MAC,arch=arm64")
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions")
          (( ++dashboards ))
          case $dashboards in
            (1) _ZLE_PICKER_SELECTED_VALUE=run ;;
            (2)
              [[ -z $_XCODE_REQUEST && ${(j:|:)captures} == A ]] || return 8
              _ZLE_PICKER_SELECTED_VALUE=scheme ;;
            (3)
              [[ $_XCODE_ACTION_CONTEXT != *A-MAC* && ${(j:|:)captures} == A ]] || return 9
              _ZLE_PICKER_SELECTED_VALUE=clean ;;
            (*) return 10 ;;
          esac ;;
        ("Xcode / Scheme") _ZLE_PICKER_SELECTED_VALUE=2 ;;
        ("Xcode / Destination")
          (( ++choices ))
          (( choices == 1 )) && return 1
          [[ $2 == *B* ]] || return 11
          _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (*) return 12 ;;
      esac
      return 0
    }
    _xcode_workspace_controller || exit
    [[ $_XCODE_REQUEST == clean && $_XCODE_SELECTED_SCHEME == B &&
       $_XCODE_SELECTED_SPEC == "platform=macOS,id=B-MAC,arch=arm64" &&
       ${(j:|:)captures} == "A|B" && $choices == 2 ]] || exit 13
    print canceled-then-switched
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal canceled-then-switched "$output"
}
test_case 'Xcode lazy flow cancels pending action and never reuses another scheme destination' \
  _test_xcode_lazy_cancel_pending_action_and_switch_scheme

_test_xcode_lazy_destination_interrupt_never_dispatches() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    _XCODE_REQUEST=""
    _xcode_schemes_capture() { _XCODE_SCHEMES=(App) }
    _xcode_destinations_capture() {
      _XCODE_DESTINATION_IDS=(MAC-1)
      _XCODE_DESTINATION_PLATFORMS=(macOS)
      _XCODE_DESTINATION_NAMES=("My Mac")
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=MAC-1,arch=arm64")
    }
    _xcode_choose() {
      [[ $1 == "Xcode / Destination" ]] && return 130
      _ZLE_PICKER_SELECTED_VALUE=build
      return 0
    }
    _xcode_workspace_controller
    [[ $? == 130 && -z $_XCODE_REQUEST ]] || {
      print -u2 "interrupt during required destination selection dispatched an action"; exit 1
    }
    print interrupted
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal interrupted "$output"
}
test_case 'Xcode lazy flow propagates interrupted required destination selection without dispatch' \
  _test_xcode_lazy_destination_interrupt_never_dispatches

_test_xcode_lazy_reselect_same_scheme_keeps_exact_destination() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local exact="platform=macOS,id=MAC-1,arch=x86_64,variant=Mac Catalyst"
    local -i dashboards=0 captures=0 choices=0
    _xcode_schemes_capture() { _XCODE_SCHEMES=(App) }
    _xcode_destinations_capture() {
      (( ++captures ))
      _XCODE_DESTINATION_IDS=(MAC-1 MAC-1)
      _XCODE_DESTINATION_PLATFORMS=(macOS macOS)
      _XCODE_DESTINATION_NAMES=("My Mac native" "My Mac Catalyst")
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=MAC-1,arch=arm64" "$exact")
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions")
          (( ++dashboards ))
          case $dashboards in
            (1) _ZLE_PICKER_SELECTED_VALUE=destination ;;
            (2) _ZLE_PICKER_SELECTED_VALUE=scheme ;;
            (3) _ZLE_PICKER_SELECTED_VALUE=build ;;
            (*) return 8 ;;
          esac ;;
        ("Xcode / Scheme") _ZLE_PICKER_SELECTED_VALUE=1 ;;
        ("Xcode / Destination")
          (( ++choices ))
          _ZLE_PICKER_SELECTED_VALUE=2 ;;
        (*) return 9 ;;
      esac
      return 0
    }
    _xcode_workspace_controller || exit
    [[ $captures == 1 && $choices == 1 && $_XCODE_REQUEST == build &&
       $_XCODE_SELECTED_SPEC == "$exact" ]] || {
      print -u2 "reselecting the current scheme changed its explicitly chosen exact destination"; exit 10
    }
    print retained
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal retained "$output"
}
test_case 'Xcode lazy flow preserves the exact destination when reselecting the current scheme' \
  _test_xcode_lazy_reselect_same_scheme_keeps_exact_destination

_test_xcode_lazy_cached_choice_journey() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local mode=$2 exact="platform=macOS,id=A-MAC,arch=x86_64,variant=Mac Catalyst"
    local -a captures=()
    local -i dashboards=0 choices=0 schemes=0
    _XCODE_REQUEST=""
    _xcode_schemes_capture() { _XCODE_SCHEMES=(A B) }
    _xcode_destinations_capture() {
      captures+=("$3")
      if [[ $3 == A ]]; then
        _XCODE_DESTINATION_IDS=(A-MAC A-MAC)
        _XCODE_DESTINATION_PLATFORMS=(macOS macOS)
        _XCODE_DESTINATION_NAMES=("A native" "A Catalyst")
        _XCODE_DESTINATION_SPECS=("platform=macOS,id=A-MAC,arch=arm64" "$exact")
      else
        _XCODE_DESTINATION_IDS=(B-MAC)
        _XCODE_DESTINATION_PLATFORMS=(macOS)
        _XCODE_DESTINATION_NAMES=("B Mac")
        _XCODE_DESTINATION_SPECS=("platform=macOS,id=B-MAC,arch=arm64")
      fi
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions")
          (( ++dashboards ))
          case $dashboards in
            (1) _ZLE_PICKER_SELECTED_VALUE=run
                [[ $mode == selected ]] && _ZLE_PICKER_SELECTED_VALUE=destination ;;
            (2) _ZLE_PICKER_SELECTED_VALUE=scheme ;;
            (3) _ZLE_PICKER_SELECTED_VALUE=scheme
                [[ $mode == selected ]] && _ZLE_PICKER_SELECTED_VALUE=destination ;;
            (4) _ZLE_PICKER_SELECTED_VALUE=build
                [[ $mode == selected ]] && _ZLE_PICKER_SELECTED_VALUE=scheme ;;
            (5) _ZLE_PICKER_SELECTED_VALUE=build ;;
            (*) return 8 ;;
          esac ;;
        ("Xcode / Scheme")
          (( ++schemes ))
          _ZLE_PICKER_SELECTED_VALUE=$(( 3 - schemes )) ;;
        ("Xcode / Destination")
          (( ++choices ))
          [[ $mode == canceled && $choices == 1 ]] && return 1
          _ZLE_PICKER_SELECTED_VALUE=2
          [[ $2 == B ]] && _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (*) return 9 ;;
      esac
      return 0
    }
    _xcode_workspace_controller || exit
    [[ $_XCODE_REQUEST == build && $_XCODE_SELECTED_SCHEME == A &&
       $_XCODE_SELECTED_SPEC == "$exact" && $choices == 2 ]] || {
      print -u2 "$mode snapshot restoration lost the explicitly chosen destination state"; exit 10
    }
    if [[ $mode == canceled ]]; then
      [[ ${(j:|:)captures} == A ]] || exit 11
    else
      [[ ${(j:|:)captures} == "A|B" ]] || exit 12
    fi
    print retained-choice
  ' "$TEST_REPO_ROOT" "$1") || return
  test_assert_equal retained-choice "$output"
}
_test_xcode_lazy_canceled_snapshot_remains_unselected() {
  _test_xcode_lazy_cached_choice_journey canceled
}
test_case 'Xcode lazy flow never converts a canceled cached snapshot into destination consent' \
  _test_xcode_lazy_canceled_snapshot_remains_unselected

_test_xcode_lazy_cached_scheme_keeps_selected_exact_spec() {
  _test_xcode_lazy_cached_choice_journey selected
}
test_case 'Xcode lazy flow restores the explicitly selected destination across cached scheme visits' \
  _test_xcode_lazy_cached_scheme_keeps_selected_exact_spec

_test_xcode_lazy_refresh_selection_journey() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local mode=$2
    local -i dashboards=0 captures=0 choices=0
    _xcode_schemes_capture() { _XCODE_SCHEMES=(App) }
    _xcode_destinations_capture() {
      (( ++captures ))
      if [[ $mode == removed && $captures == 1 ]]; then
        _XCODE_DESTINATION_IDS=(MAC-old)
        _XCODE_DESTINATION_NAMES=("Old Mac")
      else
        _XCODE_DESTINATION_IDS=(MAC-new)
        _XCODE_DESTINATION_NAMES=("New Mac")
      fi
      _XCODE_DESTINATION_PLATFORMS=(macOS)
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=${_XCODE_DESTINATION_IDS[1]},arch=arm64")
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions")
          (( ++dashboards ))
          if (( dashboards == 1 )) && [[ $mode == removed ]]; then
            _ZLE_PICKER_SELECTED_VALUE=destination
          elif [[ $mode == unresolved && $dashboards == 1 || $mode == removed && $dashboards == 2 ]]; then
            _ZLE_PICKER_SELECTED_VALUE=refresh-destinations
          else
            _ZLE_PICKER_SELECTED_VALUE=build
          fi ;;
        ("Xcode / Destination")
          (( ++choices ))
          _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (*) return 8 ;;
      esac
      return 0
    }
    _xcode_workspace_controller || exit
    local -i expected=1
    [[ $mode == removed ]] && expected=2
    [[ $captures == $expected && $choices == $expected && $_XCODE_REQUEST == build &&
       $_XCODE_SELECTED_SPEC == "platform=macOS,id=MAC-new,arch=arm64" ]] || {
      print -u2 "$mode refresh silently selected a previously unchosen destination"; exit 9
    }
    print chosen-after-refresh
  ' "$TEST_REPO_ROOT" "$1") || return
  test_assert_equal chosen-after-refresh "$output"
}
_test_xcode_lazy_refresh_does_not_select_unresolved_destination() {
  _test_xcode_lazy_refresh_selection_journey unresolved
}
test_case 'Xcode lazy flow keeps an unresolved destination unselected after refresh' \
  _test_xcode_lazy_refresh_does_not_select_unresolved_destination

_test_xcode_lazy_refresh_does_not_replace_missing_selection() {
  _test_xcode_lazy_refresh_selection_journey removed
}
test_case 'Xcode lazy flow requires a new destination choice when refresh removes the selected one' \
  _test_xcode_lazy_refresh_does_not_replace_missing_selection

_test_xcode_lazy_failed_discovery_never_dispatches() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local mode=""
    local -i captures=0 dashboards=0 choices=0 result=0
    _xcode_schemes_capture() { _XCODE_SCHEMES=(App) }
    _xcode_destinations_capture() {
      (( ++captures ))
      _XCODE_DESTINATION_IDS=(MAC-1)
      _XCODE_DESTINATION_PLATFORMS=(macOS)
      _XCODE_DESTINATION_NAMES=("My Mac")
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=MAC-1,arch=arm64")
      if [[ $mode == initial || $captures == 2 ]]; then
        if [[ $mode == malformed ]]; then
          _XCODE_DESTINATION_SPECS=("platform=macOS,id=MAC-OTHER,arch=arm64")
          return 0
        fi
        _XCODE_CAPTURE_ERROR="native destination query failed"
        return 7
      fi
      return 0
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions")
          (( ++dashboards ))
          if [[ $mode == initial ]]; then
            _ZLE_PICKER_SELECTED_VALUE=run
          elif (( dashboards == 1 )); then
            _ZLE_PICKER_SELECTED_VALUE=destination
          elif (( dashboards == 2 )); then
            _ZLE_PICKER_SELECTED_VALUE=refresh-destinations
          else
            print -u2 "failed discovery returned stale selectable state"; return 9
          fi ;;
        ("Xcode / Destination")
          (( ++choices ))
          _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (*) return 10 ;;
      esac
      return 0
    }
    for mode in initial refresh malformed; do
      captures=0 dashboards=0 choices=0 _XCODE_REQUEST="" _XCODE_WORKSPACE_ERROR=""
      _xcode_workspace_controller
      result=$?
      [[ $result == 4 && -z $_XCODE_REQUEST && -n $_XCODE_WORKSPACE_ERROR ]] || {
        print -u2 "$mode destination failure dispatched or omitted failure"; exit 11
      }
      if [[ $mode == initial ]]; then
        [[ $captures == 1 && $choices == 0 ]] || exit 12
      else
        [[ $captures == 2 && $choices == 1 ]] || exit 13
      fi
    done
    print failed-safely
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal failed-safely "$output"
}
test_case 'Xcode lazy flow fails closed on initial discovery failed refresh and invalid refreshed identity' \
  _test_xcode_lazy_failed_discovery_never_dispatches

_test_xcode_lazy_pending_run_discloses_platform_effects() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local request=""
    _xcode_schemes_capture() { _XCODE_SCHEMES=(App) }
    _xcode_destinations_capture() {
      _XCODE_DESTINATION_IDS=(MAC-1 PHONE-1 SIM-1)
      _XCODE_DESTINATION_PLATFORMS=(macOS iOS "iOS Simulator")
      _XCODE_DESTINATION_NAMES=("My Mac" "My Phone" "My Simulator")
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=MAC-1,arch=arm64"
        "platform=iOS,id=PHONE-1,arch=arm64" "platform=iOS Simulator,id=SIM-1,arch=arm64")
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions") _ZLE_PICKER_SELECTED_VALUE=$request ;;
        ("Xcode / Destination")
          [[ $4 == action-destination ]] || {
            print -u2 "pending Run destination choice is marked read-only"; return 8
          }
          [[ ${_XCODE_PICKER_DETAILS[1]} == *"app remains running"* ]] || {
            print -u2 "pending Run omits Mac app lifetime"; return 9
          }
          [[ ${_XCODE_PICKER_DETAILS[2]} == *"replacing its installed copy"* ]] || {
            print -u2 "pending Run omits physical device app replacement"; return 10
          }
          [[ ${_XCODE_PICKER_DETAILS[3]} == *"Escape stops this run"* ]] || {
            print -u2 "pending Run omits Simulator stop behavior"; return 11
          }
          _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (*) return 12 ;;
      esac
      return 0
    }
    for request in run rebuild-run; do
      _xcode_workspace_controller || exit
      [[ $_XCODE_REQUEST == $request ]] || exit 13
    done
    print disclosed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal disclosed "$output"
}
test_case 'Xcode lazy flow discloses Mac device and Simulator effects before required Run destination consent' \
  _test_xcode_lazy_pending_run_discloses_platform_effects

_test_xcode_lazy_evicted_selection_requires_fresh_choice() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local -a captures=()
    local -i dashboards=0 schemes=0 choices=0
    _xcode_schemes_capture() {
      _XCODE_SCHEMES=("App [literal]" "App ] rest" "App \$dollar"
        "App \$(print executed > $HOME/evaluated)" "App * ?")
    }
    _xcode_destinations_capture() {
      captures+=("$3")
      local -i scheme_slot=${_XCODE_SCHEMES[(Ie)$3]}
      _XCODE_DESTINATION_IDS=("MAC-$scheme_slot")
      _XCODE_DESTINATION_PLATFORMS=(macOS)
      _XCODE_DESTINATION_NAMES=("$3 Mac")
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=MAC-$scheme_slot,arch=arm64")
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions")
          (( ++dashboards ))
          (( ${#_XCODE_DESTINATION_SELECTIONS} <= 4 )) || {
            print -u2 "chosen destinations outlived the bounded snapshot cache"; return 8
          }
          if (( dashboards == 10 )); then
            [[ -z ${_XCODE_DESTINATION_SELECTIONS[${_XCODE_SCHEMES[1]}]-} ]] || return 9
          fi
          if (( dashboards == 11 )); then
            _ZLE_PICKER_SELECTED_VALUE=build
          elif (( dashboards % 2 )); then
            _ZLE_PICKER_SELECTED_VALUE=destination
          else
            _ZLE_PICKER_SELECTED_VALUE=scheme
          fi ;;
        ("Xcode / Scheme")
          (( ++schemes ))
          _ZLE_PICKER_SELECTED_VALUE=$(( schemes % 5 + 1 )) ;;
        ("Xcode / Destination")
          (( ++choices ))
          _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (*) return 10 ;;
      esac
      return 0
    }
    _xcode_workspace_controller || exit
    [[ ${#captures} == 6 && $choices == 6 && ${captures[1]} == ${captures[6]} &&
       $_XCODE_REQUEST == build && $_XCODE_SELECTED_SCHEME == "App [literal]" &&
       $_XCODE_SELECTED_SPEC == "platform=macOS,id=MAC-1,arch=arm64" ]] || {
      print -u2 "evicted scheme reused destination discovery or consent"; exit 11
    }
    local -a _XCODE_DESTINATION_CACHE_SCHEMES=() _XCODE_DESTINATION_CACHE_IDS=()
    local -a _XCODE_DESTINATION_CACHE_PLATFORMS=() _XCODE_DESTINATION_CACHE_NAMES=()
    local -a _XCODE_DESTINATION_CACHE_SPECS=()
    local -A _XCODE_DESTINATION_SELECTIONS=()
    local literal=""
    for literal in "${_XCODE_SCHEMES[@]}"; do
      _xcode_destinations_capture project /example/App.xcodeproj "$literal" || exit
      _xcode_destination_cache_store "$literal" || exit
      _XCODE_DESTINATION_SELECTIONS[$literal]=${_XCODE_DESTINATION_SPECS[1]}
      _xcode_destination_cache_forget "$literal" || exit
      (( !${#_XCODE_DESTINATION_SELECTIONS} && !${#_XCODE_DESTINATION_CACHE_SCHEMES} )) || exit 12
    done
    [[ ! -e $HOME/evaluated ]] || { print -u2 "literal scheme was evaluated"; exit 13; }
    print freshly-chosen
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal freshly-chosen "$output"
}
test_case 'Xcode lazy flow releases evicted selections and requires fresh destination choice on return' \
  _test_xcode_lazy_evicted_selection_requires_fresh_choice

_test_xcode_lazy_destination_view_accept_labels() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.xcode"
    local label="" mode=action
    local -i seen=0
    local -a _XCODE_PICKER_VALUES=(1 2) _XCODE_PICKER_LABELS=("My Mac" "My Phone")
    local -a _XCODE_PICKER_SEARCH=("My Mac" "My Phone") _XCODE_PICKER_DETAILS=("Mac details" "Phone details")
    local _XCODE_PENDING_ACTION_LABEL=""
    _zle_picker_loop() {
      (( ++seen ))
      if [[ $mode == action ]]; then
        [[ $_ZLE_PICKER_BROWSE_LABEL == "Choose destination for $label" &&
           ${_ZLE_PICKER_ACCEPT_LABELS[1]} == ${label:l} &&
           ${_ZLE_PICKER_ACCEPT_LABELS[2]} == ${label:l} ]] || {
          print -u2 "required destination view hid its pending $label execution"; return 8
        }
        _xcode_picker_collect Phone 10
        [[ $_ZLE_PICKER_RESULTS[1] == 2 &&
           ${_ZLE_PICKER_ACCEPT_LABELS[$_ZLE_PICKER_RESULTS[1]]} == ${label:l} ]] || return 9
      else
        [[ $_ZLE_PICKER_BROWSE_LABEL == "read-only selection" &&
           -z ${_ZLE_PICKER_ACCEPT_LABELS[1]-} && -z ${_ZLE_PICKER_ACCEPT_LABELS[2]-} ]] || {
          print -u2 "read-only destination choice inherited pending execution labels"; return 10
        }
      fi
      return 1
    }
    for label in Build Rebuild Test "Rebuild & Test" Analyze Clean "Build & Run" "Rebuild & Run"; do
      _XCODE_PENDING_ACTION_LABEL=$label
      _xcode_choose "Xcode / Destination" App "Filter destinations" action-destination
      [[ $? == 1 ]] || exit 11
    done
    mode=choice
    _xcode_choose "Xcode / Destination" App "Filter destinations"
    [[ $? == 1 && $seen == 9 ]] || exit 12
    print labeled
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal labeled "$output"
}
test_case 'Xcode lazy flow renders pending action accept labels and clears them for read-only destination selection' \
  _test_xcode_lazy_destination_view_accept_labels

_test_xcode_lazy_cancel_refresh_under_shell_options() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local mode="" literal="App [literal] \$(never)" exact="platform=macOS,id=MAC-1,arch=x86_64,variant=Mac Catalyst"
    local -i dashboards=0 captures=0 choices=0 result=0
    _xcode_schemes_capture() { emulate -L zsh; _XCODE_SCHEMES=("$literal") }
    _xcode_destinations_capture() {
      emulate -L zsh
      (( ++captures ))
      _XCODE_DISCOVERY_CANCELLED=0
      if (( captures == 2 )); then
        _XCODE_DISCOVERY_CANCELLED=$mode
        _XCODE_CAPTURE_ERROR="Xcode discovery cancelled"
        return $mode
      fi
      _XCODE_DESTINATION_IDS=(MAC-1 MAC-1)
      _XCODE_DESTINATION_PLATFORMS=(macOS macOS)
      _XCODE_DESTINATION_NAMES=("My Mac native" "My Mac Catalyst")
      _XCODE_DESTINATION_SPECS=("platform=macOS,id=MAC-1,arch=arm64" "$exact")
    }
    _xcode_choose() {
      emulate -L zsh
      case $1 in
        ("Xcode / Actions")
          (( ++dashboards ))
          case $dashboards in
            (1) _ZLE_PICKER_SELECTED_VALUE=destination ;;
            (2) _ZLE_PICKER_SELECTED_VALUE=refresh-destinations ;;
            (3)
              [[ $_XCODE_ACTION_CONTEXT == *"$exact"* ]] || return 8
              _ZLE_PICKER_SELECTED_VALUE=build ;;
            (*) return 9 ;;
          esac ;;
        ("Xcode / Destination")
          (( ++choices ))
          _ZLE_PICKER_SELECTED_VALUE=2 ;;
        (*) return 10 ;;
      esac
      return 0
    }
    for mode in 1 130; do
      dashboards=0 captures=0 choices=0 _XCODE_REQUEST=""
      setopt SH_WORD_SPLIT RC_EXPAND_PARAM GLOB_SUBST KSH_ARRAYS NO_NOMATCH ERR_RETURN NO_CLOBBER NO_UNSET
      if _xcode_workspace_controller; then result=0; else result=$?; fi
      emulate -R zsh
      [[ $captures == 2 && $choices == 1 ]] || exit 11
      if [[ $mode == 1 ]]; then
        [[ $result == 0 && $_XCODE_REQUEST == build && $_XCODE_SELECTED_SCHEME == "$literal" &&
           $_XCODE_SELECTED_SPEC == "$exact" ]] || exit 12
      else
        [[ $result == 130 && -z $_XCODE_REQUEST ]] || exit 13
      fi
      (( !${+parameters[_XCODE_DESTINATION_SELECTIONS]} &&
         !${+parameters[_XCODE_DESTINATION_CACHE_SCHEMES]} )) || {
        print -u2 "workspace exit leaked a destination snapshot or selection"; exit 14
      }
    done
    print preserved-and-released
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved-and-released "$output"
}
test_case 'Xcode lazy flow preserves canceled refresh selection under unusual options and releases workspace cache' \
  _test_xcode_lazy_cancel_refresh_under_shell_options

_test_xcode_discovery_status_scope() {
  test_make_temp_dir || return
  test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/ui/.zsh.ui.zle_ui_view"
    source "$1/.zsh.addons/support/ui/.zsh.ui.zle_picker_capture"
    source "$1/.zsh.addons/support/ui/.zsh.ui.zle_picker_render"
    local result=0 expected="" loop_status=0 label_seen=""
    _zle_picker_loop() {
      [[ $_ZLE_PICKER_BUSY_LABEL == "Waiting for Xcode · Escape cancels" ]] || return 99
      return $loop_status
    }
    zle() { return 0; }
    _zle_picker_render() {
      _zle_picker_titlebar 120
      label_seen=$_ZLE_PICKER_TITLEBAR
    }
    _zle_picker_show() { return 0; }
    for loop_status in 0 1 130; do
      for expected in "" "Caller status"; do
        unset _ZLE_PICKER_BUSY_LABEL
        [[ -n $expected ]] && _ZLE_PICKER_BUSY_LABEL=$expected
        _zle_ui_view status _xcode_discovery_view "Loading schemes"
        result=$?
        [[ $result == $loop_status && ${_ZLE_PICKER_BUSY_LABEL-} == "$expected" ]] || {
          print -u2 -r -- "discovery leaked its busy label after status $loop_status"
          exit 1
        }
        [[ -n $expected || ${+_ZLE_PICKER_BUSY_LABEL} == 0 ]] || exit 2
        _zle_picker_capture Files "Filesystem · /example" demo true || exit 3
        [[ $label_seen == *Files* && $label_seen == *"${expected:-Searching…}"* &&
           $label_seen != *Xcode* && $label_seen != *"Escape cancels"* ]] || exit 4
      done
    done
  ' "$TEST_REPO_ROOT"
}
test_case 'Xcode discovery status stays scoped across completion cancellation abort and later Files capture' \
  _test_xcode_discovery_status_scope
