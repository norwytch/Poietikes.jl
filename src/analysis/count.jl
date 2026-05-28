# Count-fitting: does each line hit its declared unit count (haiku 5-7-5, tanka 5-7-5-7-7)?
# The unit is whatever the form's CountSpec names — morae in Japanese, syllables in English —
# and the parse already produced units of that type for the language, so counting is uniform.

struct CountFit <: AnalysisResult
    unit::Type{<:ProsodicUnit}
    expected::Vector{Int}
    actual::Vector{Int}
    total_distance::Int        # summed |expected − actual|, plus unmatched lines on either side
end

function _count_fit(parsed::ParsedPoem, cs::CountSpec)
    actual = Int[count(u -> u isa cs.unit, l.units) for l in lines(parsed)]
    expected = cs.counts
    n = min(length(expected), length(actual))
    d = sum(abs(expected[i] - actual[i]) for i in 1:n; init = 0)
    d += sum(expected[n+1:end]; init = 0)      # lines the form expects but the poem lacks
    d += sum(actual[n+1:end]; init = 0)        # lines the poem has but the form doesn't expect
    return CountFit(cs.unit, expected, actual, d)
end
