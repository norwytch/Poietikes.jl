# Detection: language ID and form ID, both returning ranked candidates (never a scalar verdict).
#
# Language ID is a hybrid built on Languages.jl, which gives three complementary things from one
# dependency: a trigram model over 84 languages, Unicode script detection, and maintained stopword
# lists. We combine them, scoring each supported language by the strongest signal that fires:
#   • script — decisive for non-Latin text: Hiragana/Katakana → Japanese, Mandarin → Chinese,
#     Devanāgarī → Sanskrit (the model labels Devanāgarī as Nepali/Hindi, but the script alone
#     suffices since Sanskrit is our only Devanāgarī frontend);
#   • the trigram model's top guess (at its confidence) for Latin-script European languages;
#   • stopword overlap, which rescues short, function-word text the trigram argmax misreads (a
#     seven-word English poem can score as Danish — but its stopwords don't);
#   • our own signals for the two romanizations no trigram model can place, both Latin script:
#     pinyin-with-tones → Chinese, IAST diacritics → Sanskrit.
# Form ID fits every supported form for the language and ranks by NormScore (free verse baseline).

# Languages.jl language types → our Language types, for Latin-script discrimination. The model
# knows 84 languages; we map only the ones we have frontends for (the rest rank as unsupported).
const _LJL_TO_LANG = Dict{DataType,DataType}(
    Languages.English => English, Languages.French => French,
    Languages.Spanish => Spanish, Languages.Italian => Italian,
    Languages.Japanese => Japanese, Languages.Mandarin => Chinese)

# Scripts that pin one of our languages outright, regardless of the model's per-language guess.
const _SCRIPT_TO_LANG = Dict{DataType,DataType}(
    Languages.HiraganaScript => Japanese, Languages.KatakanaScript => Japanese,
    Languages.MandarinScript => Chinese, Languages.DevanagariScript => Sanskrit)

# Languages.jl `stopwords` reads a word-list file per call; cache the sets on first detection.
const _STOPWORDS = Dict{DataType,Set{String}}()
function _stopword_sets()
    isempty(_STOPWORDS) || return _STOPWORDS
    _STOPWORDS[English] = Set(Languages.stopwords(Languages.English()))
    _STOPWORDS[French]  = Set(Languages.stopwords(Languages.French()))
    _STOPWORDS[Spanish] = Set(Languages.stopwords(Languages.Spanish()))
    _STOPWORDS[Italian] = Set(Languages.stopwords(Languages.Italian()))
    return _STOPWORDS
end

"""
    detect_language(text) -> Vector{Ranked{Language}}

Ranked language candidates, best first (length ≥ 1). Hybrid over Languages.jl (script + trigram
model + stopwords) plus our romanization signals; always overridable.
"""
function detect_language(text::AbstractString)
    score = Dict{DataType,Float64}(L => 0.0 for L in
        (English, French, Spanish, Italian, Japanese, Sanskrit, Chinese))

    tokens = [lowercase(m.match) for m in eachmatch(r"[\p{L}']+", text)]
    ntok = length(tokens)
    if ntok > 0
        score[Chinese] = count(_ -> true, eachmatch(r"[a-zA-ZüÜ]+[1-5]", text)) / ntok  # pinyin-with-tones
        for (L, sw) in _stopword_sets()                                                 # stopword overlap
            score[L] = max(score[L], count(in(sw), tokens) / ntok)
        end
    end
    nonspace = count(!isspace, text)
    nonspace > 0 && (score[Sanskrit] = max(score[Sanskrit], count(in(_IAST_SIGNALS), text) / nonspace))  # IAST

    # Trigram model: script is decisive for non-Latin; otherwise trust the top guess at its confidence.
    if any(isletter, text)
        lang, script, conf = with_logger(NullLogger()) do
            Languages.LanguageDetector()(text)
        end
        if haskey(_SCRIPT_TO_LANG, typeof(script))
            score[_SCRIPT_TO_LANG[typeof(script)]] = 1.0
        else
            L = get(_LJL_TO_LANG, typeof(lang), nothing)
            L === nothing || (score[L] = max(score[L], Float64(conf)))
        end
    end

    ranked = [Ranked(l, normalize_score(RawScore{LangConfidence}(clamp(score[typeof(l)], 0, 1))))
              for l in (English(), French(), Spanish(), Italian(), Japanese(), Sanskrit(), Chinese())]
    sort!(ranked; by = r -> r.score.value, rev = true)
    return ranked
end

# Score of one analysis result, in the common NormScore currency. Free verse scores at a fixed
# baseline (`_FREEVERSE_BASELINE`, tunable via `set_freeverse_baseline!`): a constrained form
# must fit better than that to be preferred over "it's just free verse". The baseline is a
# placeholder pending corpus calibration.
_score_analysis(a::FormFit)         = normalize_score(RawScore{OTViolations}(   # mean per-line cost
    isempty(a.linefits) ? a.total_violations : a.total_violations / length(a.linefits)))
_score_analysis(a::CountFit)        = normalize_score(RawScore{CountDistance}(Float64(a.total_distance)))
_score_analysis(a::SyllabicFit)     = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(a::QuantitativeFit) = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(a::TonalFit)        = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(a::MatraFit)        = normalize_score(RawScore{CountDistance}(Float64(a.total_distance)))
_score_analysis(a::AllitFit)        = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(a::RhymeFit)        = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(a::StructureFit)    = normalize_score(RawScore{CountDistance}(Float64(a.total_cost)))
_score_analysis(::ProsodicFeatures) = NormScore(_FREEVERSE_BASELINE[], [:free_verse => _FREEVERSE_BASELINE[]])
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
