# poietikês

Prosodic analysis in Julia, inspired by Python [prosodic](https://pypi.org/project/prosodic/). 

## Install

poietikes requires **Julia ≥ 1.10**. It is not yet in Julia's General registry, so install it from the repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/<your-account>/Poietikes.jl")
# …or, for local development:
Pkg.develop(path = "/path/to/poietikes")
```

Pronunciation data is downloaded and cached on first use — [CMUdict](https://github.com/cmusphinx/cmudict) for English, [Lexique](http://www.lexique.org) for French. Japanese, Romance, Sanskrit, and Chinese currently use rule-based frontends and need no download.

## Quickstart

```julia
using Poietikes
```

**For known texts**. Supply a `Form` and `Language`, get a structured fit and a human-readable scansion:

```julia
# A haiku, counted in morae (Japanese is rule-based — runs offline)
a = analyze("ふるいけや\nかわずとびこむ\nみずのおと"; language = :japanese, form = :haiku)

best(a).analysis      # CountFit: morae per line [5, 7, 5] vs target [5, 7, 5]
best(a).score.value   # 1.0  — a perfect fit

println(scansion(a))
#   Japanese / Haiku  (score 1.0)
#   count by Mora:
#     line 1: 5 (want 5) ✓
#     line 2: 7 (want 7) ✓
#     line 3: 5 (want 5) ✓
```

The same `Form` can exist across languages, but will naturally differ in parsing needs in accordance with each language's prosody. Ex: a haiku counts morae in Japanese but syllables in English. 

```julia
analyze("an old silent pond\na frog jumps into the pond\nsplash silence again";
        language = :english, form = :haiku)        # CountFit, by Syllable
```

**Unknown texts** — omit `language`/`form`, which will both default to `:auto`. Poietikes will execute some rudimentary detection (TODO: add language detection via LanguageIdentification.jl) for language, and analyze the text based on known forms within that language. It will return candidates for both `Language` and `Form`, ranked by [QUESTION: ranked by what?]:

```julia
a = analyze("Shall I compare thee to a summer's day")   # fetches CMUdict on first run
best(a).language      # English()
best(a).form          # Sonnet{Shakespearean}()  — detected as iambic pentameter
is_confident(a)       # true

detect_language("the cat sat on the mat")                         # ranked Vector{Ranked{Language}}
detect_form("Shall I compare thee to a summer's day", English())  # ranked Vector{Ranked{Form}}
```

**Define your own forms** — by dispatch with the `@form` macro, or from a TOML file:

```julia
@form Cinquain English begin
    count = (Syllable, [2, 4, 6, 8, 2])
end

load_forms("myforms.toml")    # register data-defined forms at runtime
```

## About

## Methodology

We treat a given poetic text as a function of two independent types, `Form` and `Language`, resulting in its `(Form × Language)` pairing. This takes advantage of multiple dispatch in Julia, and this project is organized around the `(Form × Language)` extension of prosodic's metrical-phonological capabilities. 

### The language-relative parse

Analysis begins by parsing the text into prosodic units under a language hypothesis. The same string yields different structure in different languages, so the parse belongs to a candidate, not to the text:

- **English** — grapheme-to-phoneme via CMUdict (ARPABET), syllabified by the Maximum Onset Principle, carrying lexical stress; out-of-vocabulary words fall back to a vowel-group estimate.
- **Japanese** — kana segmented into morae (small kana absorb into the preceding mora; the sokuon っ, moraic nasal ん, and long mark ー each count as one).
- **Romance (French, Spanish, Italian)** — rule-based orthographic syllabification: French *e muet* elision and the silent *u* of qu/gu; Spanish/Italian diphthong–hiatus splitting, lexical stress from spelling, and synalepha across word boundaries. French rhyme additionally draws pronunciations from Lexique.
- **Sanskrit** — IAST transliteration classified into *laghu* (light) and *guru* (heavy) by the classical rule: a syllable is heavy if its vowel is long, or it is closed by a consonant cluster, anusvāra, or visarga.
- **Chinese** — pinyin with tone numbers classified into level (平) and oblique (仄).
- **more languages coming soon!**

### Six prosodic principles

A form declares constraints on one or more independent **axes**, each a trait function dispatched on `(Form, Language)`. poietikes implements the major pattern-based principles found across traditions:

| Axis | Question | Tradition |
|---|---|---|
| **count** | does each line hit a target unit count? | haiku/tanka (morae), syllabic verse |
| **meter** (accentual-syllabic) | do stresses align to a weak/strong template? | English iambic verse |
| **syllabic + accent** | right syllable count, with the accent/caesura placed? | French alexandrine, Italian endecasillabo |
| **quantitative** | does the light/heavy sequence match? | Sanskrit, classical metres |
| **tonal** | does the level/oblique sequence match? | Tang regulated verse |
| **consonantal** | do stressed onsets alliterate? | Germanic alliterative verse |

A form that declares no constraints on any axis, ie, free verse, is treated as having no template and analyzed solely through its features [QUESTION: WHAT FEATURES?].

### Metrical parsing as constraint optimization

The accentual-syllabic parser is derived directly from prosodic, and is the most involved axis, following the generative-metrics tradition. A line is parsed by mapping its syllables onto a sequence of metrical positions (weak/strong, derived from the foot and line length). A position may hold one or two syllables, which covers resolution and feminine endings and is the source of optionality the parser searches over. Each candidate parse is scored by a set of violable, weighted constraints (ie, a Harmonic Grammar (weighted sum) rather than strict OT ranking), and the lowest-cost parse wins. In descending weight:

- ***Stress maximum in a weak position*** — the cardinal violation: a syllable more prominent than both neighbours, landing off the beat.
- ***Trough in a strong position*** — an unstressed dip on the beat.
- **Clash** and **lapse** — rhythmic constraints.
- **Illegal resolution** — a near-categorical bar on splitting a stressed or heavy syllable across one position.

Two choices follow Hanson & Kiparsky: **monosyllabic words are stress-flexible** — their stress is assigned by the meter, so a function word never fights the template (this is why canonical pentameter scores zero) — and resolution is restricted to light, unstressable syllables. The quantitative and tonal axes reuse the same pattern-matching shape with weight and tone as the per-syllable property; the consonantal axis checks onset agreement among stressed syllables.

[QUESTION: IS THIS JUST FOR ENGLISH? WHAT ABOUT COUNT, METER, QUANTITATIVE, TONAL, AND CONSONANTAL PARSING?]

### Scoring and detection

Every fit reduces to a cost, mapped to a comparable score in `[0, 1]` (higher = better); the scale for metrical violations is calibrated against a corpus of known verse so that the metrical/non-metrical boundary lands near 0.5. Detection never returns a single verdict: `detect_language` and `detect_form` return **ranked candidates**, and `analyze` with `:auto` searches the `(language × form)` space and returns candidates best-first, combining language confidence with form fit. Constraint weights are tunable and can be estimated from a labelled corpus — though clean canonical verse under-determines them, which the learner reports rather than hides.

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

`fit` dispatches on whichever axis the form declares: meter → `FormFit` (the OT search) / quantitative → `QuantitativeFit` / tonal → `TonalFit` / syllabic → `SyllabicFit`; else count → `CountFit`, alliteration → `AllitFit`, rhyme → `RhymeFit`, structure → `StructureFit`; a form with no constraints (free verse) is scored descriptively by `features`.

**Unknown** — `analyze(text)` (both `:auto`):
Note: soon to replaced with actual language detection via LanguageIdentification.jl. 

```text
text
 └─ detect_language(text) → ranked [Language ⇒ confidence]   # script / diacritics / stopwords / pinyin
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

poietikes is indebted to [`prosodic`](https://github.com/quadrismegistus/prosodic) (Ryan Heuser), which implements the work of Paul Kiparsky and Kristin Hanson in "A Parametric Theory of Poetic Meter," published in *Language*, 1996. The primary way by which we differentiate our two approaches is that we consider prosodic to be primarily focused on metrical-phonological features of human speech directed at metered poetry, and poietikes comes directly with context of poetic forms beyond meter in order to analyze a given text. 

Our derivations from prosodic include:
- constraint-based view of metrical parsing — a line is scanned by minimizing the violations of weighted, violable constraints over candidate parses;
- English accentual-syllabic constraint vocabulary, which is taken entirely from prosodic and translated to Julia via `StressMaxInWeak` / `TroughInStrong` / `IllegalResolution` ≈ prosodic's `w_stress` / `s_unstress` / `unres_across`;
- the use of CMUDict as a guide to English pronunciation, which led us to the use of Lexique for French;
- human-readable scansion strings as the way a parse is presented.

**Added or deliberately divergent:** breadth beyond English accentual-syllabic to the count / syllabic+accent / quantitative / tonal / consonantal axes and seven languages; first-class language- and form-**detection** (ranked candidates); user extensibility (`@form`, TOML); and two departures from prosodic — **monosyllabic stress flexibility** (prosodic assigns monosyllables a fixed stress; we let the meter assign it, so canonical verse scores zero) and a **fit-against-a-declared-form** stance (prosodic freely scans any line; we measure fit to a stated Form, and answer "which form?" separately via detection). A line-by-line comparison, including where the two diverge and why, is in [`docs/comparison.md`](docs/comparison.md).
