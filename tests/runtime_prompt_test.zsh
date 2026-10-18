# Integration coverage for requirement capture and ordinary prompt presentation.
_test_runtime_prompt_go_workspace() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/go.work" $'go 1.24.0\nuse ./service\n' || return
  test_write_file "$TEST_TMP_DIR/project/service/go.mod" $'module example.invalid/service\ngo 1.24.0\n' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    builtin cd "$2" || exit 1
    _prompt_runtime_version() { REPLY=1.23.0; }
    local phase name
    for phase in ordinary saturated; do
      if [[ $phase == saturated ]]; then
        for name in {1..130}; do : > "entry-$name"; done
      fi
      _prompt_project_context
      [[ $_PROMPT_PROJECT_ROOT_TEXT == "$2" ]] || {
        print -u2 -- "$phase: workspace root not retained"; exit 2
      }
      [[ ${(j:|:)_PROMPT_PROJECT_ITEMS} == *"go requires ≥ 1.24.0 · using 1.23.0 — older"* ]] || {
        print -u2 -- "$phase: workspace minimum warning absent"; exit 3
      }
    done
    print detected
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/project") || return
  test_assert_equal detected "$output"
}
test_case 'runtime prompt detects Go workspace requirements in ordinary and saturated roots' _test_runtime_prompt_go_workspace

