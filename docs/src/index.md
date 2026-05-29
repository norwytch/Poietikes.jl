# Poietikes.jl

A form-aware, multilingual prosodic analysis package for Julia — inspired by Python
[prosodic](https://pypi.org/project/prosodic/), and extended beyond English accentual-syllabic
verse to the metrical traditions of many languages.

Poietikes.jl treats a poem as a pairing of two independent types, `(Form × Language)`, and dispatches
on that pair. It **analyzes** eleven languages across seven prosodic principles, measures how well a
text fits a declared form, and — for an unknown text — **detects** its language and form, returning
*ranked candidates* rather than a single guess.

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/norwytch/Poietikes.jl")
```

## Quickstart

```julia
using Poietikes

# A known text: supply Form + Language, get a structured fit and a scansion.
a = analyze("ふるいけや\nかわずとびこむ\nみずのおと"; language = :japanese, form = :haiku)
best(a).score.value        # 1.0 — a perfect 5-7-5 mora count
println(scansion(a))

# An unknown text: omit both; language and form are detected, ranked best-first.
analyze("Shall I compare thee to a summer's day")   # → English, Shakespearean sonnet
```

## Contents

- [Adding a language](adding-a-language.md) — the contract a new language frontend must satisfy.
- [vs. Python prosodic](comparison.md) — the shared lineage and where the two diverge.
- [API reference](api.md) — exported functions and types.

The full design and methodology live in the
[README](https://github.com/norwytch/Poietikes.jl#readme).
