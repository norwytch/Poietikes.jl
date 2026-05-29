# Adding a language frontend

A *form* can be added with `@form` or TOML, but a new **language** needs code: a `Language` type
and a `prosodic_parse` method that turns text into prosodic units. Detection is irrelevant here —
analysis runs entirely through `prosodic_parse`, and a language is usable the moment that method
exists (pass it explicitly, e.g. `analyze(text; language = MyLang())`).

This page is the contract that method must satisfy.

## The two required pieces

```julia
using Poietikes

struct MyLang <: Language end                       # 1. the dispatch tag

function Poietikes.prosodic_parse(text::AbstractString, ::MyLang)   # 2. the frontend
    # …build and return a ParsedPoem (see below)…
end
```

Extend `Poietikes.prosodic_parse` (qualified, or `import Poietikes: prosodic_parse`) — don't define
a new local function. The `IO` method (`prosodic_parse(::IO, ::Language)`) is provided generically,
so file input works automatically once your `String` method exists.

## What `prosodic_parse` must return

A `ParsedPoem(lang, stanzas, source)`:

- `lang` — your language instance.
- `stanzas::Vector{Stanza}` — each `Stanza(lines::Vector{Line})`; split on blank lines if your
  tradition has stanzas, otherwise use a single `Stanza`.
- `source::String` — the original text.

A `Line(units::Vector{ProsodicUnit}, surface::AbstractString)` holds the line's prosodic units in
order, plus the raw line text (`surface` is read by the caesura/cynghanedd machinery, so keep it).

`Poietikes._split_stanzas(text)` (blank-line split) and a `\n` split per line are the conventional
loop; see any `src/languages/*.jl` frontend for the shape.

## Which unit type to emit

Emit the unit that matches the **axis** your forms will declare:

| If your forms use… | emit | example languages |
|---|---|---|
| count by syllable; meter; syllabic; quantitative; moraic; consonantal | `Syllable` | English, Sanskrit, Latin, Norse |
| count by mora | `Mora` | Japanese |
| tonal (level/oblique) | `TonalSyllable(tone)` (`'P'`/`'Z'`) | Chinese |

Most languages emit `Syllable`. `units` is `Vector{ProsodicUnit}`, so a comprehension like
`ProsodicUnit[Syllable(…) for …]` is the idiom.

## The `Syllable` field contract

`Syllable(phonemes, stress, flexible, word_final, heavy)` — set only the fields the axes you target
actually read; the convenience constructors default the rest:

- **`phonemes::Vector{Phoneme}`** — the segments. The accentual meter parser and English-style rhyme
  read these (onset, coda, vowel). If you don't compute phonemes, pass `Phoneme[]` and don't use
  those axes.
- **`stress::Int`** — `0` none, `1` primary, `2` secondary. Required for **meter**, **syllabic**
  (accent positions), and **consonantal** (alliteration is on stressed onsets).
- **`flexible::Bool`** — `true` for a monosyllabic word whose stress the meter may assign (the
  Hanson–Kiparsky treatment). Only matters for the accentual parser; default `false`.
- **`word_final::Bool`** — `true` on the last syllable of each word. Read by the Romance **caesura**
  and the quantitative **yati** checks. Default `false` if you don't need them.
- **`heavy::Union{Bool,Nothing}`** — precomputed quantitative weight. **Quantitative and moraic**
  frontends must set this (`true` = heavy/guru, `false` = light/laghu); leave it `nothing` and
  `is_heavy` will try to derive weight from `phonemes` instead.

(Sanskrit, Latin, and Arabic share `Poietikes._iast_weights`, which computes the laghu/guru
`heavy` flags from a light token stream — worth reusing if your language scans by syllable weight.)

## Registering forms

A `(Form, Language)` cell must be registered to be `supports`-ed and detectable:

```julia
@form MyForm MyLang begin            # registers (MyForm, MyLang) automatically
    count = (Syllable, [5, 5])
end
# …or, for a built-in-style form, call Poietikes.register!(MyForm(), MyLang()).
```

An unregistered `(Form, Language)` pair isn't refused — it's analyzed descriptively (as free
verse), so `FreeVerse` always works once the frontend exists.

## Detection

`detect_language` ranks only the built-in auto-detected languages; a new language is **explicit-only**
unless you also teach the detector about it. Analyze it by naming it: `analyze(text; language = MyLang())`
(pass the *instance* — the `:symbol` form only resolves the built-ins).

## A minimal working example

A toy language that counts whitespace-separated tokens as syllables:

```julia
using Poietikes

struct Toy <: Language end

function Poietikes.prosodic_parse(text::AbstractString, lang::Toy)
    ls = Line[]
    for ln in split(text, '\n')
        isempty(strip(ln)) && continue
        units = ProsodicUnit[Syllable(Phoneme[], 0) for _ in split(strip(ln))]
        push!(ls, Line(units, strip(ln)))
    end
    return ParsedPoem(lang, [Stanza(ls)], String(text))
end

@form ToyForm Toy begin
    count = (Syllable, [3, 3])
end

best(analyze("a b c\nd e f"; language = Toy(), form = ToyForm())).analysis   # CountFit([3,3], [3,3], 0)
```

That's the whole contract: a `Language` type, a `prosodic_parse` returning a `ParsedPoem` of the
right unit type with the fields your axes read, and registered forms.
