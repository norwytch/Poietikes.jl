# Quantitative-meter fitting: the shared principle of Sanskrit, classical Arabic (al-Khalīl),
# and Greek/Latin verse — a line realizes a fixed pattern of light/heavy syllables. The target
# pattern is a sequence of 'L'/'H' (with '.' as a wildcard for anceps positions); each line's
# realized weights are compared position by position.

struct QuantitativeFit <: AnalysisResult
    pattern::Vector{Char}
    actual::Vector{String}        # per line: the realized L/H string
    total_cost::Int               # per-position mismatches + length differences
end

_weight_char(s::Syllable) = something(s.heavy, is_heavy(s)) ? 'H' : 'L'

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
    return QuantitativeFit(pat, rows, cost)
end
