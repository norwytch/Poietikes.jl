# Welsh cynghanedd — consonant-sequence harmony, the last of the consonantal traditions and the
# only one turning on a *sequence* correspondence rather than a single onset. Like dróttkvætt it
# needs a composite fit (count + harmony), so it gets its own `fit(::Cywydd, ::Welsh, …)`.
#
# We model cynghanedd groes/draws (cross-harmony): the line divides into two parts, and the ordered
# consonant sequence of the first answers that of the second. Computationally: there exists a word
# boundary splitting the line such that the two halves have the same consonant sequence (digraphs
# collapsed, vowels dropped). This is a simplification — full cynghanedd frees the post-tonic
# consonants and admits sain (chiming) and lusg (trailing-rhyme) types — but it captures the
# distinctive consonant-repetition that no other axis expresses.

struct CynghaneddFit <: AnalysisResult
    syllables::Vector{Int}        # per line
    count_cost::Int               # Σ|syllables − 7|
    harmony_cost::Int             # lines with no consonant-sequence answer
    total_cost::Int
end

# 0 if some word-boundary split gives the two halves equal (non-empty) consonant sequences, else 1.
function _cynghanedd_line_cost(surface::AbstractString)
    words = String[m.match for m in eachmatch(r"\p{L}+", surface)]
    length(words) < 2 && return 1
    for k in 1:(length(words) - 1)
        left  = _welsh_cons_seq(join(words[1:k], " "))
        right = _welsh_cons_seq(join(words[k+1:end], " "))
        (!isempty(left) && left == right) && return 0
    end
    return 1
end

function _cynghanedd_fit(parsed::ParsedPoem)
    ls = collect(lines(parsed))
    syllables  = Int[count(u -> u isa Syllable, l.units) for l in ls]
    count_cost = sum(abs.(syllables .- 7); init = 0)
    harmony_cost = sum(_cynghanedd_line_cost(l.surface) for l in ls; init = 0)
    return CynghaneddFit(syllables, count_cost, harmony_cost, count_cost + harmony_cost)
end

# Seven-syllable count is declared (invariant + documentation); the composite fit adds harmony.
countspec(::Cywydd, ::Welsh) = CountSpec(Syllable, [7])
fit(::Cywydd, ::Welsh, parsed::ParsedPoem) = _cynghanedd_fit(parsed)

_score_analysis(a::CynghaneddFit) = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))

function scansion(a::CynghaneddFit)
    head = "cynghanedd (7 syll/line; consonant-sequence harmony):"
    rows = ["  line $i: $(a.syllables[i]) syllables" for i in eachindex(a.syllables)]
    return head * "\n" * join(rows, "\n") * "\n  costs — count $(a.count_cost), harmony $(a.harmony_cost)"
end
