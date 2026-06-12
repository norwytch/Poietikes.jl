# Poietikes.jl

[![CI](https://github.com/norwytch/Poietikes.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/norwytch/Poietikes.jl/actions/workflows/CI.yml) [![Docs](https://img.shields.io/badge/docs-blue.svg)](https://norwytch.github.io/Poietikes.jl/) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A form-aware, multilingual prosodic analysis package for Julia, inspired by Python [prosodic](https://pypi.org/project/prosodic/).

Poietikes.jl treats a poem as a pairing of two independent types, **`(Form × Language)`**, and dispatches on that pair to measure how well a text fits a declared form. For an unknown text it returns ranked candidates for language and form.

## Install

Poietikes.jl requires **Julia ≥ 1.10**.

```julia
using Pkg
Pkg.add("Poietikes")
```

Pronunciation data is downloaded and cached on first use — [CMUdict](https://github.com/cmusphinx/cmudict) for English, [Lexique](http://www.lexique.org) for French. All other languages currently use rule-based frontends and need no download. 

## Quickstart

```julia
using Poietikes
```

Every call returns an `Analysis` — ranked candidates, best first. `best(a)` gives the top one (its `.language`, `.form`, `.analysis` — the structured fit — and `.score`), and `scansion(a)` renders it for the eye.

**For known texts**. Supply a `Form` and `Language`, get a structured fit and a human-readable scansion:

```julia
# A haiku, counted in morae (Japanese is rule-based — runs offline)
a = analyze("ふるいけや\nかわずとびこむ\nみずのおと"; language = :japanese, form = :haiku)

best(a).analysis      # CountFit(Mora, [5, 7, 5], [5, 7, 5], 0)   — unit, realized, target, cost
best(a).score.value   # 1.0

println(scansion(a))
#   Japanese / Haiku  (score 1.0), then a per-line Mora count: 5 ✓  7 ✓  5 ✓
```

The same `Form` differs by language: a haiku counts morae in Japanese but syllables in English.

```julia
b = analyze("an old silent pond\na frog jumps into the pond\nsplash silence again";
            language = :english, form = :haiku)
best(b).analysis        # CountFit(Syllable, [5, 7, 5], [5, 7, 5], 0)  — same form, counted by syllable
```

**Unknown texts** — omit `language`/`form` (both default to `:auto`): Poietikes detects the language and fits every supported form, returning ranked candidates for each. `is_confident` flags whether the top one clears a low floor; the [detection mechanism](#how-it-works) is described below.

```julia
a = analyze("Shall I compare thee to a summer's day")   # fetches CMUdict on first run
best(a).language      # English()
best(a).form          # Sonnet{Shakespearean}()   — the iambic-pentameter fit wins
is_confident(a)       # true

detect_language("the cat sat on the mat")
#  → 7-element Vector{Ranked}: English (≈0.84) first, then French, Spanish, …

detect_form("Shall I compare thee to a summer's day", English())
#  → 5-element Vector{Ranked}: Sonnet{Shakespearean} (1.0) first, then FreeVerse (0.6), …
```

**Going further** — define your own forms (by dispatch or from TOML), analyze a file, or run from the shell:

```julia
@form Cinquain English begin           # a new form by dispatch…
    count = (Syllable, [2, 4, 6, 8, 2])
end
load_forms("myforms.toml")             # …or define forms in a TOML file

open(io -> analyze(io; form = :haiku), "poem.txt")   # analyze takes an IO as readily as a String
```

```bash
julia --project=. scripts/analyze.jl poem.txt        # …or straight from the shell (language/form optional)
```

## Languages and forms

Eleven languages ship with built-in forms. Any `(Form, Language)` cell that isn't defined is analyzed descriptively — as free verse — rather than refused, and you can add your own with `@form` or a TOML file.

| Language | Frontend | Built-in forms |
|---|---|---|
| English | CMUdict (G2P) + rule fallback | free verse, haiku, tanka, Shakespearean sonnet, alliterative |
| Japanese | kana → morae | free verse, haiku, tanka |
| French | orthographic + Lexique for rhyme | free verse, Petrarchan sonnet (alexandrine) |
| Spanish | orthographic | free verse, octosílabo |
| Italian | orthographic | free verse, endecasillabo |
| Sanskrit | IAST / Devanāgarī → weight | free verse, bhujaṅgaprayāta |
| Chinese | pinyin + tone → 平/仄 | free verse, jueju |
| Latin | macron orthography → weight | free verse, dactylic hexameter |
| Arabic | transliteration → weight | free verse, ṭawīl, kāmil |
| Old Norse | orthography, initial stress | free verse, dróttkvætt |
| Welsh | orthography → consonant sequence | free verse, cywydd |

The first seven are auto-detected from raw text. Latin, Arabic, Old Norse, and Welsh take transliteration or orthography that reads as Latin script to the detector, so they're analyzed by naming the language (e.g. `language = :latin`).

## How it works

A form declares constraints on one or more independent **axes**, each a trait function dispatched on `(Form, Language)`; `analyze` parses the text under a language hypothesis, fits it against those axes, and scores the result. The seven pattern-based principles:

| Axis | Question | Tradition |
|---|---|---|
| **count** | does each line hit a target unit count? | haiku/tanka (morae), syllabic verse |
| **meter** (accentual-syllabic) | do stresses align to a weak/strong template? | English iambic verse |
| **syllabic + accent** | right syllable count, with the accent/caesura placed? | French alexandrine, Italian endecasillabo |
| **quantitative** | does the light/heavy sequence match — a fixed pattern, or feet that may substitute? | Sanskrit; Greek & Latin; Arabic |
| **moraic (mātrā)** | does each line sum to a target morae count (light = 1, heavy = 2)? | Sanskrit/Prakrit mātrā metres (e.g. āryā) |
| **tonal** | does the level/oblique sequence match? | Tang regulated verse |
| **consonantal** | do the right consonants recur — onsets, or whole sequences? | Germanic alliteration; Old Norse dróttkvætt; Welsh cynghanedd |

Two further axes range across the whole poem — **rhyme** (do the lines a scheme marks as rhyming actually rhyme?) and **structure** (the right number of lines and stanzas) — and a form may fuse several at once: Old Norse dróttkvætt is count + line-pair alliteration + internal rhyme. A form that declares nothing — free verse — is described by its prosodic features rather than fit to a template; that's also the graceful fallback when a form isn't defined for a language.

Every fit reduces to a cost mapped to a comparable score in `[0, 1]` (higher = better), calibrated so the metrical/non-metrical boundary lands near 0.5; pass a `Calibration` to `analyze` for reproducible scoring. Detection never returns a single verdict: `detect_language` and `detect_form` give **ranked candidates**, and `analyze(:auto)` searches the `(language × form)` space best-first.

**The full methodology** — the per-language parse rules, the Optimality-Theoretic metrical parser, the scoring and detection internals, and the analysis pipelines — is in the [documentation](https://norwytch.github.io/Poietikes.jl/) ([methodology page](docs/src/methodology.md)).

## Lineage

Poietikes.jl is indebted to [`prosodic`](https://github.com/quadrismegistus/prosodic) [(Ryan Heuser)](https://www.english.cam.ac.uk/people/Ryan.Heuser), which implements Paul Kiparsky and Kristin Hanson's "A Parametric Theory of Poetic Meter" (*Language*, 1996). We borrow its constraint-based metrical parse and English constraint vocabulary (`StressMaxInWeak` ≈ prosodic's `w_stress`, etc.) and its human-readable scansion output; we add breadth across the seven principles and eleven languages, ranked language- and form-**detection**, and user extensibility (`@form`, TOML). A line-by-line comparison — including the deliberate divergences (monosyllable flexibility; fit-vs-scan) — is in [`docs/src/comparison.md`](docs/src/comparison.md).

## Status and limitations

Poietikes.jl is pre-1.0. A few edges worth knowing:

- **Detection covers seven languages from raw text.** Latin, Arabic, Old Norse, and Welsh are analyzed by naming the language explicitly — their transliteration or orthography reads as Latin script to the detector.
- **Detection is a closed set — it never returns "unknown."** A text in an unsupported language (German, Russian, …) is mapped to the nearest *supported* language and confidently mislabeled; `is_confident` (a low floor) is the only guard against trusting such a verdict.
- **Adding a language means writing a frontend, not just detecting it.** A new language needs its own `prosodic_parse` (syllabification, weight, stress) before anything can be analyzed in it; that Languages.jl's model recognizes a language does not make it analyzable, since `detect_language` maps every result back onto the supported set.
- **Logographs need a dictionary.** Japanese and Chinese take *phonetic* input (kana, pinyin); raw kanji/hanzi carry no derivable pronunciation and aren't supported.
- **The Old Norse and Welsh frontends are orthographic approximations** — enough for the consonantal correspondences dróttkvætt and cynghanedd turn on, not a full phonology.
- **Scoring scales are calibrated, not learned.** The metrical-violation scale is fit to a small corpus; constraint-weight learning is implemented but reports honestly that clean canonical verse under-determines the weights.
- **Scores are ordinal, not absolute.** A `NormScore` in `[0, 1]` is meaningful for *ranking* candidates, not as a probability — 0.7 doesn't mean "70% a sonnet." The underlying raw cost is on the result (`best(a).analysis.total_cost`) if you need the number itself, and `analyze(…; calibration = …)` makes scoring reproducible against fixed tunables.
