# poietikês vs. Python `prosodic`

A compare/contrast with [`prosodic`](https://github.com/quadrismegistus/prosodic) (Ryan Heuser), the
library named in our Vision as the conceptual ancestor. Run against `prosodic` 3.3.0 on a shared
English set. This doubles as a validation harness for our English OT parser: any line where the two
*disagree on direction* would be a candidate bug — none did.

## TL;DR

- **Same lineage, near-identical constraint vocabulary.** Both are weighted-constraint (Harmonic
  Grammar / OT) metrical parsers in the Hanson–Kiparsky tradition, and `prosodic`'s default
  constraints map almost one-to-one onto ours.
- **They agree on *direction*** — metrical verse scores far better than unmetrical in both.
- **They differ on *monosyllable stress*** (the headline): `prosodic` assigns every monosyllable a
  fixed stress and counts each local mismatch, so even canonical Shakespeare scores 1–4; poietikês
  treats monosyllables as *flexible* (they conform to their position), so clean verse scores 0.
- **They answer slightly different questions:** `prosodic` *scans* (find the best parse, any line
  length); poietikês *fits* a line against a *declared* form, and answers "which form?" separately
  via `detect_form`.
- **Different reach:** `prosodic` is deeper and more mature for English accentual-syllabic metrics;
  poietikês is broader across prosodic *principles* (accentual-syllabic, mora-count, syllabic +
  accent, quantitative) and languages, with detection and user-extensibility.

## Scansion on a shared set

| Line | `prosodic` score | poietikês cost |
|---|---|---|
| Shall I compare thee to a summer's day | 4.0 | **0.0** |
| When I do count the clock that tells the time | 4.0 | **0.0** |
| Rough winds do shake the darling buds of May | 1.0 | **0.0** |
| Then hate me when thou wilt if ever now | 2.0 | **0.0** |
| happy children wander homeward slowly *(trochaic)* | 15.0 | 24.0 |
| the committee will reconsider the proposal *(prose, 12 syll.)* | 7.0 | 19.0 |

Both separate metrical from unmetrical cleanly (low for Shakespeare, high for the trochaic/prose
controls). The *absolute* numbers differ for the reasons below.

## Constraint correspondence

`prosodic`'s violation breakdown for "Shall I compare thee to a summer's day" was
`{s_unstress: 2, w_stress: 1, unres_across: 1}`. Those constraints are ours under other names:

| `prosodic` | poietikês | meaning |
|---|---|---|
| `w_stress` | `StressMaxInWeak` | a stress maximum in a weak position |
| `s_unstress` | `TroughInStrong` | an unstressed syllable on a strong beat |
| `unres_across`, resolution constraints | `IllegalResolution`, `PositionSize` | restrictions on doubly-filled positions |
| (weighted sum) | weighted sum (`_OT_SCALE`-calibrated) | both are Harmonic Grammar |

We additionally separate `Clash` and `Lapse`; `prosodic` ships a larger default set (foot-min,
position-size variants, etc.). The conceptual frame is the same.

## The headline divergence: monosyllable stress

`prosodic` scores canonical Shakespeare at 1–4 violations because it gives each monosyllable a
stress value (from its dictionary/rules) and penalises every mismatch with the metrical position —
including on function words like *I*, *to*, *thee*. poietikês instead marks monosyllabic words
**flexible**: their stress is assigned by the meter (full in a strong position, none in a weak one),
so they never fight the template, and a clean iambic line scores **0**.

Neither is "wrong" — they capture different things. poietikês's treatment is arguably the more
faithful reading of the Hanson–Kiparsky principle (a metrical line has *no stress maximum in a weak
position*), giving a clean "is it metrical?" verdict. `prosodic`'s nonzero scores capture **gradient
tension** and so distinguish lines poietikês flattens to 0 (it rates "Rough winds…" = 1 as smoother
than "Shall I…" = 4). A future poietikês refinement could expose a similar gradient by scoring
secondary/word-class stress rather than fully neutralising monosyllables.

## Scan vs. fit (the 12-syllable line)

For the 12-syllable prose line, `prosodic` *scans* it as a 12-position line (six feet, score 7) — it
chooses the line length. poietikês *fits* against the **declared** form (Sonnet ⇒ pentameter, 10
positions) and so charges length-mismatch + resolution (cost 19). This reflects the design split:
`prosodic` answers "what is the best scansion of this line?"; poietikês answers "how well does this
line satisfy *this form*?" — and answers "which form?" separately and explicitly via `detect_form`
(ranked candidates), an axis `prosodic` doesn't have.

## Reach

| | `prosodic` 3.x | poietikês |
|---|---|---|
| Prosodic principle | accentual-syllabic (stress) | accentual-syllabic **+ mora-count + syllabic/accent + quantitative** |
| Languages | English (+ phonemization for many via espeak/gruut) | English, Japanese, French, Spanish, Italian, Sanskrit |
| Forms | meter parsing; configurable constraints | free verse, sonnet, haiku, tanka, endecasillabo, octosílabo, Bhujaṅgaprayāta, `@form`/TOML |
| Detection | — | `detect_language`, `detect_form` (ranked) |
| Extensibility | constraint config | by dispatch (`@form`) **and** by data (TOML `DataForm`) |
| Maturity | mature, research-validated, large dep tree | young, lean (`Downloads`, `TOML`) |
| Output | scansion strings (`-+-+`, capitalised) + pandas DataFrames | structured Julia types (`FormFit`, `Candidate`, …) |

`prosodic` is deeper and battle-tested for **English metrics specifically** (richer constraint set,
mature tooling, notebook-friendly DataFrames). poietikês trades that depth for **breadth across
prosodic principles and languages**, plus first-class detection and extension-by-dispatch.

## Output format

`prosodic`'s human-readable scansion strings (`shall I com PARE thee…`, `-+-+-+-+--`) are a real
ergonomic win for inspection. poietikês returns structured types (`FormFit`, `Candidate`, …) **and**
a scansion renderer over them — `scansion(x)` (`src/analysis/scansion.jl`) — directly inspired by
`prosodic`, so a reader gets both the programmatic result and a legible rendering.

## Caveats

- Performance is **not** rigorously benchmarked: a Python↔Julia comparison is confounded by Julia's
  JIT warm-up and `prosodic`'s first-run caching, so a naïve timing would mislead either way.
  Qualitatively, poietikês has a far lighter dependency footprint.
- The two make different stress assumptions, so absolute scores are **not** directly comparable; the
  meaningful comparison is *direction* (both rank metrical ≪ unmetrical) and *constraint structure*.

## Conclusion

The two are complementary. `prosodic` validated our English OT parser — the constraint sets
correspond and the two agree on metrical direction, with no divergence attributable to a parser bug.
The deliberate differences (monosyllable flexibility; fit-vs-scan; breadth over depth) are design
choices, not defects. Its clearest borrowable idea — human-readable scansion output — we adopted as
`scansion` (`src/analysis/scansion.jl`).
