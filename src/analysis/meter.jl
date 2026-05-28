# Metrical representation: a meter is a sequence of positions (weak/strong), built from a
# MeterSpec's foot and length. A MetricalParse maps each position to the syllable(s) filling
# it. Positions may hold one or two syllables — the latter covers feminine endings and
# resolution — which is the source of optionality the OT parser searches over.

abstract type Strength end
struct Strong <: Strength end
struct Weak   <: Strength end

struct Meter
    positions::Vector{Strength}
    kind::MeterKind
end

struct MetricalParse
    meter::Meter
    slots::Vector{Vector{Syllable}}     # slots[i] = syllables in position i (length 1 or 2)
end

# One foot's strength pattern; the meter repeats it `len` times.
foot_pattern(::Type{Iamb})    = Strength[Weak(),   Strong()]
foot_pattern(::Type{Trochee}) = Strength[Strong(), Weak()]
foot_pattern(::Type{Anapest}) = Strength[Weak(),   Weak(),  Strong()]
foot_pattern(::Type{Dactyl})  = Strength[Strong(), Weak(),  Weak()]
foot_pattern(::Type{Spondee}) = Strength[Strong(), Strong()]
foot_pattern(::Type{Pyrrhic}) = Strength[Weak(),   Weak()]

"""
    build_meter(spec::MeterSpec) -> Meter

Construct the metrical template (e.g. iambic pentameter → 10 alternating positions). Only for
foot-based (accentual-syllabic) meter; syllabic and quantitative meters are fit without a
position template (see `_syllabic_fit` / `_quantitative_fit`).
"""
function build_meter(ms::MeterSpec)
    ms.foot === nothing && error("build_meter: meter has no foot (syllabic/quantitative meters skip this)")
    ms.len  === nothing && error("build_meter: meter has no length")
    return Meter(repeat(foot_pattern(ms.foot), ms.len), ms.kind)
end

# ── Candidate generation: partition n syllables into P positions, each of size 1 or 2 ──
# (Sizes outside [P, 2P] can't align under this rule — handled as a length mismatch upstream.)

# All k-subsets of 1:n (which positions are doubled).
function _combinations(n::Int, k::Int)
    (k < 0 || k > n) && return Vector{Int}[]
    out = Vector{Int}[]
    chosen = Int[]
    function rec(start)
        if length(chosen) == k
            push!(out, copy(chosen)); return
        end
        for i in start:n
            push!(chosen, i); rec(i + 1); pop!(chosen)
        end
    end
    rec(1)
    return out
end

function _compositions(n::Int, P::Int)
    d = n - P                                   # number of doubled positions
    (d < 0 || d > P) && return Vector{Vector{Int}}()
    return [_sizes(P, doubled) for doubled in _combinations(P, d)]
end

function _sizes(P::Int, doubled::Vector{Int})
    s = fill(1, P)
    for i in doubled
        s[i] = 2
    end
    return s
end

function _slots(syls::Vector{Syllable}, sizes::Vector{Int})
    slots = Vector{Vector{Syllable}}()
    i = 1
    for sz in sizes
        push!(slots, syls[i:i+sz-1])
        i += sz
    end
    return slots
end
