# Optimality-Theoretic metrical parsing (Hanson–Kiparsky lineage). Each constraint is a type
# with a `violations(constraint, parse)` method and a `weight`, so the set is extended by
# dispatch — add a type and two methods, no central table to edit. The parser searches
# candidate parses and returns the one minimizing the *weighted* total (Harmonic Grammar).
#
# The weights encode the well-known hierarchy: a stress maximum in a weak position is the
# cardinal violation; an unstressed beat (trough in strong) is serious but lesser; clash,
# lapse, and weight-sensitivity are softer rhythmic/quantitative preferences. Calibration of
# these weights against a corpus is tracked deferred work; the values here are principled defaults.

abstract type MetricalConstraint end

"""
    violations(constraint, parse) -> Int

Number of times `parse` violates `constraint` (≥ 0). The extension point for new constraints.
"""
function violations end

"""
    weight(constraint, cal = default_calibration()) -> Float64

Severity of the constraint in the weighted total. Reads `cal`'s per-constraint overrides (set via
`set_constraint_weight!`, e.g. by a weight learner), falling back to the principled default.
"""
weight(c::MetricalConstraint, cal::Calibration = default_calibration()) =
    get(cal.constraint_weights, typeof(c), _default_weight(c))

"""
    set_constraint_weight!(ConstraintType, w)
    reset_constraint_weights!()

Override (or clear all) metrical-constraint weights in the default `Calibration` — the knob a
calibrator/learner tunes. For reproducible runs, build a `Calibration` with explicit
`constraint_weights` and pass it to `analyze` rather than mutating the default.
"""
set_constraint_weight!(::Type{C}, w::Real) where {C<:MetricalConstraint} =
    (default_calibration().constraint_weights[C] = Float64(w); nothing)
reset_constraint_weights!() = (empty!(default_calibration().constraint_weights); nothing)

_default_weight(::MetricalConstraint) = 1.0

# Prominence order: primary stress (1) > secondary (2) > unstressed (0). (ARPABET digits don't
# rank numerically, so we remap.)
prominence(s::Syllable) = s.stress == 1 ? 2 : s.stress == 2 ? 1 : 0

# Realized prominence: a flexible (monosyllabic-word) syllable's stress is assigned by the
# meter — full in a strong position, none in a weak one — so it never fights the template.
# Lexical stress in polysyllabic words is fixed. This is the Hanson–Kiparsky treatment that
# keeps CMUdict's citation stress on monosyllables ("the", "to", "thee") from faking clashes.
realized_prominence(s::Syllable, strength::Strength) =
    s.flexible ? (strength isa Strong ? 2 : 0) : prominence(s)

# Syllable weight (quantity): heavy = long vowel/diphthong nucleus, or a coda consonant
# (closed syllable). Light = open syllable with a short/lax vowel.
const _LONG_VOWELS = Set(["AA", "AO", "ER", "IY", "UW", "EY", "AY", "OW", "AW", "OY"])

function _has_coda(s::Syllable)
    vi = findfirst(isvowel, s.phonemes)
    vi === nothing && return false
    return any(!isvowel, @view s.phonemes[vi+1:end])
end

is_heavy(s::Syllable) =
    (vi = findfirst(isvowel, s.phonemes)) !== nothing &&
    (basephone(s.phonemes[vi]) in _LONG_VOWELS || _has_coda(s))

# Whether a syllable may share a metrical position (resolution). A flexible monosyllable
# reduces when destressed (its citation vowel shortens), so only a coda consonant keeps it
# heavy — "to" resolves, "shake" does not. A fixed (polysyllable-internal) syllable resolves
# only if it is lexically light and unstressed.
_resolvable(s::Syllable) = s.flexible ? !_has_coda(s) : (!is_heavy(s) && s.stress == 0)

# Linearize a parse back to (syllables, position-strengths) in surface order.
function _linearize(p::MetricalParse)
    seq, str = Syllable[], Strength[]
    for (pos, syls) in zip(p.meter.positions, p.slots)
        for s in syls
            push!(seq, s)
            push!(str, pos)
        end
    end
    return seq, str
end

