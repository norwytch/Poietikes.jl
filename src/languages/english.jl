# English G2P: CMUdict (fetched and cached) with a rule-based fallback for OOV words, plus
# the English prosodic_parse.

# ── Rule-based fallback for out-of-vocabulary words ──
# We can't recover a real pronunciation cheaply, but we can estimate syllable count via the
# classic vowel-group heuristic and emit that many unstressed schwa nuclei — enough for
# free-verse syllable/line features. (Low-confidence: OOV stress is not recovered.)
function _estimate_syllables_english(w::AbstractString)
    s = replace(lowercase(w), r"[^a-z]" => "")
    isempty(s) && return 0
    groups = count(_ -> true, eachmatch(r"[aeiouy]+", s))
    if endswith(s, "e") && groups > 1 && !endswith(s, "le")
        groups -= 1                                     # silent trailing 'e'
    end
    return max(groups, 1)
end

_rule_g2p(::English, w::AbstractString) =
    [Phoneme("AH0") for _ in 1:max(_estimate_syllables_english(w), 1)]

# A backend wrapper around the rule fallback, so it can sit in a ChainBackend.
struct RuleBackend <: G2PBackend end
pronounce(::RuleBackend, w::AbstractString, lang::English) = _rule_g2p(lang, w)

# ── CMUdict backend: fetch once, cache in the depot, parse lazily on first use ──
const CMUDICT_URL = "https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict"

function _cmudict_path()
    dir = joinpath(first(DEPOT_PATH), "poietikes")
    isdir(dir) || mkpath(dir)
    return joinpath(dir, "cmudict.dict")
end

function _ensure_cmudict()
    path = _cmudict_path()
    isfile(path) || Downloads.download(CMUDICT_URL, path)
    return path
end

"Parse the cmudict.dict format into word => primary pronunciation."
function _parse_cmudict(io::IO)
    table = Dict{String,Vector{Phoneme}}()
    for raw in eachline(io)
        line = strip(raw)
        (isempty(line) || startswith(line, ";;;")) && continue
        c = findfirst('#', line)                            # strip inline comment
        c === nothing || (line = strip(line[1:prevind(line, c)]))
        isempty(line) && continue
        parts = split(line)
        word = parts[1]
        occursin('(', word) && continue                     # skip alternate-pronunciation entries
        get!(table, lowercase(word), [Phoneme(String(p)) for p in parts[2:end]])
    end
    return table
end

_load_cmudict() = open(_parse_cmudict, _ensure_cmudict())

mutable struct CMUDictBackend <: G2PBackend
    table::Union{Dict{String,Vector{Phoneme}},Nothing}
end
CMUDictBackend() = CMUDictBackend(nothing)
function pronounce(b::CMUDictBackend, w::AbstractString, ::English)
    b.table === nothing && (b.table = _load_cmudict())      # lazy: fetch+parse once
    return get(b.table, lowercase(w), nothing)
end

# ── Parse English text into a language-relative prosodic structure ──
function prosodic_parse(text::AbstractString, lang::English)
    stanzas = Stanza[]
    for block in _split_stanzas(text)
        ls = Line[]
        for ln in split(block, '\n')
            isempty(strip(ln)) && continue
            units = ProsodicUnit[]
            for w in _words(ln)
                wsyls = syllabify_phonemes(pronounce_word(lang, w))
                if length(wsyls) == 1               # monosyllabic word: stress is flexible
                    s = wsyls[1]
                    wsyls[1] = Syllable(s.phonemes, s.stress, true)
                end
                append!(units, wsyls)
            end
            push!(ls, Line(units, String(strip(ln))))
        end
        isempty(ls) || push!(stanzas, Stanza(ls))
    end
    return ParsedPoem(lang, stanzas, String(text))
end

# English backend: CMUdict (lazy fetch) then rule fallback. (Default registration for all
# languages lives in languages/lexique.jl, where every backend type is in scope.)
_english_backend() = ChainBackend(G2PBackend[CMUDictBackend(), RuleBackend()])
