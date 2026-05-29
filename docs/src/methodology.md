# Methodology

We treat a given poetic text as a function of two independent types, `Form` and `Language`,
resulting in its `(Form × Language)` pairing. This takes advantage of multiple dispatch in Julia,
and this project is organized around the `(Form × Language)` extension of prosodic's
metrical-phonological capabilities.

## The language-relative parse

Analysis begins by parsing the text into prosodic units under a language hypothesis. The same
string yields different structure in different languages, so the parse belongs to a candidate, not
to the text:

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

## Seven prosodic principles

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

## Metrical parsing as constraint optimization

The accentual-syllabic parser is derived directly from prosodic, and is the most involved axis, following the generative-metrics tradition. A line is parsed by mapping its syllables onto a sequence of metrical positions (weak/strong, derived from the foot and line length). A position may hold one or two syllables, which covers resolution and feminine endings and is the source of optionality the parser searches over. Each candidate parse is scored by a set of violable, weighted constraints (ie, a Harmonic Grammar (weighted sum) rather than strict OT ranking), and the lowest-cost parse wins. In descending weight:

- ***Stress maximum in a weak position*** — the cardinal violation: a syllable more prominent than both neighbours, landing off the beat.
- ***Trough in a strong position*** — an unstressed dip on the beat.
- **Clash** and **lapse** — rhythmic constraints.
- **Illegal resolution** — a near-categorical bar on splitting a stressed or heavy syllable across one position.

Two choices follow Hanson & Kiparsky: **monosyllabic words are stress-flexible** — their stress is assigned by the meter, so a function word never fights the template (this is why canonical pentameter scores zero) — and resolution is restricted to light, unstressable syllables. The quantitative and tonal axes take weight and tone as the per-syllable property in place of stress; the consonantal axis works on onsets, and on the consonant sequences of the harmony traditions.

Most axes need no such search; they are direct per-line comparisons: **count** tallies the units in each line against the target (e.g. 5-7-5); **moraic** sums each line's morae (light = 1, heavy = 2) against a target; **syllabic** checks that count plus the caesura and accent positions; **tonal** compares the line's level/oblique sequence to a target pattern, position by position; and **rhyme** and **structure** compare realized rimes and line/stanza counts to what the form declares. **Quantitative** metre is a direct comparison too when its target is a fixed light/heavy pattern (Sanskrit) — but when the metre is built from *feet that may substitute* (a dactyl contracting to a spondee in Greek/Latin hexameter; the *ziḥāf* variants of the Arabic *buḥūr*), each foot offers several light/heavy realizations and the best-fitting combination is searched for: the quantitative analog of the metrical parse. The **consonantal** axis likewise ranges from the simple — counting how many stressed onsets agree — to composite forms that check several correspondences at once: Old Norse dróttkvætt (line-pair alliteration plus internal half/full rhyme) and Welsh cynghanedd (consonant-sequence harmony). So meter and the foot-substitution metres are the parsers; the rest are short, near-identical `_*_fit` comparisons.

## Scoring and detection

Every fit reduces to a cost, mapped to a comparable score in `[0, 1]` (higher = better); the scale for metrical violations is calibrated against a corpus of known verse so that the metrical/non-metrical boundary lands near 0.5. Detection never returns a single verdict: `detect_language` and `detect_form` return **ranked candidates**, and `analyze` with `:auto` searches the `(language × form)` space and returns candidates best-first, combining language confidence with form fit. `detect_language` is built on Languages.jl's model, which recognizes dozens of languages — but it maps that answer onto its own supported set rather than reporting all of them, since analysis needs a frontend; the broader model is headroom for languages added later, not current coverage. Constraint weights are tunable (and the OT scale and free-verse baseline live in a `Calibration` you can pass to `analyze` for reproducible scoring); they can be estimated from a labelled corpus, though clean canonical verse under-determines them, which the learner reports rather than hides.

## Known vs Unknown texts

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
