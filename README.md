# Poietikes.jl

[![CI](https://github.com/norwytch/Poietikes.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/norwytch/Poietikes.jl/actions/workflows/CI.yml) [![Docs](https://img.shields.io/badge/docs-blue.svg)](https://norwytch.github.io/Poietikes.jl/) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A form-aware, multilingual prosodic analysis package for Julia, inspired by Python [prosodic](https://pypi.org/project/prosodic/).

Poietikes.jl treats a poem as a pairing of two independent types, **`(Form × Language)`**, and dispatches on that pair to measure how well a text fits a declared form. For an unknown text it returns ranked candidates for language and form.

## Install

Poietikes.jl requires **Julia ≥ 1.10**. It's not in Julia's General registry yet, so install it from the repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/norwytch/Poietikes.jl")
# …or, for local development:
Pkg.develop(path = "/path/to/Poietikes.jl")
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
#   Japanese / Haiku  (score 1.0)
#   count by Mora:
#     line 1: 5 (want 5) ✓
#     line 2: 7 (want 7) ✓
#     line 3: 5 (want 5) ✓
```

The same `Form` can exist across languages, but will naturally differ in parsing needs in accordance with each language's prosody. Ex: a haiku counts morae in Japanese but syllables in English. 

```julia
b = analyze("an old silent pond\na frog jumps into the pond\nsplash silence again";
            language = :english, form = :haiku)
best(b).analysis        # CountFit(Syllable, [5, 7, 5], [5, 7, 5], 0)  — same form, counted by syllable
```

**Unknown texts** — omit `language`/`form`, which will both default to `:auto`. Poietikes will detect the language — via [Languages.jl](https://github.com/JuliaText/Languages.jl): Unicode script detection, a trigram language model, and stopword lists, plus our own signals for transliterated input (pinyin, IAST) — and analyze the text based on known forms within that language. It will return candidates for both `Language` and `Form`, ranked by `NormScore` [0,1], in which 1 is a perfect fit to the form (a constrained form must clear a ~0.6 baseline to be ranked above free verse; `is_confident` separately flags a top candidate that falls below a low floor).

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

**Define your own forms** — by dispatch with the `@form` macro, or from a TOML file:

```julia
@form Cinquain English begin
    count = (Syllable, [2, 4, 6, 8, 2])
end

load_forms("myforms.toml")    # register data-defined forms at runtime
```

**From a file, or the terminal** — `analyze` (and `detect_language`/`detect_form`) take an open file as readily as a string:

```julia
open(io -> analyze(io; form = :haiku), "poem.txt")   # or: analyze(read("poem.txt", String))
```

…or run it straight from the shell on a file — `language` and `form` are optional, omit them to auto-detect:

```bash
julia --project=. scripts/analyze.jl poem.txt
julia --project=. scripts/analyze.jl haiku.txt japanese haiku
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

## Methodology

We treat a given poetic text as a function of two independent types, `Form` and `Language`, resulting in its `(Form × Language)` pairing. This takes advantage of multiple dispatch in Julia, and this project is organized around the `(Form × Language)` extension of prosodic's metrical-phonological capabilities. 

### The language-relative parse

Analysis begins by parsing the text into prosodic units under a language hypothesis. The same string yields different structure in different languages, so the parse belongs to a candidate, not to the text:

- **English** — grapheme-to-phoneme via CMUdict (ARPABET), syllabified by the Maximum Onset Principle, carrying lexical stress; out-of-vocabulary words fall back to a vowel-group estimate.
- **Japanese** — kana segmented into morae (small kana absorb into the preceding mora; the sokuon っ, moraic nasal ん, and long mark ー each count as one).
- **Romance (French, Spanish, Italian)** — rule-based orthographic syllabification: French *e muet* elision and the silent *u* of qu/gu; Spanish/Italian diphthong–hiatus splitting, lexical stress from spelling, and synalepha across word boundaries. French rhyme additionally draws pronunciations from Lexique.
- **Sanskrit** — IAST transliteration or Devanāgarī, classified into *laghu* (light) and *guru* (heavy) by the classical rule: a syllable is heavy if its vowel is long, or it is closed by a consonant cluster, anusvāra, or visarga.
- **Chinese** — pinyin with tone numbers classified into level (平) and oblique (仄).
- **Latin** — macron-marked orthography classified into light/heavy by the classical rule (heavy if the vowel is long or a diphthong, or closed by following consonants), with consonantal *i/j*, *qu*, and the digraphs handled; the weigher is shared with Sanskrit.
- **Arabic** — phonetic transliteration with explicit long vowels, classified into the same light/heavy weights — the material of the al-Khalīl metres (the *buḥūr*).
- **Old Norse** — normalized orthography syllabified with word-initial stress, exposing each syllable's onset (for alliteration) and rime (for *hending*, the internal rhyme).
- **Welsh** — orthography reduced to its ordered consonant sequence (the digraphs *ch, dd, ll, ng, …* read as single consonants), the material of *cynghanedd*.
- **more languages coming soon**

### Seven prosodic principles

A form declares constraints on one or more independent **axes**, each a trait function dispatched on `(Form, Language)`. Poietikes.jl implements the major pattern-based principles found across traditions:

| Axis | Question | Tradition |
|---|---|---|
| **count** | does each line hit a target unit count? | haiku/tanka (morae), syllabic verse |
| **meter** (accentual-syllabic) | do stresses align to a weak/strong template? | English iambic verse |
| **syllabic + accent** | right syllable count, with the accent/caesura placed? | French alexandrine, Italian endecasillabo |
| **quantitative** | does the light/heavy sequence match — a fixed pattern, or feet that may substitute? | Sanskrit; Greek & Latin; Arabic |
| **moraic (mātrā)** | does each line sum to a target morae count (light = 1, heavy = 2)? | Sanskrit/Prakrit mātrā metres (e.g. āryā) |
| **tonal** | does the level/oblique sequence match? | Tang regulated verse |
| **consonantal** | do the right consonants recur — onsets, or whole sequences? | Germanic alliteration; Old Norse dróttkvætt; Welsh cynghanedd |

Beyond these per-line principles, two axes range across the whole poem: **rhyme** — do the lines a scheme marks as rhyming actually rhyme? — and **structure** — the right number of lines and stanzas? A form may combine any of the axes, and a few fuse several at once: Old Norse dróttkvætt is count + line-pair alliteration + internal rhyme, Welsh cynghanedd is count + consonant-sequence harmony.

A form that declares no constraints on any axis, ie, free verse, is treated as having no template and analyzed solely through its prosodic features: stanza and line counts, the number of units (syllables or morae) per line, the total syllable count, and the per-line stress profile. This is also the fallback when a form isn't defined for a given language — it is analyzed as if it had no template, rather than refused. 

### Metrical parsing as constraint optimization

The accentual-syllabic parser is derived directly from prosodic, and is the most involved axis, following the generative-metrics tradition. A line is parsed by mapping its syllables onto a sequence of metrical positions (weak/strong, derived from the foot and line length). A position may hold one or two syllables, which covers resolution and feminine endings and is the source of optionality the parser searches over. Each candidate parse is scored by a set of violable, weighted constraints (ie, a Harmonic Grammar (weighted sum) rather than strict OT ranking), and the lowest-cost parse wins. In descending weight:

- ***Stress maximum in a weak position*** — the cardinal violation: a syllable more prominent than both neighbours, landing off the beat.
- ***Trough in a strong position*** — an unstressed dip on the beat.
- **Clash** and **lapse** — rhythmic constraints.
- **Illegal resolution** — a near-categorical bar on splitting a stressed or heavy syllable across one position.

Two choices follow Hanson & Kiparsky: **monosyllabic words are stress-flexible** — their stress is assigned by the meter, so a function word never fights the template (this is why canonical pentameter scores zero) — and resolution is restricted to light, unstressable syllables. The quantitative and tonal axes take weight and tone as the per-syllable property in place of stress; the consonantal axis works on onsets, and on the consonant sequences of the harmony traditions.

Most axes need no such search; they are direct per-line comparisons: **count** tallies the units in each line against the target (e.g. 5-7-5); **moraic** sums each line's morae (light = 1, heavy = 2) against a target; **syllabic** checks that count plus the caesura and accent positions; **tonal** compares the line's level/oblique sequence to a target pattern, position by position; and **rhyme** and **structure** compare realized rimes and line/stanza counts to what the form declares. **Quantitative** metre is a direct comparison too when its target is a fixed light/heavy pattern (Sanskrit) — but when the metre is built from *feet that may substitute* (a dactyl contracting to a spondee in Greek/Latin hexameter; the *ziḥāf* variants of the Arabic *buḥūr*), each foot offers several light/heavy realizations and the best-fitting combination is searched for: the quantitative analog of the metrical parse. The **consonantal** axis likewise ranges from the simple — counting how many stressed onsets agree — to composite forms that check several correspondences at once: Old Norse dróttkvætt (line-pair alliteration plus internal half/full rhyme) and Welsh cynghanedd (consonant-sequence harmony). So meter and the foot-substitution metres are the parsers; the rest are short, near-identical `_*_fit` comparisons.

### Scoring and detection

Every fit reduces to a cost, mapped to a comparable score in `[0, 1]` (higher = better); the scale for metrical violations is calibrated against a corpus of known verse so that the metrical/non-metrical boundary lands near 0.5. Detection never returns a single verdict: `detect_language` and `detect_form` return **ranked candidates**, and `analyze` with `:auto` searches the `(language × form)` space and returns candidates best-first, combining language confidence with form fit. `detect_language` is built on Languages.jl's model, which recognizes dozens of languages — but it maps that answer onto its own supported set rather than reporting all of them, since analysis needs a frontend; the broader model is headroom for languages added later, not current coverage. Constraint weights are tunable and can be estimated from a labelled corpus — though clean canonical verse under-determines them, which the learner reports rather than hides.

### Known vs Unknown Texts

**Known** — `analyze(text; language = :japanese, form = :haiku)` (both supplied):

```text
text
 └─ resolve :japanese → Japanese()                       # _resolve_language
     └─ prosodic_parse(text, Japanese()) → ParsedPoem    # language-relative units
         └─ resolve :haiku → Haiku()                      # _resolve_form
             └─ supports(Haiku, Japanese)?  → yes
                 └─ mode(Haiku, Japanese) → Prescriptive
                     └─ fit(Haiku, Japanese, parsed)      # routed by the declared axis → CountFit
                 └─ score = (the fit's normalized score)  # pure fit; no language uncertainty
 └─ Analysis(text, [Candidate(…)])  →  best() is the one verdict
```

`fit` dispatches on whichever axis the form declares: meter → `FormFit` (the OT search) / quantitative → `QuantitativeFit` / tonal → `TonalFit` / syllabic → `SyllabicFit`; else count → `CountFit`, moraic → `MatraFit`, alliteration → `AllitFit`, rhyme → `RhymeFit`, structure → `StructureFit`; a multi-constraint form (Old Norse dróttkvætt → `DrottkvaettFit`, Welsh cynghanedd → `CynghaneddFit`) declares a composite fit that checks several axes at once; and a form with no constraints (free verse) is scored descriptively by `features`.

**Unknown** — `analyze(text)` (both `:auto`):

```text
text
 └─ detect_language(text) → ranked [Language ⇒ confidence]   # Languages.jl: script + trigram + stopwords; our pinyin/IAST signals
     keep the languages within 0.6× the best score
     └─ for each candidate language L:
         prosodic_parse(text, L) → ParsedPoem                # re-parsed under each hypothesis
         └─ for each form F in supported_forms(L):
             analysis = mode(F, L)==Descriptive ? features(parsed) : fit(F, L, parsed)
             score    = combine(confidence(L), score(analysis))   # language × form fit
             collect Candidate(L, F, analysis, score)
 └─ sort candidates by score, best-first  →  Analysis        # ranked; best() = top, never a lone verdict
```

### Lineage and references

Poietikes.jl is indebted to [`prosodic`](https://github.com/quadrismegistus/prosodic) [(Ryan Heuser)](https://www.english.cam.ac.uk/people/Ryan.Heuser), which implements the work of Paul Kiparsky and Kristin Hanson in "A Parametric Theory of Poetic Meter," published in *Language*, 1996. The primary way by which we differentiate our two approaches is that we consider prosodic to be primarily focused on metrical-phonological features of human speech directed at metered poetry, and Poietikes.jl comes directly with context of poetic forms beyond meter in order to analyze a given text. 

Our derivations from prosodic include:
- constraint-based view of metrical parsing — a line is scanned by minimizing the violations of weighted, violable constraints over candidate parses;
- English accentual-syllabic constraint vocabulary, which is taken entirely from prosodic and translated to Julia via `StressMaxInWeak` / `TroughInStrong` / `IllegalResolution` ≈ prosodic's `w_stress` / `s_unstress` / `unres_across`;
- the use of CMUdict as a guide to English pronunciation, which led us to the use of Lexique for French;
- human-readable scansion strings as the way a parse is presented.

**Added or deliberately divergent:** breadth beyond English accentual-syllabic to the count / syllabic+accent / quantitative / moraic / tonal / consonantal axes and eleven languages — including a foot-substitution search for the Greek/Latin and Arabic quantitative metres, and composite fits for Old Norse dróttkvætt and Welsh cynghanedd; first-class language- and form-**detection** (ranked candidates); user extensibility (`@form`, TOML); and two departures from prosodic — **monosyllabic stress flexibility** (prosodic assigns monosyllables a fixed stress; we let the meter assign it, so canonical verse scores zero) and a **fit-against-a-declared-form** stance (prosodic freely scans any line; we measure fit to a stated Form, and answer "which form?" separately via detection). A line-by-line comparison, including where the two diverge and why, is in [`docs/src/comparison.md`](docs/src/comparison.md).

## Status and limitations

Poietikes.jl is pre-1.0 and not yet in Julia's General registry. A few edges worth knowing:

- **Detection covers seven languages from raw text.** Latin, Arabic, Old Norse, and Welsh are analyzed by naming the language explicitly — their transliteration or orthography reads as Latin script to the detector.
- **Detection is a closed set — it never returns "unknown."** A text in an unsupported language (German, Russian, …) is mapped to the nearest *supported* language and confidently mislabeled; `is_confident` (a low floor) is the only guard against trusting such a verdict.
- **Adding a language means writing a frontend, not just detecting it.** A new language needs its own `prosodic_parse` (syllabification, weight, stress) before anything can be analyzed in it; that Languages.jl's model recognizes a language does not make it analyzable, since `detect_language` maps every result back onto the supported set.
- **Logographs need a dictionary.** Japanese and Chinese take *phonetic* input (kana, pinyin); raw kanji/hanzi carry no derivable pronunciation and aren't supported.
- **The Old Norse and Welsh frontends are orthographic approximations** — enough for the consonantal correspondences dróttkvætt and cynghanedd turn on, not a full phonology.
- **Scoring scales are calibrated, not learned.** The metrical-violation scale is fit to a small corpus; constraint-weight learning is implemented but reports honestly that clean canonical verse under-determines the weights.
- **Scores are ordinal, not absolute.** A `NormScore` in `[0, 1]` is meaningful for *ranking* candidates, not as a probability — 0.7 doesn't mean "70% a sonnet." The underlying raw cost is on the result (`best(a).analysis.total_cost`) if you need the number itself, and `analyze(…; calibration = …)` makes scoring reproducible against fixed tunables.