# Linearize, plus the realized prominence of each syllable (the basis for stress constraints).
function _realized(p::MetricalParse)
    seq, str = _linearize(p)
    pr = Int[realized_prominence(seq[i], str[i]) for i in eachindex(seq)]
    return seq, str, pr
end

# A line-internal peak (more prominent than both neighbors) / trough (less than both).
ispeak(pr, i)   = 1 < i < length(pr) && pr[i] > pr[i-1] && pr[i] > pr[i+1]
istrough(pr, i) = 1 < i < length(pr) && pr[i] < pr[i-1] && pr[i] < pr[i+1]

# ── The constraints ──

# Cardinal generative-metrics constraint: a stress maximum in a weak position. Line-initial/
# final syllables are never maxima, so initial trochaic inversions are correctly permitted.
struct StressMaxInWeak <: MetricalConstraint end
function violations(::StressMaxInWeak, p::MetricalParse)
    _, str, pr = _realized(p)
    return count(i -> ispeak(pr, i) && str[i] isa Weak, eachindex(pr))
end
_default_weight(::StressMaxInWeak) = 4.0

# Dual constraint: a stress trough (an unstressed dip) landing on a strong position — an
# unfilled beat.
struct TroughInStrong <: MetricalConstraint end
function violations(::TroughInStrong, p::MetricalParse)
    _, str, pr = _realized(p)
    return count(i -> istrough(pr, i) && str[i] isa Strong, eachindex(pr))
end
_default_weight(::TroughInStrong) = 2.0

# Stress clash: two adjacent primary-stressed syllables.
struct Clash <: MetricalConstraint end
function violations(::Clash, p::MetricalParse)
    _, _, pr = _realized(p)
    return count(i -> pr[i] == 2 && pr[i+1] == 2, 1:length(pr)-1)
end

# Stress lapse: a run of three or more consecutive unstressed syllables (one per run).
struct Lapse <: MetricalConstraint end
function violations(::Lapse, p::MetricalParse)
    _, _, pr = _realized(p)
    v, run = 0, 0
    for x in pr
        run = x == 0 ? run + 1 : 0
        run == 3 && (v += 1)
    end
    return v
end

# Weight-sensitivity (Hanson–Kiparsky parameter): a heavy syllable in a weak position. Kept
# available for quantity-sensitive traditions but NOT in the English default set — English
# accentual-syllabic meter is governed by stress, not quantity, so this just adds noise here.
struct HeavyInWeak <: MetricalConstraint end
function violations(::HeavyInWeak, p::MetricalParse)
    seq, str = _linearize(p)
    return count(i -> str[i] isa Weak && is_heavy(seq[i]), eachindex(seq))
end
_default_weight(::HeavyInWeak) = 0.5

# Complexity cost: a position holding more than one syllable.
struct PositionSize <: MetricalConstraint end
violations(::PositionSize, p::MetricalParse) = count(s -> length(s) > 1, p.slots)

# Resolution restriction: a doubly-filled position is legal only if BOTH its syllables are
# resolvable (light and unstressable). Near-categorical (high weight) so the parser cannot
# split a stressed or heavy syllable across a position merely to shift the alignment and dodge
# a stress violation — the over-permissiveness that let off-length lines escape judgment.
struct IllegalResolution <: MetricalConstraint end
violations(::IllegalResolution, p::MetricalParse) =
    count(slot -> length(slot) > 1 && !all(_resolvable, slot), p.slots)
_default_weight(::IllegalResolution) = 10.0

# Short, stable names for the per-line breakdown (types → Symbol at the edge).
name(::StressMaxInWeak) = :max_in_weak
name(::TroughInStrong)  = :trough_in_strong
name(::Clash)           = :clash
name(::Lapse)           = :lapse
name(::HeavyInWeak)       = :heavy_in_weak
name(::PositionSize)      = :position_size
name(::IllegalResolution) = :illegal_resolution

default_constraints() = MetricalConstraint[
    StressMaxInWeak(), TroughInStrong(), Clash(), Lapse(), PositionSize(), IllegalResolution(),
]

