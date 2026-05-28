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

Pronunciation data is downloaded and cached on first use — [CMUdict](https://github.com/cmusphinx/cmudict) for English, [Lexique](http://www.lexique.org) for French. Japanese, Romance, Sanskrit, and Chinese use rule-based frontends and need no download.

## Quickstart

```julia
using Poietikes
```

**Targeted analysis** — supply a Form and Language, get a structured fit and a human-readable scansion:

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

The *same* Form is realized differently per language — a haiku counts **morae** in Japanese but **syllables** in English — because forms dispatch on `(Form × Language)`:

```julia
analyze("an old silent pond\na frog jumps into the pond\nsplash silence again";
        language = :english, form = :haiku)        # CountFit, by Syllable
```

**Auto-detection** — omit `language`/`form` (both default to `:auto`) and poietikês detects them, returning ranked candidates best-first:

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

The goal for poeitikes is to retain the metrical-phonological capabilities of prosodic, and extend its capabilities into a language-aware poetic form analysis.

Poietikes has two pipelines: 
- prescriptive: given a poetic text, its Form, and its Language, explicitly breaks down the given text in accordance with a Form x Language dispatch, allowing for the same form to be analyzed based on its differences across languages (haiku are analyzed with morae in Japanese and syllables in English). 
- descriptive: given a poetic text, extract features from the text, and output an estimate of source language and poetic form. 

Both pipelines are based on analysis of the same prosodic and phonological features, as described in the Methodolgy section. Prosodic parsing is relative to the text language (a parameter in the prescriptive pipeline, or a product of language detection in the descriptive pipeline). 

Currently, this has built-in support for English, Japanese, French, Spanish, Italian, Chinese, and Sanskrit, with pronunciation data from CMUdict for English and Lexique for French. 
```

## Methodology

poietikês treats the analysis of a poem as a function of two independent types — its **Form** and its **Language** — resolved by Julia's multiple dispatch. This `(Form × Language)` pairing is the organizing idea: a form's realized constraints are a property of the *pair*, not of the form alone, so the same form is measured by different prosodic units in different languages (a haiku counts morae in Japanese, syllables in English) with no special-casing.

### The language-relative parse

Analysis begins by parsing the text into prosodic units *under a language hypothesis* — the same string yields different structure in different languages, so the parse belongs to a candidate, not to the text:

- **English** — grapheme-to-phoneme via CMUdict (ARPABET), syllabified by the Maximum Onset Principle, carrying lexical stress; out-of-vocabulary words fall back to a vowel-group estimate.
- **Japanese** — kana segmented into morae (small kana absorb into the preceding mora; the sokuon っ, moraic nasal ん, and long mark ー each count as one).
- **Romance (French, Spanish, Italian)** — rule-based orthographic syllabification: French *e muet* elision and the silent *u* of qu/gu; Spanish/Italian diphthong–hiatus splitting, lexical stress from spelling, and synalepha across word boundaries.
- **Sanskrit** — IAST transliteration classified into *laghu* (light) and *guru* (heavy) by the classical rule: a syllable is heavy if its vowel is long, or it is closed by a consonant cluster, anusvāra, or visarga.
- **Chinese** — pinyin with tone numbers classified into level (平) and oblique (仄).

French rhyme additionally draws pronunciations from Lexique.

### Six prosodic principles

A form declares constraints on one or more independent **axes**, each a trait function dispatched on `(Form, Language)`. poietikês implements the major pattern-based principles found across traditions:

| Axis | Question | Tradition |
|---|---|---|
| **count** | does each line hit a target unit count? | haiku/tanka (morae), syllabic verse |
| **meter** (accentual-syllabic) | do stresses align to a weak/strong template? | English iambic verse |
| **syllabic + accent** | right syllable count, with the accent/caesura placed? | French alexandrine, Italian endecasillabo |
| **quantitative** | does the light/heavy sequence match? | Sanskrit, classical metres |
| **tonal** | does the level/oblique sequence match? | Tang regulated verse |
| **consonantal** | do stressed onsets alliterate? | Germanic alliterative verse |

A form that declares no constraints (free verse) is analyzed *descriptively* — features only, no template.

### Metrical parsing as constraint optimization

The accentual-syllabic parser, the most involved axis, follows the generative-metrics tradition. A line is parsed by mapping its syllables onto a sequence of metrical positions (weak/strong, derived from the foot and line length); a position may hold one or two syllables, which covers resolution and feminine endings and is the source of optionality the parser searches over. Each candidate parse is scored by a set of **violable, weighted constraints** — a Harmonic Grammar (weighted sum) rather than strict OT ranking — and the lowest-cost parse wins. In descending weight:

- ***Stress maximum in a weak position*** — the cardinal violation: a syllable more prominent than both neighbours, landing off the beat.
- ***Trough in a strong position*** — an unstressed dip on the beat.
- **Clash** and **lapse** — rhythmic constraints.
- **Illegal resolution** — a near-categorical bar on splitting a stressed or heavy syllable across one position.

Two choices follow Hanson & Kiparsky: **monosyllabic words are stress-flexible** — their stress is assigned by the meter, so a function word never fights the template (this is why canonical pentameter scores zero) — and resolution is restricted to light, unstressable syllables. The quantitative and tonal axes reuse the same pattern-matching shape with weight and tone as the per-syllable property; the consonantal axis checks onset agreement among stressed syllables.

### Scoring and detection

Every fit reduces to a cost, mapped to a comparable score in `[0, 1]` (higher = better); the scale for metrical violations is calibrated against a corpus of known verse so that the metrical/non-metrical boundary lands near 0.5. Detection never returns a single verdict: `detect_language` and `detect_form` return **ranked candidates**, and `analyze` with `:auto` searches the `(language × form)` space and returns candidates best-first, combining language confidence with form fit. Constraint weights are tunable and can be estimated from a labelled corpus — though clean canonical verse under-determines them, which the learner reports rather than hides.

### The two pipelines

`analyze(text; language=:auto, form=:auto)` is the single entry point; the keywords select between two execution paths that share the same middle (parse → fit), differing only at the ends.

**Targeted** — `analyze(text; language = :japanese, form = :haiku)` (both supplied):

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

**Auto-detection** — `analyze(text)` (both `:auto`):

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

So detection replaces the single resolved language/form with a **ranked search over the `(language × form)` space**, and `combine`s language confidence with the form fit rather than using the fit alone. Everything between — the language-relative `prosodic_parse` and the axis-routed `fit` — is identical across both paths.

### Lineage and references

poietikês begins from Python [`prosodic`](https://github.com/quadrismegistus/prosodic) (Ryan Heuser), and is explicit about what it inherits.

**Derived from `prosodic`:**
- the constraint-based view of metrical parsing — a line is scanned by minimizing the violations of weighted, violable constraints over candidate parses;
- the English accentual-syllabic constraint vocabulary, which corresponds nearly one-to-one (our `StressMaxInWeak` / `TroughInStrong` / `IllegalResolution` ≈ prosodic's `w_stress` / `s_unstress` / `unres_across`);
- the dictionary-based approach to English pronunciation (syllabification and stress from a pronouncing dictionary);
- human-readable scansion strings as the way a parse is presented.

**Added or deliberately divergent:** breadth beyond English accentual-syllabic to the count / syllabic+accent / quantitative / tonal / consonantal axes and seven languages; first-class language- and form-**detection** (ranked candidates); user extensibility (`@form`, TOML); and two departures from prosodic — **monosyllabic stress flexibility** (prosodic assigns monosyllables a fixed stress; we let the meter assign it, so canonical verse scores zero) and a **fit-against-a-declared-form** stance (prosodic freely scans any line; we measure fit to a stated Form, and answer "which form?" separately via detection). A line-by-line comparison, including where the two diverge and why, is in [`docs/comparison.md`](docs/comparison.md).

- Hanson, K. & Kiparsky, P. (1996). "A Parametric Theory of Poetic Meter." *Language* 72(2). — form-as-parameters; monosyllabic stress flexibility.
- Prince, A. & Smolensky, P. (1993/2004). *Optimality Theory: Constraint Interaction in Generative Grammar.*
- Legendre, G., Miyata, Y. & Smolensky, P. (1990); Pater, J. (2009). — Harmonic Grammar (weighted constraints).
- Hayes, B. (1995). *Metrical Stress Theory: Principles and Case Studies.*
- Piṅgala. *Chandaḥśāstra.* — Sanskrit *chandas* and the *gaṇa* system (*laghu*/*guru*).
- Sievers, E. (1893). *Altgermanische Metrik.* — Germanic alliterative verse.
- Pronunciation data: the CMU Pronouncing Dictionary (English); New, B. & Pallier, C. et al., *Lexique* (French).


