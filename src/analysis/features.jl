# Free-verse descriptive features: extracted from any parse, no template assumed. This is the
# default mode of the package — most modern poetry lives here.

struct ProsodicFeatures <: AnalysisResult
    n_stanzas::Int
    n_lines::Int
    syllables_per_line::Vector{Int}
    total_syllables::Int
    stress_per_line::Vector{Vector{Int}}    # stress digit of each syllable, per line
end

stress_of_unit(s::Syllable)    = s.stress
stress_of_unit(::ProsodicUnit) = 0          # units without lexical stress (e.g. Mora)

"""
    features(parsed::ParsedPoem) -> ProsodicFeatures

Line/stanza counts, syllables per line, and the per-line stress profile.
"""
function features(p::ParsedPoem)
    ls  = collect(lines(p))
    spl = [length(l.units) for l in ls]
    str = [Int[stress_of_unit(u) for u in l.units] for l in ls]
    return ProsodicFeatures(length(p.stanzas), length(ls), spl, sum(spl; init = 0), str)
end
