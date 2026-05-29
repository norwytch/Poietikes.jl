# Arabic frontend: classical ʿarūḍ (al-Khalīl) scansion → syllables with quantitative weight.
#
# Arabic metre is quantitative: a syllable is light (CV — an open short syllable) or heavy (CVV
# long vowel, or CVC closed). These rules match Latin/Sanskrit, so weighting reuses `_iast_weights`
# over an Arabic token stream. Input is a PHONETIC transliteration with explicit short (a i u) and
# long (ā ī ū) vowels, gemination written as a doubled consonant, and the digraphs th/kh/dh/sh/gh
# read as one consonant each (ث خ ذ ش غ). Native Arabic script is an abjad — it omits the short
# vowels, so it underdetermines scansion (the same vocalization gap noted for other languages);
# vocalized native script is a future refinement, and Languages.jl already detects ArabicScript
# for that. Auto-detection here is explicit-only (romanized input reads as Latin script), as for Latin.
#
# The buḥūr are foot sequences whose ziḥāf — the allowed per-foot variations — are expressed as
# the alternative L/H realizations the quantitative foot-search consumes. The final foot's last
# position is anceps ('.'): the line-final syllable of the bayt is counted heavy regardless.

const _AR_LONG_V       = Set(['ā', 'ī', 'ū'])
const _AR_SHORT_V      = Set(['a', 'i', 'u'])
const _AR_DIGRAPH_CONS = Set(["th", "kh", "dh", "sh", "gh"])      # ث خ ذ ش غ — one consonant each

function _arabic_tokens(s::AbstractString)
    cs = collect(lowercase(s))
    toks = Tuple{Symbol,Bool}[]
    i, n = 1, length(cs)
    while i <= n
        c = cs[i]
        two = i < n ? string(c, cs[i+1]) : ""
        if two in _AR_DIGRAPH_CONS
            push!(toks, (:cons, false)); i += 2
        elseif c in _AR_LONG_V
            push!(toks, (:vowel, true)); i += 1
        elseif c in _AR_SHORT_V
            push!(toks, (:vowel, false)); i += 1
        elseif isspace(c)
            push!(toks, (:boundary, false)); i += 1               # word break (for yati)
        elseif isletter(c) || c == 'ʿ' || c == 'ʾ'               # consonants incl. ʿayn / hamza
            push!(toks, (:cons, false)); i += 1
        else
            i += 1                                                # punctuation, stray marks
        end
    end
    return toks
end

function prosodic_parse(text::AbstractString, lang::Arabic)
    stanzas = Stanza[]
    for block in _split_stanzas(text)
        ls = Line[]
        for ln in split(block, '\n')
            isempty(strip(ln)) && continue
            toks = _arabic_tokens(ln)
            w, wf = _iast_weights(toks), _word_final_flags(toks)
            units = ProsodicUnit[Syllable(Phoneme[], 0, false, wf[i], w[i]) for i in eachindex(w)]
            push!(ls, Line(units, String(strip(ln))))
        end
        isempty(ls) || push!(stanzas, Stanza(ls))
    end
    return ParsedPoem(lang, stanzas, String(text))
end

# ── Buḥūr (the foot-alternative search lives in analysis/quantitative.jl) ──

# al-Ṭawīl: faʿūlun mafāʿīlun faʿūlun mafāʿīlun. Common ziḥāf qabḍ drops the 5th sākin
# (faʿūlun → faʿūlu = L H L; mafāʿīlun → mafāʿilun = L H L H).
const _AR_FAULUN   = ["LHH", "LHL"]          # faʿūlun / faʿūlu
const _AR_MAFAILUN = ["LHHH", "LHLH"]        # mafāʿīlun / mafāʿilun
tawil() = [_AR_FAULUN, _AR_MAFAILUN, _AR_FAULUN, ["LHH.", "LHL."]]

# al-Kāmil: mutafāʿilun ×3. Ziḥāf iḍmār contracts the two opening shorts to one long
# (mutafāʿilun L L H L H → mutfāʿilun H H L H) — a foot alternative of a *different* length,
# which the variable-length search handles directly.
const _AR_MUTAFAILUN = ["LLHLH", "HHLH"]
kamil() = [_AR_MUTAFAILUN, _AR_MUTAFAILUN, ["LLHL.", "HHL."]]

meterspec(::Tawil, ::Arabic) = MeterSpec(Quantitative(), nothing, nothing, nothing, Int[], Char[], tawil())
meterspec(::Kamil, ::Arabic) = MeterSpec(Quantitative(), nothing, nothing, nothing, Int[], Char[], kamil())