_test_runtime_prompt_ready_toolchain() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/Package.swift" '// fixture' || return
  test_write_file "$TEST_TMP_DIR/project/.swift-version" '6.3.2' || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    TERM=dumb
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    builtin cd "$2" || exit 1
    _prompt_runtime_version() { REPLY=6.4; }
    COLUMNS=199 LINES=47 BUFFER=""
    _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 2
    BUFFER=ls
    _prompt_interaction_update || :
    _prompt_prepare_transcript
    BUFFER=""
    _prompt_update
    local rendered row version_start path_start columns escape
    printf -v escape "\033"
    print -P -v rendered -r -- "$PROMPT"
    setopt extendedglob
    rendered=${rendered//$escape\[[0-9\;]##m/}
    [[ $_PROMPT_VIEW == compact && $rendered == *READY* &&
       $rendered == *TOOLCHAIN*"swift 6.4"* &&
       $rendered == *"using 6.4 — newer"* ]] || {
      print -u2 -- "READY lost captured toolchain or warning"; exit 3
    }
    for row in "${(@f)rendered}"; do
      [[ $row != *TOOLCHAIN* ]] || version_start=${row%%swift*}
      [[ $row != *PATH* ]] || path_start=${row%%/*}
    done
    (( ${#version_start} == ${#path_start} )) || {
      print -u2 -- "toolchain and ordinary values use different columns"; exit 4
    }
    # Repaint/resize only consumes captured values, including a cleared draft.
    _prompt_project_context() { print -u2 unexpected-project-read; return 99; }
    _runtime_read_metadata() { print -u2 unexpected-metadata-read; return 99; }
    _prompt_runtime_version() { print -u2 unexpected-runtime-read; return 99; }
    for columns in 40 20 199; do
      COLUMNS=$columns
      _prompt_interaction_update || :
      print -P -v rendered -r -- "$PROMPT"
      rendered=${rendered//$escape\[[0-9\;]##m/}
      for row in "${(@f)rendered}"; do
        (( ${(m)#row} <= COLUMNS )) || exit 5
      done
    done
    [[ $rendered == *"using 6.4 — newer"* ]] || exit 6
    # The added row must not displace an existing last outcome in a tall view.
    _PROMPT_GIT_TEXT="main" _PROMPT_ENV_TEXT="fixture-env"
    _PROMPT_LAST_OUTCOME_TEXT="× exit 1"
    _prompt_interaction_update || :
    [[ $PROMPT == *TOOLCHAIN* && $PROMPT == *LAST*"× exit 1"* &&
       $PROMPT == *ENV*fixture-env* ]] || {
      print -u2 "toolchain displaced existing outcome/environment"; exit 8
    }
    _PROMPT_PROJECT_ITEMS=() _PROMPT_PROJECT_ITEM_WIDTHS=()
    _prompt_interaction_update || :
    [[ $PROMPT != *TOOLCHAIN* ]] || exit 7
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/project"
}
test_case 'runtime prompt retains toolchain in READY after acceptance and captured-only resize' _test_runtime_prompt_ready_toolchain

_test_runtime_prompt_native_clear() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/project/Package.swift" '// fixture' || return
  test_write_file "$TEST_TMP_DIR/home/project/.swift-version" '6.3.2' || return
  command mkfifo "$TEST_TMP_DIR/home/events" || return
  test_write_file "$TEST_TMP_DIR/home/.zshrc" '
HISTFILE=/dev/null
exec {event_fd}<> "$HOME/events"
source "$RUNTIME_TEST_ROOT/.zsh.addons/.zsh.prompt"
source "$RUNTIME_TEST_ROOT/.zsh.addons/.zsh.editor"
for support_component in "$RUNTIME_TEST_ROOT/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
source "$RUNTIME_TEST_ROOT/.zsh.addons/support/.zsh.appearance"
_prompt_runtime_version() { REPLY=6.4; }
_runtime_frame() {
  local visible=0
  [[ $PROMPT == *TOOLCHAIN* && $PROMPT == *"using 6.4 — newer"* ]] && visible=1
  print -r -u $event_fd -- "FRAME|$BUFFER|$_PROMPT_VIEW|$_PROMPT_INTERACTION_KIND|$visible|$COLUMNS"
}
add-zle-hook-widget line-pre-redraw _runtime_frame
add-zle-hook-widget line-init _runtime_frame
zle -N runtime-probe _runtime_frame
bindkey "^X^Z" runtime-probe
print -r -u $event_fd -- "SOURCE|$(command tty)"
' || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8 RUNTIME_TEST_ROOT=$2
    source "$2/tests/pty_support.zsh" || exit 9
    exec {event_fd}<> "$HOME/events"
    local event="" trace="" device=""
    _runtime_driver() {
      builtin cd "$HOME/project"
      command stty rows 30 cols 199
      exec "$1" -di
    }
    _runtime_expect() {
      { test_pty_expect ${2:+-p} runtime-clear $event_fd "$1" } always {
        trace+=$TEST_PTY_OUTPUT
        (( ${#TEST_PTY_EVENTS} )) && event=${TEST_PTY_EVENTS[-1]}
      }
    }
    test_pty_start runtime-clear _runtime_driver "$1"
    {
      _runtime_expect "SOURCE|" prefix
      device=${event#SOURCE|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 1
      _runtime_expect "FRAME||lens|ready|1|199" || exit 2
      zpty -w -n runtime-clear ls
      _runtime_expect "FRAME|ls|compact|run|0|199" || exit 3
      zpty -w -n runtime-clear $'"'"'\r'"'"'
      _runtime_expect "FRAME||compact|ready|1|199" || exit 4
      zpty -w runtime-clear clear
      _runtime_expect "FRAME||compact|ready|1|199" || exit 5
      command stty rows 16 cols 40 < "$device"
      zpty -w -n runtime-clear $'"'"'\x18\x1a'"'"'
      _runtime_expect "FRAME||compact|ready|0|40" || exit 6
      command stty rows 30 cols 199 < "$device"
      zpty -w -n runtime-clear $'"'"'\x18\x1a'"'"'
      _runtime_expect "FRAME||compact|ready|1|199" || exit 7
      [[ $trace == *TOOLCHAIN* && $trace == *"using 6.4 — newer"* &&
         $trace != *"command not found"* && $trace != *"bad pattern"* ]] || exit 8
    } always {
      zpty -d runtime-clear
      exec {event_fd}>&-
    }
  ' "$TEST_ZSH_BIN" "$TEST_REPO_ROOT"
}
test_case 'runtime prompt native command clear and resize preserve READY toolchain' _test_runtime_prompt_native_clear

# Build each `name=file,dir/,...` fixture under a fresh project folder, run
# the detector there and print `name=items` with neutral color syntax
# removed. A `saturated-` fixture also gets 129 padding entries, which pushes
# its root onto the bounded saturated path.
_test_prompt_project_matrix() {
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    _prompt_runtime_version() { REPLY=1; }
    local root=$2 spec name file items
    local -a files
    shift 2
    for spec in "$@"; do
      name=${spec%%=*}
      files=("$root/$name/"${^${(s:,:)spec#*=}})
      [[ $name == saturated-* ]] && files+=("$root/$name/pad-"{1..129})
      command mkdir -p -- "$root/$name" ${${(M)files:#*/}%/} ${${files:#*/}:h} || exit 1
      for file in ${files:#*/}; do : >| "$file"; done
      builtin cd -- "$root/$name" || exit 2
      _prompt_project_context
      items=${(j:,:)_PROMPT_PROJECT_ITEMS}
      print -r -- "$name=${${items//\%F\{default\}/}//\%f/}"
    done
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/matrix" "$@"
}

# Characterize the merged, ordered project items that root and conventional
# folder language rules produce. `mix.exs` adds a marker-only language that is
# always last in rule order, so a language the rules miss but the resolver
# still reports would move behind it and change the pinned order. The
# `literal-*[x]` folder name pins that pattern characters in the project path
# stay literal.
_test_prompt_project_detection_rules() {
  test_make_temp_dir || return
  local rule='' folder='' extension='' language='' name='' expected_text=''
  local output=''
  local -a specs=() expected=()
  local -a rules=(
    .:c:c-cpp .:cc:c-cpp .:cpp:c-cpp .:cxx:c-cpp .:hh:c-cpp .:hpp:c-cpp .:hxx:c-cpp
    .:asm:asm .:s:asm .:S:asm .:scm:scheme .:ss:scheme .:rkt:racket
    .:lisp:lisp .:cl:lisp .:asd:lisp .:mm:objective-c .:swift:swift
    .:php:php .:ps1:powershell .:psm1:powershell .:psd1:powershell
    .:kt:kotlin .:kts:kotlin .:lua:lua .:rockspec:lua .:R:r .:Rmd:r .:Rproj:r
    .:zig:zig .:tf:terraform .:jl:julia .:pl:perl .:pm:perl
    .:f:fortran .:f90:fortran .:f95:fortran .:f03:fortran
    .:ml:ocaml .:mli:ocaml .:opam:ocaml .:scala:scala .:erl:erlang .:hrl:erlang
    .:groovy:groovy .:ipynb:python .:cabal:haskell .:gemspec:ruby .:java:java
    .:csproj:dotnet .:fsproj:fsharp .:fs:fsharp .:vbproj:visual-basic .:vb:visual-basic
    .:sln:dotnet .:slnx:dotnet
  )
  for folder in src source Sources lib app; do
    for extension in c cc cpp cxx hh hpp hxx; do
      rules+=("${folder}:${extension}:c-cpp")
    done
    for extension in asm s S; do
      rules+=("${folder}:${extension}:asm")
    done
  done
  for folder in src source lib; do
    for extension in scm:scheme ss:scheme rkt:racket lisp:lisp cl:lisp asd:lisp; do
      rules+=("${folder}:${extension}")
    done
  done
  for folder in src source Sources app; do
    rules+=("${folder}:mm:objective-c" "${folder}:swift:swift")
  done
  rules+=(
    include:hh:c-cpp include:hpp:c-cpp include:hxx:c-cpp
    src:php:php app:php:php public:php:php
    src:ps1:powershell src:psm1:powershell src:psd1:powershell
    scripts:ps1:powershell scripts:psm1:powershell scripts:psd1:powershell
    modules:ps1:powershell modules:psm1:powershell modules:psd1:powershell
    src:kt:kotlin app:kt:kotlin src:lua:lua lua:lua:lua lib:lua:lua
    R:R:r src:R:r scripts:R:r notebooks:Rmd:r
    src:zig:zig source:zig:zig src:jl:julia scripts:jl:julia
    lib:pl:perl bin:pl:perl script:pl:perl scripts:pl:perl lib:pm:perl bin:pm:perl
    src:ml:ocaml src:mli:ocaml lib:ml:ocaml lib:mli:ocaml
    src:scala:scala app:scala:scala
    src:erl:erlang src:hrl:erlang include:erl:erlang include:hrl:erlang
    src:groovy:groovy app:groovy:groovy notebooks:ipynb:python
    src:java:java app:java:java src:fs:fsharp app:fs:fsharp
    src:vb:visual-basic app:vb:visual-basic
  )
  for folder in src source app; do
    for extension in f f90 f95 f03; do
      rules+=("${folder}:${extension}:fortran")
    done
  done

  for rule in "${rules[@]}"; do
    folder=${rule%%:*}
    extension=${${rule#*:}%%:*}
    language=${rule##*:}
    name="rule-${folder//./root}-$extension"
    specs+=("$name=$folder/x.$extension,mix.exs")
    case $extension in
      (ipynb) expected+=("$name=$language 1,elixir 1,mix,jupyter") ;;
      (rockspec) expected+=("$name=$language 1,elixir 1,mix,luarocks") ;;
      (cabal) expected+=("$name=$language 1,elixir 1,cabal,mix") ;;
      (opam) expected+=("$name=$language 1,elixir 1,mix,opam") ;;
      (sln|slnx) expected+=("$name=$language 1,elixir 1,solution,mix") ;;
      (asd) [[ $folder == . ]] &&
          expected+=("$name=$language 1,elixir 1,mix,asdf") ||
          expected+=("$name=$language 1,elixir 1,mix") ;;
      (*) expected+=("$name=$language 1,elixir 1,mix") ;;
    esac
  done
  specs+=(
    'tf-json=x.tf.json,mix.exs'
    'hidden=.x.c,src/.x.swift,lib/.x.lua,bin/.x.sh,mix.exs'
    'tuist=Project.swift,Workspace.swift,Tuist.swift,src/Project.swift,mix.exs'
    'package-swift=Package.swift,mix.exs'
    'build-gradle-kts=build.gradle.kts,mix.exs'
    'settings-gradle-kts=settings.gradle.kts,mix.exs'
    'xmake=xmake.lua,src/xmake.lua,lua/xmake.lua,mix.exs'
    'bare-m=x.m,mix.exs'
    'xcode-m=X.xcodeproj/,x.m,mix.exs'
    'lib-php=lib/x.php,mix.exs'
    'public-c=public/x.c,mix.exs'
    'src-kts=src/x.kts,mix.exs'
    'src-h=src/x.h,mix.exs'
    'polyglot=src/x.c,Sources/x.swift,x.php,lib/x.pl,notebooks/x.ipynb,app/x.java,x.vb,lua/x.lua,mix.exs'
    'shell-root=.git/,x.sh'
    'shell-src=.git/,src/x.sh'
    'shell-bin=.git/,bin/x.sh'
    'shell-scripts=.git/,scripts/x.sh'
    'shell-lib=.git/,lib/x.sh'
    'shell-make=Makefile,x.sh'
    'shell-hidden=.git/,.x.sh'
    'literal-*[x]=src/x.c,Project.swift,lib/x.lua,mix.exs'
  )
  expected+=(
    'tf-json=terraform 1,elixir 1,mix'
    'hidden=elixir 1,mix'
    'tuist=elixir 1,mix'
    'package-swift=swift 1,elixir 1,swiftpm,mix'
    'build-gradle-kts=elixir 1,gradle,mix'
    'settings-gradle-kts=elixir 1,kotlin 1,gradle,mix'
    'xmake=elixir 1,mix,xmake'
    'bare-m=elixir 1,objective-c 1,mix'
    'xcode-m=objective-c 1,elixir 1,xcode,mix'
    'lib-php=elixir 1,php 1,mix'
    'public-c=elixir 1,c-cpp 1,mix'
    'src-kts=elixir 1,kotlin 1,mix'
    'src-h=elixir 1,mix'
    'polyglot=c-cpp 1,swift 1,php 1,lua 1,perl 1,python 1,java 1,visual-basic 1,elixir 1,mix,jupyter'
    'shell-root=shell 1'
    'shell-src=shell 1'
    'shell-bin=shell 1'
    'shell-scripts=shell 1'
    'shell-lib=shell 1'
    'shell-make=make'
    'shell-hidden='
    'literal-*[x]=c-cpp 1,lua 1,elixir 1,mix'
  )

  output=$(_test_prompt_project_matrix "${specs[@]}") || return
  expected_text=${(F)expected}
  test_assert_equal "$expected_text" "$output"
}
test_case 'prompt project detection characterizes root and conventional-folder language rules' \
  _test_prompt_project_detection_rules

# A conventional folder holding more rule candidates than one bounded listing
# keeps exact evidence for every rule. The rule table is replaced with
# extensions outside the resolver's source sample, so the root stays on the
# ordinary path. `zone.vue` must still be found among 2,000 `.tsx` files;
# both APFS (hash) and sorted directory order list it after the first 129.
_test_prompt_project_detection_dense_folder() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    _prompt_runtime_version() { REPLY=1; }
    _PROMPT_PROJECT_RULES=("language:tsx g:src/*.tsx" "language:vue g:src/*.vue")
    local root=$2
    local -i i=0
    command mkdir -p -- "$root/src" || exit 1
    : >| "$root/package.json" && : >| "$root/src/zone.vue" || exit 1
    for (( i = 1; i <= 2000; i++ )); do : >| "$root/src/x-$i.tsx" || exit 1; done
    builtin cd -- "$root" || exit 2
    _prompt_project_context
    print -r -- "${${(j:,:)_PROMPT_PROJECT_ITEMS//\%F\{default\}/}//\%f/}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/dense") || return
  test_assert_equal 'tsx 1,vue 1' "$output"
}
test_case 'prompt project detection stays exact in a dense conventional folder' \
  _test_prompt_project_detection_dense_folder
# Characterize marker-driven languages, tools, frameworks and environment
# signals, one fixture each. Every fixture holds `.git/` and `x.sh`, so the
# shell fallback also shows whether the markers made the folder a recognized
# project. `saturated-` fixtures pin the bounded manifest-only path.
_test_prompt_project_detection_markers() {
  test_make_temp_dir || return
  local pair='' output='' expected_text=''
  local -i index=0
  local -a specs=() expected=()
  local -a pairs=(
    'package.json|node 1'
    'tsconfig.json|typescript 1'
    'deno.json|deno 1'
    'deno.jsonc|deno 1'
    'composer.json|php 1,composer'
    'composer.lock|php 1,composer'
    'DESCRIPTION|r 1'
    'renv.lock|r 1,renv'
    'build.zig|zig 1'
    'project.godot|gdscript 1'
    '.terraform.lock.hcl|terraform 1'
    'JuliaProject.toml|julia 1'
    'Project.toml|julia 1'
    'Manifest.toml|julia 1'
    'cpanfile|perl 1,cpan'
    'Makefile.PL|perl 1,cpan'
    'Build.PL|perl 1,cpan'
    'fpm.toml|fortran 1,fpm'
    'dune-project|ocaml 1,dune'
    'build.sbt|scala 1,sbt'
    'build.sc|scala 1,mill'
    'rebar.config|erlang 1,rebar3'
    'gleam.toml|gleam 1'
    'pyproject.toml|python 1'
    'setup.py|python 1'
    'setup.cfg|python 1'
    'requirements.txt|python 1,pip'
    'Pipfile|python 1,pipenv'
    'poetry.lock|python 1,poetry'
    'pdm.lock|python 1,pdm'
    'hatch.toml|python 1,hatch'
    'environment.yml|python 1,conda'
    'environment.yaml|python 1,conda'
    'mkdocs.yml|python 1,mkdocs'
    'mkdocs.yaml|python 1,mkdocs'
    'uv.lock|python 1,uv'
    '.python-version|python 1'
    'stack.yaml|haskell 1,stack'
    'cabal.project|haskell 1,cabal'
    'Cargo.toml|rust 1,cargo'
    'go.mod|go 1,go-modules'
    'go.work|go 1,workspace'
    'Gemfile|ruby 1,bundler'
    '.ruby-version|ruby 1'
    'global.json|dotnet 1'
    'pubspec.yaml|dart 1,pub'
    '.zshrc|zsh 1'
    'CMakeLists.txt|cmake'
    'meson.build|meson'
    'configure.ac|autotools'
    'configure.in|autotools'
    'MODULE.bazel|bazel'
    'WORKSPACE|bazel'
    'WORKSPACE.bazel|bazel'
    'conanfile.py|conan'
    'conanfile.txt|conan'
    'vcpkg.json|vcpkg'
    'xmake.lua|xmake'
    'X.xcodeproj/|xcode'
    'X.xcworkspace/|xcode,xcworkspace'
    'pom.xml|maven'
    'build.gradle|gradle'
    'build.gradle.kts|gradle'
    'settings.gradle|gradle'
    'settings.gradle.kts|kotlin 1,gradle'
    'terragrunt.hcl|terragrunt'
    'Pulumi.yaml|pulumi'
    'Chart.yaml|helm'
    'kustomization.yaml|kustomize'
    'kustomization.yml|kustomize'
    'serverless.yml|serverless'
    'serverless.yaml|serverless'
    'pixi.toml|pixi'
    'pixi.lock|shell 1,pixi'
    'melos.yaml|melos,workspace'
    'melos.yml|melos,workspace'
    '_quarto.yml|quarto'
    '_quarto.yaml|quarto'
    'Makefile|make'
    'makefile|make'
    'GNUmakefile|make'
    'build.ninja|ninja'
    'buf.yaml|buf'
    'buf.gen.yaml|buf'
    'Justfile|just'
    'justfile|just'
    'Taskfile.yml|task'
    'Taskfile.yaml|task'
    'Dockerfile|docker'
    'compose.yaml|docker'
    'compose.yml|docker'
    'docker-compose.yaml|docker'
    'docker-compose.yml|docker'
    '.devcontainer/devcontainer.json|devcontainer'
    'flake.nix|nix'
    'shell.nix|nix'
    'devenv.nix|devenv'
    'devenv.yaml|devenv'
    'mise.toml|mise'
    '.mise.toml|mise'
    'Vagrantfile|vagrant'
    'supabase/config.toml|supabase'
    'bun.lock|shell 1,bun'
    'bun.lockb|shell 1,bun'
    'pnpm-lock.yaml|shell 1,pnpm'
    'yarn.lock|shell 1,yarn'
    'package-lock.json|shell 1,npm'
    'turbo.json|shell 1,turbo,workspace'
    'nx.json|shell 1,nx,workspace'
    'lerna.json|shell 1,lerna,workspace'
    'rush.json|shell 1,rush,workspace'
    'pnpm-workspace.yaml|shell 1,workspace'
    'Package.swift|swift 1,swiftpm'
    'X.xcodeproj/,Podfile|xcode,cocoapods'
    'X.xcodeproj/,Podfile.lock|xcode,cocoapods'
    'X.xcodeproj/,Cartfile|xcode,carthage'
    'X.xcodeproj/,Cartfile.resolved|xcode,carthage'
    'X.xcodeproj/,Tuist.swift|xcode,tuist'
    'X.xcodeproj/,Project.swift|xcode,tuist'
    'X.xcodeproj/,Workspace.swift|xcode,tuist'
    'X.xcodeproj/,Tuist/|xcode,tuist'
    'X.xcodeproj/,project.yml|xcode,xcodegen'
    'X.xcodeproj/,project.yaml|xcode,xcodegen'
    'X.xcodeproj/,.swiftlint.yml|xcode,swiftlint'
    'X.xcodeproj/,.swiftlint.yaml|xcode,swiftlint'
    'X.xcodeproj/,.swiftformat|xcode,swiftformat'
    'X.xcodeproj/,Fastfile|xcode,fastlane'
    'X.xcodeproj/,fastlane/Fastfile|xcode,fastlane'
    'X.xcodeproj/,Mintfile|xcode,mint'
    'X.xcworkspace/,Podfile|xcode,xcworkspace,cocoapods'
    'Podfile,Cartfile,Tuist.swift,Tuist/,project.yml,.swiftlint.yml,.swiftformat,Fastfile,Mintfile|shell 1'
    'uv.lock,poetry.lock,pdm.lock,pixi.toml,hatch.toml,Pipfile,environment.yml,requirements.txt|python 1,uv'
    'poetry.lock,pdm.lock,pixi.lock,hatch.toml,Pipfile,environment.yaml,requirements.txt|python 1,poetry'
    'pdm.lock,pixi.toml,hatch.toml,Pipfile,environment.yml,requirements.txt|python 1,pdm'
    'pixi.toml,hatch.toml,Pipfile,environment.yml,requirements.txt|python 1,pixi'
    'hatch.toml,Pipfile,environment.yml,requirements.txt|python 1,hatch'
    'Pipfile,environment.yml,requirements.txt|python 1,pipenv'
    'environment.yaml,requirements.txt|python 1,conda'
    'bun.lock,pnpm-lock.yaml,yarn.lock,package-lock.json|shell 1,bun'
    'pnpm-lock.yaml,yarn.lock,package-lock.json|shell 1,pnpm'
    'yarn.lock,package-lock.json|shell 1,yarn'
    'stack.yaml,package.yaml|haskell 1,stack,hpack'
    'package.yaml|shell 1'
    'x.cabal,package.yaml|haskell 1,cabal,hpack'
    'mill-build/build.sc|shell 1,mill'
    'packages.lock.json|shell 1,nuget'
    'Directory.Packages.props|shell 1,nuget'
    'pak.lock|shell 1,pak'
    'cpanfile.snapshot|shell 1,carton'
    'dist.ini|shell 1,dzil'
    '.tflint.hcl|shell 1,tflint'
    '.envrc|shell 1,direnv'
    'x.fs,X.sln|fsharp 1,solution'
    'x.vb,global.json|visual-basic 1'
    'x.csproj,global.json|dotnet 1'
    'x.fsproj,X.slnx|fsharp 1,solution'
    'next.config.js|shell 1,next'
    'nuxt.config.ts|shell 1,nuxt'
    'vite.config.mjs|shell 1,vite'
    'astro.config.mjs|shell 1,astro'
    'remix.config.js|shell 1,remix'
    'gatsby-config.js|shell 1,gatsby'
    'angular.json|shell 1,angular'
    'svelte.config.js|shell 1,sveltekit'
    'expo-env.d.ts|shell 1,expo'
    'react-native.config.js|shell 1,react-native'
    'forge.config.js|shell 1,electron'
    'electron-builder.yml|shell 1,electron'
    'electron-builder.yaml|shell 1,electron'
    'electron-builder.json|shell 1,electron'
    'electron-builder.json5|shell 1,electron'
    'electron-builder.js|shell 1,electron'
    'electron-builder.ts|shell 1,electron'
    '.storybook/main.js|shell 1,storybook'
    'prisma/schema.prisma|shell 1,prisma'
    'manage.py|shell 1,django'
    'config/application.rb,bin/rails|shell 1,rails'
    'config/application.rb|shell 1'
    'lib/app_web/router.ex|shell 1,phoenix'
    'src-tauri/tauri.conf.json|shell 1,tauri'
    'src-tauri/tauri.conf.json5|shell 1,tauri'
    'pubspec.yaml,lib/,android/|dart 1,pub,flutter'
    'pubspec.yaml,lib/,ios/|dart 1,pub,flutter'
    'pubspec.yaml,android/|dart 1,pub'
    'artisan|shell 1,laravel'
    'symfony.lock|shell 1,symfony'
    'wp-config.php|php 1,wordpress'
    'core/lib/Drupal.php|shell 1,drupal'
    'app/src/main/AndroidManifest.xml|shell 1,android'
    'lazy-lock.json,lua/|shell 1,neovim'
    'lazy-lock.json|shell 1'
    'x.ipynb,Makefile|python 1,make,jupyter'
    'Package.swift,X.xcodeproj/,package.json,tsconfig.json,pnpm-lock.yaml,turbo.json,next.config.js,Dockerfile,flake.nix,.envrc,Cargo.toml,go.mod,Gemfile,pom.xml,CMakeLists.txt,Makefile,Justfile,manage.py,pyproject.toml,uv.lock|swift 1,node 1,typescript 1,python 1,rust 1,go 1,ruby 1,pnpm,turbo,swiftpm,xcode,uv,cargo,go-modules,bundler,maven,cmake,make,just,next,django,workspace,docker,nix,direnv'
  )
  for pair in "${pairs[@]}"; do
    (( ++index ))
    specs+=("m$index=.git/,x.sh,${pair%%|*}")
    expected+=("m$index=${pair#*|}")
  done
  specs+=(
    'saturated-manifests=Package.swift,package.json,tsconfig.json,deno.jsonc,composer.lock,project.godot,requirements.txt,Cargo.toml,go.work,.ruby-version,pubspec.yaml,mix.exs,global.json,Podfile,Dockerfile'
    'saturated-resolved=src/x.c,x.fs,mix.exs,global.json'
    'saturated-subset=setup.cfg,DESCRIPTION,build.zig,stack.yaml,x.sh'
    'saturated-shell=.git/,x.sh'
    'saturated-custom=Makefile,x.sh'
  )
  expected+=(
    'saturated-manifests=swift 1,node 1,typescript 1,deno 1,php 1,gdscript 1,python 1,rust 1,go 1,ruby 1,dart 1,elixir 1,dotnet 1'
    'saturated-resolved=fsharp 1,c-cpp 1,elixir 1,dotnet 1'
    'saturated-subset=zig 1'
    'saturated-shell=shell 1'
    'saturated-custom='
  )
  output=$(_test_prompt_project_matrix "${specs[@]}") || return
  expected_text=${(F)expected}
  test_assert_equal "$expected_text" "$output"
}
test_case 'prompt project detection characterizes tool, framework and environment markers' \
  _test_prompt_project_detection_markers
