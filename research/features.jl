# Per-poem feature extractors for the exploratory analyses (spectral / information-theoretic /
# embedding / optimal-transport). These read poietikês's parse and fits but live OUTSIDE the
# package — the core stays lean (no FFTW/UMAP/etc. as dependencies); run with `--project=.`.

using Poietikes

"""
    stress_series(parsed) -> Vector{Int}

The poem's **lexical** stress as a ±1 sequence — one entry per syllable, in order across all lines:
`+1` if the syllable carries stress (primary or secondary), `-1` if unstressed. Deliberately
form-independent: it reads each syllable's citation stress, never a meter-assigned realization, so
the downstream spectral/entropy analyses don't presuppose a form. (The meter-*realized* alternation
that peaks cleanly at 0.5 lives in the OT parse — that would be a separate, form-dependent series.)
"""
function stress_series(parsed)
    s = Int[]
    for line in Poietikes.lines(parsed), u in line.units
        u isa Syllable && push!(s, u.stress == 0 ? -1 : 1)
    end
    return s
end

stress_series(text::AbstractString, lang::Language) = stress_series(prosodic_parse(text, lang))

"""
    cost_vector(text, language) -> NamedTuple

The poem's fit score against each supported form for `language` — a point in form-space, the
substrate for the embedding and optimal-transport analyses. Keys are form names, values are
`NormScore`s in `[0, 1]`. (Mapping these onto a fixed cross-language ℝ⁹ *axis* basis is a
normalization step to design on top of this primitive.)
"""
function cost_vector(text::AbstractString, lang::Language)
    ranked = detect_form(text, lang)
    return (; (Poietikes.formname(r.value) => r.score.value for r in ranked)...)
end
