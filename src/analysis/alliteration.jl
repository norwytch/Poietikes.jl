# Consonantal axis: alliteration — onset correspondence on stressed syllables. This is the core
# of the Germanic alliterative tradition (Old English, Old Norse) and a building block of Welsh
# cynghanedd. We model the basic requirement (≥ N stressed syllables per line share an onset; all
# vowels alliterate, keyed "V") on English via CMUdict onsets. Old Norse dróttkvætt's line-pair
# alliteration with internal rhyme (skothending/aðalhending), and Welsh consonant-sequence
# harmony, need their own phonology and a richer correspondence model — deferred.

# The alliteration key of a syllable: its onset's first phoneme (vowels collapse to "V").
function _allit_key(s::Syllable)
    isempty(s.phonemes) && return ""
    p = first(s.phonemes)
    return isvowel(p) ? "V" : String(basephone(p))
end

struct AllitFit <: AnalysisResult
    min_required::Int
    per_line::Vector{Int}              # the most stressed syllables sharing an onset, per line
    keys::Vector{Vector{String}}       # the alliteration keys (one per stressed syllable), per line
    total_cost::Int
end

function _allit_fit(parsed::ParsedPoem, spec::AllitSpec)
    per_line, keysv, cost = Int[], Vector{String}[], 0
    for l in lines(parsed)
        keys = String[_allit_key(u) for u in l.units if u isa Syllable && u.stress == 1]
        push!(keysv, keys)
        counts = Dict{String,Int}()
        for k in keys
            counts[k] = get(counts, k, 0) + 1
        end
        m = isempty(counts) ? 0 : maximum(values(counts))
        push!(per_line, m)
        cost += max(spec.min - m, 0)
    end
    return AllitFit(spec.min, per_line, keysv, cost)
end