"""
    best_parse(meter, syllables, constraints=default_constraints())
        -> (parse, cost, breakdown)

The alignment of `syllables` onto `meter` minimizing the weighted total violation (`cost`).
`breakdown` is the raw per-constraint counts of the winning parse. If the syllable count can't
align (outside `[P, 2P]` positions), returns `(nothing, |n−P|, [:length_mismatch => …])`.
"""
# A line that can't align to the meter (outside [P, 2P] syllables) is penalised per missing/
# extra syllable at roughly the cardinal-constraint weight — a wrong-length line is at least as
# unmetrical as a stress fault, so it must score low rather than near a clean fit.
const _LENGTH_MISMATCH_WEIGHT = 4

function best_parse(meter::Meter, syls::Vector{Syllable}, constraints = default_constraints(),
                    cal::Calibration = default_calibration())
    P, n = length(meter.positions), length(syls)
    combos = _compositions(n, P)
    if isempty(combos)
        return (nothing, _LENGTH_MISMATCH_WEIGHT * abs(n - P),
                Pair{Symbol,Int}[:length_mismatch => abs(n - P)])
    end
    best, bestcost, bestbreak = nothing, Inf, Pair{Symbol,Int}[]
    for sizes in combos
        parse  = MetricalParse(meter, _slots(syls, sizes))
        counts = [(c, violations(c, parse)) for c in constraints]
        cost   = sum(weight(c, cal) * v for (c, v) in counts; init = 0.0)
        if cost < bestcost
            best, bestcost = parse, cost
            bestbreak = Pair{Symbol,Int}[name(c) => v for (c, v) in counts]
        end
    end
    return (best, bestcost, bestbreak)
end

# ── The prescriptive result of fitting a line / poem against a meter ──
struct LineFit
    line::Line
    parse::Union{MetricalParse,Nothing}
    cost::Float64                           # weighted total violation for this line's best parse
    breakdown::Vector{Pair{Symbol,Int}}
end

struct FormFit <: AnalysisResult
    meter::Meter
    linefits::Vector{LineFit}
    total_violations::Float64
end

function _metrical_fit(parsed::ParsedPoem, ms::MeterSpec, cal::Calibration = default_calibration())
    meter = build_meter(ms)
    constraints = default_constraints()
    linefits = LineFit[]
    for l in lines(parsed)
        syls = Syllable[u for u in l.units if u isa Syllable]
        parse, cost, breakdown = best_parse(meter, syls, constraints, cal)
        push!(linefits, LineFit(l, parse, cost, breakdown))
    end
    return FormFit(meter, linefits, sum(lf.cost for lf in linefits; init = 0.0))
end

"""
    fit(form, language, parsed) -> AnalysisResult

Fit a poem against a form's declared constraints: accentual-syllabic meter → `FormFit`,
quantitative meter → `QuantitativeFit`, syllabic meter (Romance) → `SyllabicFit`, the count
axis (haiku/tanka) → `CountFit`. Forms declaring none of these fall back to descriptive
features (rhyme/structure-only forms — until those axes are fit).
"""
function fit(form::Form, lang::Language, parsed::ParsedPoem, cal::Calibration = default_calibration())
    ms = meterspec(form, lang)
    if ms !== nothing
        ms.foot !== nothing      && return _metrical_fit(parsed, ms, cal) # accentual-syllabic (foot-based)
        if ms.kind isa Quantitative                                      # quantitative (L/H)
            return isempty(ms.feet) ? _quantitative_fit(parsed, ms) :    #   fixed pattern (Sanskrit)
                                      _quantitative_search(parsed, ms)   #   foot alternatives (Greek/Latin)
        end
        ms.kind isa Tonal        && return _tonal_fit(parsed, ms)        # tonal (P/Z pattern)
        return _syllabic_fit(parsed, ms)                                 # syllabic (Romance: count + caesura)
    end
    cs = countspec(form, lang)
    cs !== nothing && return _count_fit(parsed, cs)
    mts = matraspec(form, lang)
    mts !== nothing && return _matra_fit(parsed, mts)
    als = allitspec(form, lang)
    als !== nothing && return _allit_fit(parsed, als)
    rs = rhymespec(form, lang)
    rs !== nothing && return _rhyme_fit(parsed, rs, lang)
    ss = structurespec(form, lang)
    ss !== nothing && return _structure_fit(parsed, ss)
    return features(parsed)
end
