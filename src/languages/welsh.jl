# Welsh frontend: orthography → consonant sequence + syllable count, for the cynghanedd analysis.
#
# Welsh orthography is largely phonemic once its digraphs are read as single consonants (ch dd ff
# ng ll ph rh th, and the nasal-mutation trigraphs ngh/mh/nh). Cynghanedd ("harmony") is built on
# the ordered sequence of CONSONANTS in a line, so the frontend's job is to extract that sequence
# (digraph-aware, vowels dropped) and to count syllables (one per vowel group). Stress is regular
# (penultimate) and not needed for cynghanedd groes. This is a simplified orthographic model — it
# does not disambiguate ng (/ŋ/) from n+g, nor resolve every diphthong, which a full Welsh
# phonology would.

const _WELSH_VOWELS   = Set(collect("aeiouwyâêîôûŵŷáéíóúàèìòùäëïöü"))
const _WELSH_DIGRAPHS = ["ngh", "mh", "nh", "ng", "ch", "dd", "ff", "ll", "ph", "rh", "th"]  # longest first

# The ordered consonant sequence of a string: digraphs collapsed to one token, vowels dropped.
function _welsh_cons_seq(s::AbstractString)
    cs = collect(lowercase(s))
    seq, i, n = String[], 1, length(cs)
    while i <= n
        d = findfirst(g -> i + length(g) - 1 <= n && join(cs[i:i+length(g)-1]) == g, _WELSH_DIGRAPHS)
        if d !== nothing
            g = _WELSH_DIGRAPHS[d]
            push!(seq, g); i += length(g)
        elseif cs[i] in _WELSH_VOWELS || !isletter(cs[i])
            i += 1
        else
            push!(seq, string(cs[i])); i += 1
        end
    end
    return seq
end

# One syllable per maximal run of vowels (an approximation of Welsh syllable count).
function _welsh_syllables(word::AbstractString)
    syls, invowel = Syllable[], false
    for c in lowercase(word)
        if c in _WELSH_VOWELS
            invowel || push!(syls, Syllable(Phoneme[], 0))
            invowel = true
        else
            invowel = false
        end
    end
    return syls
end

function prosodic_parse(text::AbstractString, lang::Welsh)
    stanzas = Stanza[]
    for block in _split_stanzas(text)
        ls = Line[]
        for ln in split(block, '\n')
            isempty(strip(ln)) && continue
            units = ProsodicUnit[]
            for m in eachmatch(r"\p{L}+", ln)
                append!(units, _welsh_syllables(m.match))
            end
            push!(ls, Line(units, String(strip(ln))))
        end
        isempty(ls) || push!(stanzas, Stanza(ls))
    end
    return ParsedPoem(lang, stanzas, String(text))
end
