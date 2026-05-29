# Sanskrit frontend: IAST transliteration → syllables with quantitative weight (laghu/guru).
#
# A syllable is guru (heavy) if its vowel is long (ā ī ū ṝ ḹ e ai o au), or is followed by
# anusvāra/visarga, or is closed by a consonant cluster (≥2 consonants before the next vowel —
# the first consonant closes this syllable); otherwise laghu (light). Weight is computed across
# the whole line (sandhi context), as classical scansion does. Devanāgarī input and the line-
# final anceps convention are not yet handled (IAST input, strict rule); noted on the roadmap.

# Distinctly-Indic IAST diacritics (for language detection); excludes ñ (Spanish) and the bare
# macrons ā/ī/ū which other languages also use.
const _IAST_SIGNALS = Set(['ṛ', 'ṝ', 'ḷ', 'ḹ', 'ṃ', 'ḥ', 'ṭ', 'ḍ', 'ṇ', 'ṅ', 'ś', 'ṣ'])

const _IAST_LONG_V  = Set(['ā', 'ī', 'ū', 'ṝ', 'ḹ', 'e', 'o'])
const _IAST_SHORT_V = Set(['a', 'i', 'u', 'ṛ', 'ḷ'])
const _IAST_ASPIRABLE = Set(['k', 'g', 'c', 'j', 'ṭ', 'ḍ', 't', 'd', 'p', 'b'])  # + h → one consonant

# Tokenize IAST into (:vowel,long?) / (:cons,_) / (:anusvara,_) / (:visarga,_), skipping spaces.
function _iast_tokens(s::AbstractString)
    cs = collect(lowercase(s))
    toks = Tuple{Symbol,Bool}[]
    i, n = 1, length(cs)
    while i <= n
        c = cs[i]
        if c == 'a' && i < n && (cs[i+1] == 'i' || cs[i+1] == 'u')   # ai / au
            push!(toks, (:vowel, true)); i += 2
        elseif c in _IAST_LONG_V
            push!(toks, (:vowel, true)); i += 1
        elseif c in _IAST_SHORT_V
            push!(toks, (:vowel, false)); i += 1
        elseif c == 'ṃ'
            push!(toks, (:anusvara, false)); i += 1
        elseif c == 'ḥ'
            push!(toks, (:visarga, false)); i += 1
        elseif c in _IAST_ASPIRABLE && i < n && cs[i+1] == 'h'
            push!(toks, (:cons, false)); i += 2                       # aspirate digraph (kh, gh, …)
        elseif isletter(c)
            push!(toks, (:cons, false)); i += 1
        else
            isspace(c) && push!(toks, (:boundary, false))             # word break (for yati)
            i += 1
        end
    end
    return toks
end

# guru/laghu per vowel (true = guru/heavy).
function _iast_weights(toks)
    vpos = [i for (i, t) in enumerate(toks) if t[1] === :vowel]
    weights = Bool[]
    for (k, vi) in enumerate(vpos)
        if toks[vi][2]                         # long vowel → guru
            push!(weights, true); continue
        end
        stop = k < length(vpos) ? vpos[k+1] : length(toks) + 1
        run = @view toks[vi+1:stop-1]
        mark  = any(t -> t[1] in (:anusvara, :visarga), run)
        ncons = count(t -> t[1] === :cons, run)
        guru = mark || ncons >= 2 || (k == length(vpos) && ncons >= 1)   # closed syllable → guru
        push!(weights, guru)
    end
    return weights
end

# Word-final flag per syllable (one per vowel), from a token stream carrying :boundary markers
# at word breaks: a syllable ends its word if a boundary falls before the next vowel (codas
# between the vowel and the break belong to this syllable), or it is the line's last syllable.
# This is what yati (the quantitative caesura) tests — the L/H analog of the Romance caesura.
function _word_final_flags(toks)
    vpos = [i for (i, t) in enumerate(toks) if t[1] === :vowel]
    flags = Bool[]
    for (k, vi) in enumerate(vpos)
        stop = k < length(vpos) ? vpos[k+1] : length(toks) + 1
        push!(flags, k == length(vpos) || any(t -> t[1] === :boundary, @view toks[vi+1:stop-1]))
    end
    return flags
