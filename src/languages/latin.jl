# Latin frontend: classical scansion → syllables with quantitative weight (light/heavy).
#
# A syllable is heavy if its vowel is long by nature (macron) or a diphthong, or long by
# position — followed by ≥2 consonants (the first closes the syllable), counting across word
# boundaries as classical scansion does. The rules match Sanskrit's, so weighting reuses
# `_iast_weights` over a Latin token stream. Vowel length must be marked (macrons): orthography
# alone underdetermines it (the same dictionary gap noted for other languages). Handled here:
# diphthongs, consonantal i/j (intervocalic or word-initial before a vowel → onset, e.g. Trōiae
# = Trō-jae), qu / x / z, and h (no weight). NOT yet handled (roadmap): elision, muta-cum-liquida
# correption (a stop+liquid cluster may leave the prior vowel short), and yati word-boundary.

const _LAT_LONG_V  = Set(['ā', 'ē', 'ī', 'ō', 'ū', 'ȳ'])
const _LAT_SHORT_V = Set(['a', 'e', 'i', 'o', 'u', 'y'])
const _LAT_DIPH    = Set(["ae", "au", "oe"])                       # reliable diphthongs → heavy
# (eu/ei/ui omitted on purpose: diphthongal only in a few words — cui, seu — but hiatus in many
#  common ones — deus, meus, fuit, tenuis — where treating them as one syllable would mis-scan.)

_lat_isvowel(c::Char) = c in _LAT_LONG_V || c in _LAT_SHORT_V

function _latin_tokens(s::AbstractString)
    cs = collect(lowercase(s))
    toks = Tuple{Symbol,Bool}[]
    i, n = 1, length(cs)
    boundary = true                                                    # at line start or after a space/punct
    while i <= n
        c = cs[i]
        two = i < n ? string(c, cs[i+1]) : ""
        if two in _LAT_DIPH
            push!(toks, (:vowel, true)); i += 2; boundary = false
        elseif (c == 'i' || c == 'j') && i < n && _lat_isvowel(cs[i+1]) &&
               (boundary || (!isempty(toks) && toks[end][1] === :vowel))
            push!(toks, (:cons, false)); i += 1; boundary = false      # consonantal i (j)
        elseif c in _LAT_LONG_V
            push!(toks, (:vowel, true)); i += 1; boundary = false
        elseif c in _LAT_SHORT_V
            push!(toks, (:vowel, false)); i += 1; boundary = false
        elseif c == 'q' && i < n && cs[i+1] == 'u'
            push!(toks, (:cons, false)); i += 2; boundary = false      # qu = one consonant
        elseif c == 'x' || c == 'z'
            push!(toks, (:cons, false)); push!(toks, (:cons, false)); i += 1   # double consonant
        elseif c == 'h'
            i += 1                                                     # h makes no position
        elseif isletter(c)
            push!(toks, (:cons, false)); i += 1; boundary = false
        else
            isspace(c) && push!(toks, (:boundary, false))              # word break (for yati)
            i += 1; boundary = true
        end
    end
    return toks
end

function prosodic_parse(text::AbstractString, lang::Latin)
    stanzas = Stanza[]
    for block in _split_stanzas(text)
        ls = Line[]
        for ln in split(block, '\n')
            isempty(strip(ln)) && continue
            toks = _latin_tokens(ln)                                   # same guru/laghu logic as Sanskrit
            w, wf = _iast_weights(toks), _word_final_flags(toks)
            units = ProsodicUnit[Syllable(Phoneme[], 0, false, wf[i], w[i]) for i in eachindex(w)]
            push!(ls, Line(units, String(strip(ln))))
        end
        isempty(ls) || push!(stanzas, Stanza(ls))
    end
    return ParsedPoem(lang, stanzas, String(text))
end

# Latin dactylic hexameter (the foot-alternative search lives in analysis/quantitative.jl).
meterspec(::Hexameter, ::Latin) =
    MeterSpec(Quantitative(), nothing, nothing, nothing, Int[], Char[], dactylic_hexameter())
