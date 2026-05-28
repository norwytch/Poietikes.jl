# Detection: language ID and form ID, both returning ranked candidates (never a scalar verdict).
#
# Language ID is heuristic — script (kana/kanji → Japanese), language-specific diacritics, and
# function-word overlap — with a small English prior as the poetry fallback for unmarked
# Latin-script text. It is deliberately fallible (poetry resists langID); always allow override.
# A trained character-n-gram model is the upgrade. Form ID fits every supported form for the
# language and ranks by the resulting NormScore, with free verse as a fixed baseline.

const _STOPWORDS = Dict{DataType,Set{String}}(
    English => Set(["the","a","an","and","of","to","in","is","it","that","he","was","for","on",
                    "are","with","as","his","they","at","be","this","from","or","by","not","but",
                    "she","do","if","will","up","under","over","into","no","so","we","you","i"]),
    French  => Set(["le","la","les","un","une","de","des","du","et","est","que","qui","à","dans",
                    "ce","il","je","ne","pas","pour","sur","au","aux","en","se","son","sa","ses",
                    "mon","ma","mes","plus","ou","mais","comme","tout","nous","vous","ils","elle","par","avec"]),
    Spanish => Set(["el","la","los","las","un","una","de","del","y","que","en","es","se","no",
                    "por","con","su","para","lo","como","más","o","pero","sus","le","ya","sí",
                    "porque","esta","entre","cuando","muy","sin","sobre","también","me","hasta","donde","todo","nos"]),
    Italian => Set(["il","lo","la","i","gli","le","di","del","della","e","che","un","una","è",
                    "per","con","non","si","come","sono","nel","ma","se","mi","ti","ci","vi",
                    "da","in","su","al","dei","delle","questo","quello","anche","più","o","ho","ha","ne"]),
)

function _diacritic_bonus!(b::Dict{DataType,Float64}, text)
    for c in text
        c in ('ñ', 'Ñ', '¿', '¡')             && (b[Spanish] += 0.3)
        c in ('ç', 'Ç', 'œ', 'Œ')             && (b[French]  += 0.3)
    end
    return b
end

"""
    detect_language(text) -> Vector{Ranked{Language}}

Ranked language candidates, best first (length ≥ 1). Heuristic; always allow override.
"""
function detect_language(text::AbstractString)
    toks = [lowercase(m.match) for m in eachmatch(r"[\p{L}']+", text)]
    nonspace = count(!isspace, text)
    jp = count(c -> _is_kana(c) || _is_kanji(c), text)
    sa = count(c -> ('ऀ' <= c <= 'ॿ') || c in _IAST_SIGNALS, text)   # Devanāgarī / IAST
    bonus = _diacritic_bonus!(Dict{DataType,Float64}(English => 0.0, French => 0.0,
                                                      Spanish => 0.0, Italian => 0.0), text)
    score = Dict{DataType,Float64}()
    score[Japanese] = nonspace == 0 ? 0.0 : jp / nonspace
    score[Sanskrit] = nonspace == 0 ? 0.0 : sa / nonspace
    for L in (English, French, Spanish, Italian)
        hits = isempty(toks) ? 0 : count(t -> t in _STOPWORDS[L], toks)
        frac = isempty(toks) ? 0.0 : hits / length(toks)
        score[L] = frac + bonus[L]
    end
    score[English] += 0.05      # default prior for unmarked Latin-script text (poetry fallback)

    ranked = [Ranked(l, normalize_score(RawScore{LangConfidence}(clamp(score[typeof(l)], 0, 1))))
              for l in (English(), French(), Spanish(), Italian(), Japanese(), Sanskrit())]
    sort!(ranked; by = r -> r.score.value, rev = true)
    return ranked
end

# Score of one analysis result, in the common NormScore currency. Free verse is a fixed
# baseline (0.5): a constrained form must fit better than that to be preferred over "it's just
# free verse". The threshold is a placeholder pending corpus calibration (see project_map.md).
_score_analysis(a::FormFit)         = normalize_score(RawScore{OTViolations}(   # mean per-line cost
    isempty(a.linefits) ? a.total_violations : a.total_violations / length(a.linefits)))
_score_analysis(a::CountFit)        = normalize_score(RawScore{CountDistance}(Float64(a.total_distance)))
_score_analysis(a::SyllabicFit)     = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(a::QuantitativeFit) = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(a::RhymeFit)        = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(a::StructureFit)    = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(::ProsodicFeatures) = NormScore(0.6, [:free_verse => 0.6])  # only a near-perfect fit beats free verse
_score_analysis(::Unsupported)      = NormScore(0.0, Pair{Symbol,Float64}[])

_analyze_form(f::Form, lang::Language, parsed::ParsedPoem) =
    mode(f, lang) isa Descriptive ? features(parsed) : fit(f, lang, parsed)

"""
    detect_form(text, language) -> Vector{Ranked{Form}}

Ranked form candidates for `language`, best first (length ≥ 1): every supported form is fit
and scored, free verse included as the baseline.
"""
function detect_form(text::AbstractString, lang::Language)
    parsed = prosodic_parse(text, lang)
    ranked = [Ranked(f, _score_analysis(_analyze_form(f, lang, parsed))) for f in supported_forms(lang)]
    sort!(ranked; by = r -> r.score.value, rev = true)
    return ranked
end
