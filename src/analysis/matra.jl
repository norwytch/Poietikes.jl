# Moraic (mātrā) fitting — the second Sanskrit metrical system (mātrāchandas), alongside the
# syllable-pattern varṇa metres. A mātrā meter is defined by a target *mora* count per line,
# where a light (laghu) syllable is 1 mātrā and a heavy (guru) syllable is 2. It reuses the
# syllable weight already computed by the parse; only the aggregation differs from QuantitativeFit
# (sum of weights, not a position-by-position pattern).

struct MatraFit <: AnalysisResult
    expected::Vector{Int}
    actual::Vector{Int}        # mātrās per line (laghu = 1, guru = 2)
    total_distance::Int
end

_matra(s::Syllable) = something(s.heavy, is_heavy(s)) ? 2 : 1

function _matra_fit(parsed::ParsedPoem, ms::MatraSpec)
    actual = Int[sum(_matra(u) for u in l.units if u isa Syllable; init = 0) for l in lines(parsed)]
    expected = ms.counts
    n = min(length(expected), length(actual))
    d = sum(abs(expected[i] - actual[i]) for i in 1:n; init = 0)
    d += sum(expected[n+1:end]; init = 0)
    d += sum(actual[n+1:end]; init = 0)
    return MatraFit(expected, actual, d)
end
