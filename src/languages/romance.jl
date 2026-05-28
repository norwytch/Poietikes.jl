# Romance frontend: rule-based, orthographic syllable counting with stress and synalepha.
# Romance verse counts written/spoken syllables by convention, so (unlike English) no
# pronunciation dictionary is needed.
#
# French applies the e-muet rules (a final mute 'e' elides before a vowel-initial word and is
# uncounted at line end) plus the silent u of qu/gu, and marks each word's tonic (the last
# non-mute syllable) so the caesura can require an accentuable syllable. Spanish and Italian
# split vowel groups by the diphthong/hiatus rule, derive lexical stress from spelling, and
# apply synalepha (a vowel ending one word merges with a vowel starting the next).
#
# Documented approximations: French diérèse/synérèse, aspirated h, and -ent verbs (a lexicon
# is the real fix); Italian antepenultimate stress (not predictable from spelling without a
# lexicon — penultimate is assumed); dialefa (synalepha is always applied).

# ── French ──
const _FR_VOWELS = Set("aeiouyàâäéèêëîïôöùûüÿæœ")
_is_fr_vowel(c::Char) = c in _FR_VOWELS

# Diérèse candidates (Tier-3 count flex): a high vowel (i/u/y) before an open vowel may be read
# as two syllables rather than a glide. Heuristic — over-generates on glides like -ied; the
# real fix is the Lexique backend. Each candidate is one optional +1 to the line's count.
const _FR_OPEN = Set("aàâeéèêëoô")
function _dierese_count(w::AbstractString)
    cs = collect(w)
    return count(i -> cs[i] in ('i', 'u', 'y') && cs[i+1] in _FR_OPEN, 1:length(cs)-1)
end

function _vowel_group_count(s::AbstractString, vowels)
    n, invowel = 0, false
    for c in s
        v = c in vowels
        v && !invowel && (n += 1)
        invowel = v
    end
    return n
end

"""
    _french_syllables(line) -> (Vector{Syllable}, expansions)

French verse syllables: e-muet elision/uncounting, silent qu/gu u, and a marked tonic per word.
`expansions` is how many extra syllables diérèse could add (Tier-3 count flex).
"""
function _french_syllables(line::AbstractString)
    words = [lowercase(m.match) for m in eachmatch(r"[\p{L}']+", line)]
    syls = Syllable[]
    for (wi, w) in enumerate(words)
        has_mute, body = false, w
        if endswith(w, "es") && length(w) > 2
            body, has_mute = chop(w; tail = 2), true
        elseif endswith(w, "e")
            body, has_mute = chop(w; tail = 1), true
        end
        b = replace(body, "qu" => "k")
        b = replace(b, r"gu(?=[eiéèêë])" => "g")        # silent u before a front vowel
        B = _vowel_group_count(b, _FR_VOWELS)
        e_counts = false
        if has_mute
            if B == 0
                B, has_mute = 1, false                  # the e is the word's only vowel ("le", "que")
            else
                nextw = wi < length(words) ? words[wi+1] : ""
                line_final = wi == length(words)
                next_vowel = !isempty(nextw) && (_is_fr_vowel(first(nextw)) || first(nextw) == 'h')
                e_counts = !(line_final || next_vowel)  # mute e elides before vowel / at line end
            end
        end
        nsyl = max(B + (e_counts ? 1 : 0), 1)
        tonic = e_counts ? nsyl - 1 : nsyl              # accent is the last non-mute syllable
        for k in 1:nsyl
            push!(syls, Syllable(Phoneme[], k == tonic ? 1 : 0, false, k == nsyl))
        end
    end
    return syls, sum(_dierese_count, words; init = 0)
end

# ── Spanish / Italian ──
const _ES_VOWELS = Set("aeiouáéíóúüy"); const _ES_WEAK = Set("iuüy"); const _ES_ACCENTED = Set("áéíóú")
const _IT_VOWELS = Set("aeiouàèéìíòóùú"); const _IT_WEAK = Set("iu"); const _IT_ACCENTED = Set("àèéìíòóùú")

# Per-nucleus accent flags: adjacent vowels are one nucleus unless both strong, or one is an
# accented weak vowel (í, ú) — then a hiatus splits them.
function _nuclei_accents(word::AbstractString, vowels, weak, accented)
    out, invowel, prevstrong = Bool[], false, false
    for c in word
        if c in vowels
            cstrong = !(c in weak)
            if !invowel || (prevstrong && cstrong)
                push!(out, c in accented)
            else
                out[end] |= (c in accented)
            end
            invowel, prevstrong = true, cstrong
        else
            invowel = false
        end
    end
    return out
end

_diphthong_nuclei(word, vowels, weak) = length(_nuclei_accents(word, vowels, weak, Set{Char}()))

_default_tonic(word, n, ::Spanish) =
    n <= 1 ? n : (last(word) in _ES_VOWELS || last(word) in ('n', 's')) ? n - 1 : n   # llana / aguda
_default_tonic(word, n, ::Italian) = n <= 1 ? n : n - 1                                # penultimate (piana)

# Syllable count and tonic (1-based) of a word: a written accent wins, else the language rule.
function _romance_nuclei(word, vowels, weak, accented, lang)
    acc = _nuclei_accents(word, vowels, weak, accented)
    n = length(acc)
    n == 0 && return (0, 0)
    ai = findfirst(identity, acc)
    return ai === nothing ? (n, _default_tonic(word, n, lang)) : (n, ai)
end

# Returns (syllables, expansions): expansions = synalepha junctions applied, each of which
# dialefa could undo to add a syllable (Tier-3 count flex).
function _romance_syllables(line::AbstractString, vowels, weak, accented, lang)
    syls = Syllable[]
    prev_vend, merges = false, 0
    for m in eachmatch(r"[\p{L}']+", line)
        w = lowercase(m.match)
        n, tonic = _romance_nuclei(w, vowels, weak, accented, lang)
        n = max(n, 1)
        vstart, vend = first(w) in vowels, last(w) in vowels
        for k in 1:n
            stressed = (k == tonic)
            if k == 1 && prev_vend && vstart && !isempty(syls)        # synalepha: merge into previous
                prev = syls[end]
                syls[end] = Syllable(Phoneme[], (prev.stress == 1 || stressed) ? 1 : 0, false, true)
                merges += 1
            else
                push!(syls, Syllable(Phoneme[], stressed ? 1 : 0, false, k == n))
            end
        end
        prev_vend = vend
    end
    return syls, merges
end

# ── Assembly ──
function _romance_parse(text, lang, syllabify_line)
    stanzas = Stanza[]
    for block in _split_stanzas(text)
        ls = Line[]
        for ln in split(block, '\n')
            isempty(strip(ln)) && continue
            syls, expansions = syllabify_line(String(ln))
            push!(ls, Line(ProsodicUnit[syls...], String(strip(ln)), expansions))
        end
        isempty(ls) || push!(stanzas, Stanza(ls))
    end
    return ParsedPoem(lang, stanzas, String(text))
end

prosodic_parse(text::AbstractString, lang::French)  = _romance_parse(text, lang, _french_syllables)
prosodic_parse(text::AbstractString, lang::Spanish) =
    _romance_parse(text, lang, ln -> _romance_syllables(ln, _ES_VOWELS, _ES_WEAK, _ES_ACCENTED, lang))
prosodic_parse(text::AbstractString, lang::Italian) =
    _romance_parse(text, lang, ln -> _romance_syllables(ln, _IT_VOWELS, _IT_WEAK, _IT_ACCENTED, lang))