end

# Devanāgarī → the same token stream the IAST weigher consumes, so guru/laghu is reused untouched.
# A consonant carries an inherent short 'a' unless followed by a vowel sign, a virāma (it joins a
# cluster), or another consonant; signs and independent vowels carry their own long/short value.
const _DEVA_VOWEL_IND_LONG  = Set("आईऊॠॡएऐओऔ")
const _DEVA_VOWEL_IND_SHORT = Set("अइउऋऌ")
const _DEVA_SIGN_LONG  = Set("ाीूॄेैोौॣ")
const _DEVA_SIGN_SHORT = Set("िुृॢ")
_deva_consonant(c::Char) = 'क' <= c <= 'ह'                     # U+0915–U+0939

function _devanagari_tokens(text::AbstractString)
    cs = collect(text)
    toks = Tuple{Symbol,Bool}[]
    i, n = 1, length(cs)
    while i <= n
        c = cs[i]
        if c in _DEVA_VOWEL_IND_LONG
            push!(toks, (:vowel, true)); i += 1
        elseif c in _DEVA_VOWEL_IND_SHORT
            push!(toks, (:vowel, false)); i += 1
        elseif _deva_consonant(c)
            push!(toks, (:cons, false))
            nxt = i < n ? cs[i+1] : ' '
            if nxt in _DEVA_SIGN_LONG
                push!(toks, (:vowel, true)); i += 2
            elseif nxt in _DEVA_SIGN_SHORT
                push!(toks, (:vowel, false)); i += 2
            elseif nxt == '्'                                  # virāma: cluster, no vowel
                i += 2
            else
                push!(toks, (:vowel, false)); i += 1            # inherent short 'a'
            end
        elseif c == 'ं' || c == 'ँ'
            push!(toks, (:anusvara, false)); i += 1
        elseif c == 'ः'
            push!(toks, (:visarga, false)); i += 1
        else
            isspace(c) && push!(toks, (:boundary, false))       # word break (for yati)
            i += 1                                              # daṇḍa, digit, …
        end
    end
    return toks
end

# Accept either script: Devanāgarī if present, else IAST.
_sanskrit_tokens(s::AbstractString) =
    any(c -> 'ऀ' <= c <= 'ॿ', s) ? _devanagari_tokens(s) : _iast_tokens(s)

function prosodic_parse(text::AbstractString, lang::Sanskrit)
    stanzas = Stanza[]
    for block in _split_stanzas(text)
        ls = Line[]
        for ln in split(block, '\n')
            isempty(strip(ln)) && continue
            toks = _sanskrit_tokens(ln)
            w, wf = _iast_weights(toks), _word_final_flags(toks)
            units = ProsodicUnit[Syllable(Phoneme[], 0, false, wf[i], w[i]) for i in eachindex(w)]
            push!(ls, Line(units, String(strip(ln))))
        end
        isempty(ls) || push!(stanzas, Stanza(ls))
    end
    return ParsedPoem(lang, stanzas, String(text))
end

# ── Gaṇa system: the eight trisyllabic gaṇas plus la (light) / ga (heavy), as L/H patterns ──
const _GANAS = Dict("ma" => "HHH", "ya" => "LHH", "ra" => "HLH", "sa" => "LLH",
                    "ta" => "HHL", "ja" => "LHL", "bha" => "HLL", "na" => "LLL",
                    "la" => "L", "ga" => "H")

"Expand a sequence of gaṇa names into a per-syllable weight pattern ('L'/'H')."
gana_pattern(ganas) = collect(join(_GANAS[g] for g in ganas))

# Bhujaṅgaprayāta: four ya-gaṇas → (L H H) × 4, twelve syllables.
meterspec(::Bhujangaprayata, ::Sanskrit) =
    MeterSpec(Quantitative(), nothing, 12, nothing, Int[], gana_pattern(["ya", "ya", "ya", "ya"]))
