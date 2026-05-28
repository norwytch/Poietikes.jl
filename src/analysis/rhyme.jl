# Rhyme fitting: do the lines the scheme marks as rhyming actually rhyme? The rhyme key of a
# line is its rime — from the last primary-stressed vowel to the line end. English derives it
# from CMUdict phonemes (accurate); other languages fall back to a crude orthographic suffix
# until a phonological frontend exists (French via the planned Lexique backend).

function _english_rhyme_key(line::Line)
    syls = Syllable[u for u in line.units if u isa Syllable]
    isempty(syls) && return ""
    li = something(findlast(s -> s.stress == 1, syls), length(syls))   # last stressed (or last)
    key = String[]
    vi = findfirst(isvowel, syls[li].phonemes)                          # from the nucleus onward
    vi === nothing || append!(key, [basephone(p) for p in syls[li].phonemes[vi:end]])
    for k in (li+1):length(syls), p in syls[k].phonemes
        push!(key, basephone(p))
    end
    return join(key, " ")
end

_orthographic_rhyme_key(line::Line) =
    last(lowercase(join(c for c in line.surface if isletter(c))), 3)   # crude suffix rhyme

rhyme_key(line::Line, ::English)  = _english_rhyme_key(line)
rhyme_key(line::Line, ::French)   = _french_rhyme_key(line)     # Lexique phon-based (languages/lexique.jl)
rhyme_key(line::Line, ::Language) = _orthographic_rhyme_key(line)

struct RhymeFit <: AnalysisResult
    scheme::String
    realized::Vector{String}      # rhyme key per line
    total_cost::Int               # scheme-mandated rhyme pairs that don't actually rhyme, + length gap
end

function _rhyme_fit(parsed::ParsedPoem, rs::RhymeSpec, lang::Language)
    ls   = collect(lines(parsed))
    keys = [rhyme_key(l, lang) for l in ls]
    scheme = collect(rs.scheme)
    n = min(length(ls), length(scheme))
    cost = 0
    for i in 1:n, j in (i+1):n
        scheme[i] == scheme[j] || continue        # the scheme says lines i and j rhyme
        (isempty(keys[i]) || keys[i] != keys[j]) && (cost += 1)
    end
    cost += abs(length(ls) - length(scheme))
    return RhymeFit(rs.scheme, keys, cost)
end
