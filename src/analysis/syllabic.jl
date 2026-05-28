# Syllabic-meter fitting (Romance verse). The template is not a foot pattern but a syllable
# count plus accent placement. The alexandrine: 12 syllables with a caesura after the 6th (a
# word boundary, on an accentuable syllable). The Italian endecasillabo: the last accent on the
# 10th syllable, the line reckoned by the *ley del acento final* — its metrical length is the
# position of the last accent plus one, so an oxytone ending counts +1 and a proparoxytone −1.

# Metrical line length. Spanish/Italian reckon to the last accent + 1; French (and the default)
# use the raw syllable count (with mute-e already excluded by the parser).
metrical_length(::Language, syls) = length(syls)
function metrical_length(::Union{Spanish,Italian}, syls)
    sp = findlast(s -> s.stress == 1, syls)
    return sp === nothing ? length(syls) : sp + 1
end

struct SyllabicFit <: AnalysisResult
    expected::Int
    actual::Vector{Int}            # metrical length per line (after the final-accent rule)
    caesura::Union{Int,Nothing}
    caesura_ok::Vector{Bool}       # per line: word boundary on an accentuable syllable at the caesura?
    accents::Vector{Int}
    accents_ok::Vector{Bool}       # per line: a word-accent falls on every required position?
    total_cost::Int                # Σ|metrical−expected| + caesura misses + missing accents
end

function _syllabic_fit(parsed::ParsedPoem, ms::MeterSpec)
    target = ms.len
    actual, caes_ok, acc_ok, cost = Int[], Bool[], Bool[], 0
    for l in lines(parsed)
        syls = Syllable[u for u in l.units if u isa Syllable]
        n = length(syls)
        ml = metrical_length(parsed.lang, syls)         # default (minimum); diérèse/dialefa can add
        push!(actual, ml)
        if target !== nothing
            hi = ml + l.expansions                      # Tier-3: target counts as met if reachable in [ml, hi]
            cost += ml > target ? (ml - target) : target > hi ? (target - hi) : 0
        end
        if ms.caesura !== nothing
            ok = ms.caesura <= n && syls[ms.caesura].word_final && syls[ms.caesura].stress == 1
            push!(caes_ok, ok); ok || (cost += 1)
        end
        if !isempty(ms.accents)
            miss = count(a -> !(a <= n && syls[a].stress == 1), ms.accents)
            push!(acc_ok, miss == 0); cost += miss
        end
    end
    return SyllabicFit(something(target, 0), actual, ms.caesura, caes_ok, ms.accents, acc_ok, cost)
end
