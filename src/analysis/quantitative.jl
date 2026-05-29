# Quantitative-meter fitting: the shared principle of Sanskrit, classical Arabic (al-Khalīl),
# and Greek/Latin verse — a line realizes a pattern of light/heavy syllables.
#
# Two shapes of target. A *fixed* pattern (Sanskrit varṇa metres) is one sequence of 'L'/'H'
# (with '.' for anceps); each line is compared position by position. A *foot-alternative* metre
# (Greek/Latin, Arabic) is a sequence of feet where each foot may be realized several ways —
# dactyl (— ∪ ∪) may contract to spondee (— —), and these substitutions are independent per
# foot, so no single fixed string describes the line. There we search the cartesian product of
# foot realizations for the target best matching each line — the quantitative analog of the
# accentual OT search in `best_parse`.

struct QuantitativeFit <: AnalysisResult
    pattern::Vector{Char}
    actual::Vector{String}        # per line: the realized L/H string
    total_cost::Int               # per-position mismatches + length differences
    matched::Vector{String}       # foot-search path: the winning foot realization per line (else empty)
end
QuantitativeFit(pattern, actual, total_cost) = QuantitativeFit(pattern, actual, total_cost, String[])

_weight_char(s::Syllable) = something(s.heavy, is_heavy(s)) ? 'H' : 'L'

# Yati: a quantitative metre may require a word boundary after a fixed syllable position (the
# L/H analog of the Romance caesura). Cost 1 per line whose syllable there is not word-final.
function _yati_cost(parsed::ParsedPoem, ms::MeterSpec)
    ms.caesura === nothing && return 0
    cost = 0
    for l in lines(parsed)
        syls = Syllable[u for u in l.units if u isa Syllable]
        (ms.caesura <= length(syls) && syls[ms.caesura].word_final) || (cost += 1)
    end
    return cost
end

function _quantitative_fit(parsed::ParsedPoem, ms::MeterSpec)
    pat = ms.pattern
    rows, cost = String[], 0
    for l in lines(parsed)
        w = [_weight_char(u) for u in l.units if u isa Syllable]
        push!(rows, String(w))
        for i in 1:min(length(w), length(pat))
            pat[i] == '.' && continue          # anceps: either weight accepted
            w[i] == pat[i] || (cost += 1)
        end
        cost += abs(length(w) - length(pat))
    end
    return QuantitativeFit(pat, rows, cost + _yati_cost(parsed, ms))
end

# ── Foot-alternative quantitative metre (Greek/Latin, Arabic) ──

# Classical feet, as the L/H realizations each may take (— = H, ∪ = L). The biceps of a dactyl
# may contract: a foot is dactyl OR spondee. The final foot is — × (long + anceps, i.e. brevis
# in longo), expressed by allowing either weight in the last position.
const _DACTYL_SPONDEE = ["HLL", "HH"]       # — ∪∪  /  — —
const _FINAL_FOOT     = ["HH", "HL"]        # — —   /  — ∪   (anceps)

"Dactylic hexameter: five dactyl⇄spondee feet then a disyllabic final foot (brevis in longo)."
dactylic_hexameter() =
    [_DACTYL_SPONDEE, _DACTYL_SPONDEE, _DACTYL_SPONDEE, _DACTYL_SPONDEE, _DACTYL_SPONDEE, _FINAL_FOOT]

"""
    final_anceps(pattern) -> Vector{Char}

The fixed quantitative `pattern` with its last position made anceps ('.'): the line-final
syllable's weight becomes indifferent (brevis in longo), as most Sanskrit and classical metres
allow. A convenience over hand-writing the wildcard.
"""
final_anceps(pattern::AbstractVector{Char}) = isempty(pattern) ? Char[] : [pattern[1:end-1]; '.']
final_anceps(pattern::AbstractString) = final_anceps(collect(pattern))

# Every concatenation of one realization per foot — the candidate target strings to fit against.
function _expand_feet(feet::Vector{Vector{String}})
    targets = String["" ]
    for alts in feet
        targets = String[t * a for t in targets for a in alts]
    end
    return targets
end

# Cost of realizing `actual` against one candidate `target`: per-position weight mismatches
# (with '.' an anceps wildcard) plus any length difference.
function _quant_line_cost(actual::AbstractString, target::AbstractString)
    cost = abs(length(actual) - length(target))
    for i in 1:min(length(actual), length(target))
        target[i] == '.' && continue
        actual[i] == target[i] || (cost += 1)
    end
    return cost
end

function _quantitative_search(parsed::ParsedPoem, ms::MeterSpec)
    targets = _expand_feet(ms.feet)
    rows, matched, cost = String[], String[], 0
    for l in lines(parsed)
        w = String(Char[_weight_char(u) for u in l.units if u isa Syllable])
        c, bestfit = minimum(((_quant_line_cost(w, t), t) for t in targets))
        push!(rows, w); push!(matched, bestfit); cost += c
    end
    return QuantitativeFit(Char[], rows, cost + _yati_cost(parsed, ms), matched)
end
