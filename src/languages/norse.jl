# Old Norse frontend: normalized orthography → syllables, for the dróttkvætt analysis.
#
# Norse stress is word-initial, so stress needs no dictionary — the first syllable of each word
# is the lift. Onsets, nuclei and codas are read from the (largely phonemic) orthography, each
# grapheme stored as a Phoneme symbol; au/ei/ey are single nuclei. This is a deliberately simple
# orthographic model — enough for the consonantal/rhyme correspondences dróttkvætt turns on
# (alliteration on onsets, hending on rimes), not a full Norse phonology (vowel length, sandhi).

const _NORSE_VOWELS = Set(collect("aeiouyáéíóúýæøœǫöäåü"))
const _NORSE_DIPH   = Set(["au", "ei", "ey"])
_norse_isnucleus(g::AbstractString) = g in _NORSE_DIPH || (length(g) == 1 && first(g) in _NORSE_VOWELS)

# Split a word into graphemes (diphthongs au/ei/ey as one), lowercase.
function _norse_graphemes(word::AbstractString)
    cs = collect(lowercase(word))
    g, i, n = String[], 1, length(cs)
    while i <= n
        two = i < n ? string(cs[i], cs[i+1]) : ""
        if two in _NORSE_DIPH
            push!(g, two); i += 2
        else
            push!(g, string(cs[i])); i += 1
        end
    end
    return g
end

# One word → syllables (one per nucleus), word-initial syllable stressed. A single intervocalic
# consonant onsets the next syllable; a cluster splits, its last consonant onsetting the next.
function _norse_syllables(word::AbstractString)
    g = _norse_graphemes(word)
    nuc = [i for (i, x) in enumerate(g) if _norse_isnucleus(x)]
    isempty(nuc) && return Syllable[]
    syls, start = Syllable[], 1
    for (j, ni) in enumerate(nuc)
        stop = if j < length(nuc)
            ncons = nuc[j+1] - ni - 1            # consonants between this nucleus and the next
            ncons >= 2 ? nuc[j+1] - 2 : ni       # ≥2 ⇒ keep all but the last as coda; else open
        else
            length(g)
        end
        push!(syls, Syllable(Phoneme[Phoneme(x) for x in g[start:stop]], j == 1 ? 1 : 0))
        start = stop + 1
    end
    return syls
end

# A syllable's (onset, nucleus, coda) as strings, from its stored graphemes.
function _norse_parts(s::Syllable)
    syms = String[p.symbol for p in s.phonemes]
    vi = findfirst(_norse_isnucleus, syms)
    vi === nothing && return (join(syms), "", "")
    return (join(syms[1:vi-1]), syms[vi], join(syms[vi+1:end]))
end

function prosodic_parse(text::AbstractString, lang::Norse)
    stanzas = Stanza[]
    for block in _split_stanzas(text)
        ls = Line[]
        for ln in split(block, '\n')
            isempty(strip(ln)) && continue
            units = ProsodicUnit[]
            for m in eachmatch(r"\p{L}+", ln)
                append!(units, _norse_syllables(m.match))
            end
            push!(ls, Line(units, String(strip(ln))))
        end
        isempty(ls) || push!(stanzas, Stanza(ls))
    end
    return ParsedPoem(lang, stanzas, String(text))
end
