# Grapheme-to-phoneme: a pluggable backend abstraction, dispatched like everything else.
# A backend answers "phonemes for one word, or nothing if it doesn't know it"; composition
# and fallback live above it. The default English backend (set in __init__) fetches CMUdict
# on first use and caches it, with a rule-based fallback for out-of-vocabulary words.

abstract type G2PBackend end

"""
    pronounce(backend, word, language) -> Union{Vector{Phoneme},Nothing}

Phoneme sequence for one (case-insensitive) word, or `nothing` if this backend doesn't know it.
"""
function pronounce end

# Dictionary-backed: CMUdict once loaded, or a small in-memory stub (used in tests).
struct DictBackend <: G2PBackend
    table::Dict{String,Vector{Phoneme}}
end
pronounce(b::DictBackend, w::AbstractString, ::Language) = get(b.table, lowercase(w), nothing)

# Try each backend in order; first hit wins. Composes "CMUdict, then rules".
struct ChainBackend <: G2PBackend
    backends::Vector{G2PBackend}
end
function pronounce(b::ChainBackend, w::AbstractString, lang::Language)
    for bk in b.backends
        r = pronounce(bk, w, lang)
        r === nothing || return r
    end
    return nothing
end

# Default-backend registry, keyed by Language type (pluggable: swap via set_backend!).
const _G2P = Dict{DataType,G2PBackend}()
set_backend!(l::Language, b::G2PBackend) = (_G2P[typeof(l)] = b; nothing)
function g2p_backend(l::Language)
    haskey(_G2P, typeof(l)) || throw(ArgumentError(
        "no G2P backend registered for $(typeof(l)); register one with set_backend!"))
    return _G2P[typeof(l)]
end

# ── Tokenization (whitespace + punctuation; WordTokenizers.jl is a later upgrade) ──
_words(text::AbstractString) = [lowercase(m.match) for m in eachmatch(r"[A-Za-z']+", text)]
_split_stanzas(text::AbstractString) = split(text, r"\n[ \t]*\n")     # blank line = stanza break

# ── ARPABET helpers (general; English reaches them via CMUdict) ──
const _ARPABET_VOWELS = Set([
    "AA","AE","AH","AO","AW","AY","EH","ER","EY","IH","IY","OW","OY","UH","UW",
])

basephone(p::Phoneme) = rstrip(p.symbol, ('0', '1', '2'))     # drop stress digit
isvowel(p::Phoneme)   = basephone(p) in _ARPABET_VOWELS
stressof(p::Phoneme)  = (c = last(p.symbol); isdigit(c) ? c - '0' : 0)

# Sonority scale for the Maximum Onset Principle (higher = more sonorous).
function sonority(p::Phoneme)
    b = basephone(p)
    b in _ARPABET_VOWELS                            && return 7
    b in ("W", "Y")                                 && return 6   # glides
    b in ("L", "R")                                 && return 5   # liquids
    b in ("M", "N", "NG")                           && return 4   # nasals
    b in ("F","V","TH","DH","S","Z","SH","ZH","HH") && return 3   # fricatives
    b in ("CH", "JH")                               && return 2   # affricates
    return 1                                                       # stops
end

# Split an intervocalic consonant cluster into (coda-of-previous, onset-of-next) by Maximum
# Onset: the onset is the longest suffix whose sonority strictly rises toward the nucleus,
# plus the English /s/+voiceless-stop exception (so "extra" splits ...k.str...).
function _split_cluster(cons::AbstractVector{Phoneme})
    n = length(cons)
    n == 0 && return (0, 0)
    k = n                                       # onset = cons[k:end]; starts as the last consonant
    while k > 1 && sonority(cons[k-1]) < sonority(cons[k])
        k -= 1
    end
    if k > 1 && basephone(cons[k-1]) == "S" && basephone(cons[k]) in ("P", "T", "K")
        k -= 1
    end
    onset = n - k + 1
    return (n - onset, onset)
end

"""
    syllabify_phonemes(phonemes) -> Vector{Syllable}

Group an ARPABET phoneme sequence into syllables (one per vowel nucleus), assigning
consonants by the Maximum Onset Principle. Stress is read from the nucleus's stress digit.
"""
function syllabify_phonemes(phs::AbstractVector{Phoneme})
    nuclei = findall(isvowel, phs)
    isempty(nuclei) && return [Syllable(collect(phs), 0)]   # vowelless: one defective syllable
    syls = Syllable[]
    start = 1
    for (j, nuc) in enumerate(nuclei)
        if j < length(nuclei)
            coda, _ = _split_cluster(@view phs[nuc+1:nuclei[j+1]-1])
            stop = nuc + coda
            push!(syls, Syllable(phs[start:stop], stressof(phs[nuc])))
            start = stop + 1
        else
            push!(syls, Syllable(phs[start:end], stressof(phs[nuc])))
        end
    end
    return syls
end

# Always returns phonemes: backend hit, else rule-based fallback (never nothing).
function pronounce_word(lang::Language, w::AbstractString)
    r = pronounce(g2p_backend(lang), w, lang)
    return r === nothing ? _rule_g2p(lang, w) : r
end

"""
    phonetic_transcribe(text, language) -> Vector{Vector{Phoneme}}

Phoneme sequences for each word of `text`, in order.
"""
phonetic_transcribe(text::AbstractString, lang::Language) =
    [pronounce_word(lang, w) for w in _words(text)]

"""
    syllabify(text, language) -> Vector{Syllable}

All syllables of `text`, in order (structure-flattened; use `prosodic_parse` to keep lines).
"""
function syllabify(text::AbstractString, lang::Language)
    syls = Syllable[]
    for w in _words(text)
        append!(syls, syllabify_phonemes(pronounce_word(lang, w)))
    end
    return syls
end
