# USB progress integer bounds

Status: implemented; follow-ups are proposals (below)
Recorded: 2026-10-12

## Question

USB progress readers parse Compozsh's own mode-0600 `mktemp` captures in
`${TMPDIR:-/tmp}`. Only a same-user process could plant text there, which is
outside SECURITY.md's threat model. The question was whether that text could
still reach Zsh integer arithmetic unbounded, or as an expression, and whether
the verification-phase record needed a size cap without adding per-tick cost.
The audit then covered every integer use the USB peer feeds from captured,
image or device text.

## Findings (Apple Zsh 5.9, macOS 27)

Zsh evaluates text assigned to an integer, or named inside `(( ))`, as
arithmetic. A decimal literal above 9223372036854775807 (some 19-digit values
and every longer one) prints `number truncated after N digits` on stderr, which
can land on the status frame. The value is then truncated or wraps negative.
The 18-digit bound used across the codebase is conservative: such a value can
never overflow. Text that is an expression is evaluated, and an array subscript
such as `path[$(cmd)]` runs `cmd`; an invalid expression is a math error that
aborts the calling command list.

| Site | Input | Before |
| --- | --- | --- |
| `_usb_dd_progress_bytes` (pure) | dd records in progress captures | Unbounded `<->`; callers assign to `local -i` |
| `_usb_dd_progress_read` | `compozsh-write-verify-bytes:` records | Unbounded `<->` compared in `(( ))` |
| `_usb_write_image` | `compozsh-write-stage:` text | Compared as `(( _USB_WRITE_STAGE == verify ))`: planted subscripts ran commands; a verified write failing in its image stage printed `bad math expression` |
| `_usb_verify_progress_read` | verification-phase record | Here-string `read` straight into `local -i`: `1+1` became 2, planted subscripts ran commands, and the `<->` check came after evaluation |
| `_usb_createinstallmedia_progress_read` | installer percentage | Unbounded `<->` assigned to `local -i` |
| `_usb_od_uint` | GPT header fields of the selected image or target device | `od -t u8` prints up to 20 digits |
| `_usb_gpt_layout_capture` | image backup entry LBA | Multiplied by 512 before any upper bound, so a valid 17-digit LBA of 2^55+k wraps |
| `_usb_disk_info_capture` | diskutil `TotalSize`, `DeviceBlockSize` | Assigned to `typeset -gi` globals before the `<->` check, which therefore had no effect |

Image files are untrusted data, so the two GPT cases are inside the threat
model. The wrap is a verification-integrity gap. A crafted image with a
matching header CRC could set its backup entry LBA to 2^55+20. Its byte offset
then wraps to the primary entry array, which passes the duplicate-entry digest.
That shrinks `_USB_GPT_STABLE_END`, and with it the range the relocated-GPT
fallback compares after a write. It allows no code execution and no
transmission.

## Change

The 18-digit bound (precedent: `_zle_picker_highlights_shift`) now applies at
each site, with `10#` on assignment where the text is converted.
- **Stage names** are compared with `[[ ]]`.
- **The backup entry LBA** is range-checked against the last LBA before
  multiplication. This is the same order `_usb_target_gpt_layout_validate`
  already used.
- **The diskutil sizes** are validated as scalars before they are assigned to
  the integer globals.
- **The verification-phase record** is opened with
  `sysopen -o cloexec,nofollow,nonblock` and read with one `sysread` of at most
  1,025 bytes. A record longer than 1 KiB is rejected after that read, and the
  rest of it is never read. The per-tick here-string temporary file is gone.

Regression cases are in `tests/usb_test.zsh`; select them with
`zsh tests/run.zsh 'USB numeric bounds'`. All eight fail on `00deab4` and pass
with the change.

*Superseded in part 2026-10-13 (separate change):* the post-write read-back
fallback was unreachable, because `flash-verify` succeeds only with in-session
verification evidence, and it was deleted; `_usb_execute` now fails closed
without that evidence. `_usb_verify_progress_read`, `_usb_od_uint` and
`_usb_gpt_layout_capture` went with it, so the verification-phase, GPT-field
and backup-entry hardening above covered code that no longer ships, and their
three cases were removed. The other five `USB numeric bounds` cases still
apply.

## Measurements

Each figure is the mean of 400 calls to `_usb_verify_progress_read` with a
three-field record and a one-line dd capture, in a disposable `HOME`, under
`env -i` and `LC_ALL=C`. Each session ran three rounds on one machine, against
a `git archive` export of `00deab4` and against this change. Session 1 measured
an earlier version that opened the record with `nofollow` only; session 2
measured the final `cloexec,nofollow,nonblock` open under slightly higher
system load. The figures are evidence, not thresholds.

| Path per tick | Session | Before | After |
| --- | --- | --- | --- |
| Meta record only (progress capture absent) | 1 | 0.25–0.26 ms | 0.16 ms |
| Meta record only (progress capture absent) | 2 | 0.27–0.28 ms | 0.18 ms |
| Full tick (meta record and dd capture) | 1 | 1.96–2.00 ms | 1.76–1.84 ms |
| Full tick (meta record and dd capture) | 2 | 2.16–2.27 ms | 2.08–2.09 ms |

The cap costs nothing, because the bounded native read is cheaper than the
old `$(<…)` read plus here-string. Most of the remaining tick is the
`/usr/bin/stat` process that `_usb_dd_bytes_observed` starts for its 1 MiB cap.

## Proposals (not implemented)

- **Native progress-capture cap.** *Withdrawn (2026-10-13): `_usb_dd_bytes_observed`
  was deleted with the unreachable Windows writer, its last caller.* It could
  have dropped its `/usr/bin/stat` call in favor of the same bounded
  `sysopen`/`sysread`; raw-image write polling uses `_usb_dd_progress_read`
  and was never affected.
- **Remaining diskutil numbers.** *Implemented separately (`f17abf6`,
  [arithmetic validation](arithmetic-input-validation.md)):* the integer audit
  bounds the `AllDisks` count, the personality sizes (as int64 text) and FAT32
  free space. As first recorded, these were `<->`-validated without a length
  bound before `(( ))` comparisons; none is assigned to an integer:
  - the `AllDisks` count;
  - personality minimum and maximum sizes;
  - FAT32 free space.

  They come from Apple's `diskutil` through size-capped captures. A planted
  out-of-range value would print a diagnostic. An in-range lie would be equally
  possible, though, so a bound here would only improve hygiene.
- **Progress percentage arithmetic.** `_usb_progress_model` computes
  `bytes * 100`, which can wrap for 17–18-digit totals. Only the displayed bar
  would be affected, because `_usb_progress_bar` clamps to 0–100. Real
  totals are image sizes far below that range.

## Related observation

`_usb_disk_info_capture` ended with `[[ -n $device_tree ]] && …`, so it
returned 1 when diskutil omitted `DeviceTreePath`, and its callers treated that
as a capture failure. This was found while writing the disk-size fixture and was
left unchanged here.

*Fixed 2026-10-12 (separate change):* the function ends with
`if [[ -n $device_tree ]]; then …; fi`, so a disk without the key captures with
fingerprint `id|size|name|protocol` and stays eligible. Regression case:
`zsh tests/run.zsh 'without DeviceTreePath'`.
