# Xcode Run across concrete destinations

The earlier Run coordinator supported only Simulator. Build and Test already
delegated to `xcodebuild`, but the destination parser deduplicated by device ID
and discarded architecture and variant. The user requested Build/Run/Test on
every valid destination rather than silently hiding Run outside Simulator.

The action dashboard now offers both Run modes for every retained concrete
destination. A validated destination specification accompanies the ID,
platform and display label through selection, four-scheme temporary caching,
refresh, build, test and build-settings capture. Native Mac, Rosetta, Catalyst
and Designed for iPad choices can therefore share an ID without collapsing.
Compatible iPad/iPhone variants also remain available on Vision Pro and its
Simulator; a regression check covers their capture and exact Build/Test arguments.
Run remains subject to the selected scheme and installed native tools: a
library has no standalone application, and a device must support the native
device transport. Generic build-only placeholders are not launch targets.

Run builds incrementally, or sends ordered `clean build` for Rebuild & Run.
Bounded build settings identify existing app bundles or Mac command-line
products over at most 100 target dictionaries. Several runnable products open
a shared Run product chooser after the build, using only captured paths and
identifiers. Its acceptance says Run, Escape cancels launch, and the selected
leaf is checked again after cleanup. Absent interactive UI fails on ambiguity.
This does not reproduce Xcode's complete Run scheme editor, arguments,
environment or custom executable configuration.

Mac apps use `open -n -a` with their exact built path and captured architecture;
command-line products execute in the restored terminal, using native `arch`
when necessary. Physical devices use `devicectl device install app --device`
and `device process launch --device --terminate-existing --console` with the
exact ID and bundle. Apple's foreground console owns output and signal
forwarding. Simulator retains the existing scoped log/LLDB workspace. There
is no new background monitor, persistent Compozsh log or device scan.

Device installation is an explicit native-tool handoff to user-selected
hardware over its configured connection. The installed app persists, can
replace its previous installed copy, and is not rolled back on launch failure.
Pairing, Developer Mode and signing remain in Xcode. Public documentation and
the security inventory disclose this boundary separately from Simulator's
in-memory logging lifecycle.

## Evidence

Apple's [command-line tool reference](https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference)
identifies `xcodebuild`, `simctl` and `devicectl` and directs developers to their
native help. The [device-running guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
describes scheme/destination selection and device prerequisites. Apple's
[Xcode updates](https://developer.apple.com/documentation/updates/xcode)
describe CoreDevice-supported hardware; compatibility is owned by the installed
Xcode and device versions, not inferred from a platform label alone.

On the development host, Xcode 27 beta build 27A5252f's native help confirmed
exact device-ID/UDID addressing, app installation, console attachment and
catchable signal forwarding. A disposable project reported native Mac,
Catalyst and `Designed for [iPad,iPhone]` entries sharing one device ID. The
comma-containing display variant is invalid as a literal destination argument
(status 64); `variant=Designed for iPad` is accepted. Bounded settings queries
with a fixture-local DerivedData path reported `macosx` for native/Catalyst and
`iphoneos` for Designed for iPad. Only synthetic project data was queried;
host/device identifiers are omitted here.

The updated Run coordinator also built and launched a disposable native Mac
application. Its only behavior wrote the expected synthetic marker beneath
the fixture directory and exited. The sandbox initially blocked Launch
Services despite the executable existing; an approved host-level rerun
returned success and produced the marker. This is a native Mac integration
observation, not a physical-device or GA-version certification.

Native-Zsh regressions cover menu visibility across destinations, exact
build/rebuild and device install/launch arguments, failure short-circuiting,
command-line execution status, ambiguous products, invalid selectors,
same-ID variant refresh/cache restoration, and missing cached specifications.
A real PTY/ZLE product journey exercises explicit selection, narrow resize,
Escape, terminal cleanup, and symlink replacement before acceptance. These
tests use disposable native-command spies and launch no real device app.
No paired physical hardware was available for end-to-end device validation.

## Independent review corrections

Three agents reviewed native correctness, security/lifecycle, and tests/UI
before release sign-off. The correctness review caught two gaps in the expanded
destination handling: compatible Vision Pro variants were rejected by a
Mac-only variant check, and captured architecture reached the build but not
physical launch or Simulator boot. Regression tests established both failures
before correction. The documented native `variant=macOS` is also retained.

The UI review strengthened the product chooser's real PTY test to inspect the
editor payload at paint, require a fitted 40-column redraw, and verify restored
terminal modes, prompt/buffer/display state and alternate-screen cleanup.

An isolated disposable iOS 26.5 Simulator successfully booted with
`--arch=arm64`; `simctl getenv <exact-id> SIMULATOR_ARCHS` returned `arm64`.
Its `SIMULATOR_RUNTIME_VERSION` returned `26.5`. Native `simctl launch` help
restricts explicit launch architecture to runtime 26 or newer, so those
runtimes receive the captured slice at launch; older runtimes require a
single matching boot architecture. Missing or ambiguous native reports stop
before installation, and Compozsh never shuts down a running Simulator to
change its architecture automatically.
A proposed `/usr/bin/uname -m` spawn failed with native status 111, so that
probe was rejected before production implementation. The fixture was shut down
and deleted. This validates the native architecture environment probe on that
runtime; it does not establish Rosetta behavior on every supported runtime.

A compiled synthetic arm64 app was also installed and launched with
`--arch=arm64 --console` on the isolated iOS 26.5 Simulator. A marker written
inside that app's sandbox verified execution. The initial short-lived app's
stdout marker was not captured despite launch status 0; the sandbox marker
provided independent execution evidence on the repeated check. The Simulator
and its app data were removed after verification.

The final candidate passed all 782 native regression tests and all 26 optional
Node website tests. Native syntax checks, isolated double-sourcing, and
`git diff --check` passed. Independent security/lifecycle, correctness, UI/test
and release-scope reviews found no remaining blocking issue after the recorded
corrections. Physical-device and Rosetta execution remain outside the native
integration evidence collected for this change.
