# French G2P via Lexique (lexique.org) — the French analog of CMUdict. Its biggest payoff is
# *rhyme*: French rhyme is judged on the realized pronunciation (the rime from the last full
# vowel onward), which the orthographic syllabifier can't recover. Verse syllable *counting*
# stays orthographic (the mute-e-before-consonant rule is a convention of verse, not of speech,
# so Lexique's spoken count is the wrong measure there). The dictionary is fetched and cached
# on first use; out-of-vocabulary words fall back to an orthographic rhyme key.

const LEXIQUE_URL = "http://www.lexique.org/databases/Lexique383/Lexique383.tsv"

# Lexique's phon alphabet: single-char symbols, with nasal vowels written as "X~" (a~, o~, …).
function _phon_tokens(phon::AbstractString)
    cs = collect(phon)
    toks = Phoneme[]
    i = 1
    while i <= length(cs)
        if i < length(cs) && cs[i+1] == '~'
            push!(toks, Phoneme(string(cs[i], '~'))); i += 2
        else
            push!(toks, Phoneme(string(cs[i]))); i += 1
        end
    end
    return toks
end

"Parse the Lexique TSV (tab-separated; columns ortho, phon, …) into word => phonemes."
function _parse_lexique(io::IO)
    table = Dict{String,Vector{Phoneme}}()
    first = true
    for raw in eachline(io)
        if first                            # skip the header row
            first = false; continue
        end
        cols = split(raw, '\t')
        length(cols) >= 2 || continue
        get!(table, lowercase(cols[1]), _phon_tokens(cols[2]))
    end
    return table
end

function _lexique_path()
    dir = joinpath(first(DEPOT_PATH), "poietikes")
    isdir(dir) || mkpath(dir)
    return joinpath(dir, "Lexique383.tsv")
end

function _load_lexique()
    path = _lexique_path()
    isfile(path) || Downloads.download(LEXIQUE_URL, path)
    return open(_parse_lexique, path)
end

mutable struct LexiqueBackend <: G2PBackend
    table::Union{Dict{String,Vector{Phoneme}},Nothing}
end
LexiqueBackend() = LexiqueBackend(nothing)
function pronounce(b::LexiqueBackend, w::AbstractString, ::French)
    b.table === nothing && (b.table = _load_lexique())     # lazy: fetch+parse once
    return get(b.table, lowercase(w), nothing)
end

# French rhyme key: the rime of the last word — from its last full (non-schwa) vowel to the end
# of its pronunciation. Falls back to the orthographic key when the word is out of vocabulary.
const _FR_PHON_VOWELS = Set(["a", "i", "y", "u", "e", "E", "2", "9", "o", "O",
                             "a~", "o~", "e~", "9~", "5"])
function _french_rhyme_key(line::Line)
    ws = [lowercase(m.match) for m in eachmatch(r"[\p{L}']+", line.surface)]
    isempty(ws) && return ""
    phon = pronounce(g2p_backend(French()), last(ws), French())
    phon === nothing && return _orthographic_rhyme_key(line)
    syms = [p.symbol for p in phon]
    vi = findlast(s -> s in _FR_PHON_VOWELS, syms)
    return vi === nothing ? _orthographic_rhyme_key(line) : join(syms[vi:end], " ")
end

# Default G2P backends, installed in __init__ (no fetch at load — both are lazy).
function _register_g2p_defaults!()
    set_backend!(English(), _english_backend())
    set_backend!(French(), ChainBackend(G2PBackend[LexiqueBackend()]))
end
