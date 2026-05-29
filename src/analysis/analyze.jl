# The analyze pipeline and the Symbol→type resolve registry (keeping Symbols at the ergonomic
# edge, out of dispatch). With `:auto`, detection runs and the result is a ranked set of
# candidates over the (language × form) space; with an explicit language/form, that axis is
# fixed and its score is the pure fit (no language uncertainty mixed in).

_resolve_language(l::Language) = l
function _resolve_language(s::Symbol)
    s in (:auto, :english) && return English()
    s === :japanese && return Japanese()
    s === :french   && return French()
    s === :spanish  && return Spanish()
    s === :italian  && return Italian()
    s === :sanskrit && return Sanskrit()
    s === :chinese  && return Chinese()
    s === :latin    && return Latin()
    s === :arabic   && return Arabic()
    s === :norse    && return Norse()
    s === :welsh    && return Welsh()
    error("unknown language :$s")
end

_resolve_form(f::Form) = f
function _resolve_form(s::Symbol)
    s in (:auto, :free_verse, :freeverse) && return FreeVerse()
    s === :haiku  && return Haiku()
    s === :tanka  && return Tanka()
    s === :endecasillabo  && return Endecasillabo()
    s === :octosilabo     && return Octosilabo()
    s === :bhujangaprayata && return Bhujangaprayata()
    s === :jueju  && return Jueju()
    s === :alliterative && return Alliterative()
    s === :hexameter && return Hexameter()
    s === :tawil && return Tawil()
    s === :kamil && return Kamil()
    s === :drottkvaett && return Drottkvaett()
    s === :cywydd && return Cywydd()
    s === :sonnet && return Sonnet{Shakespearean}()
    error("unknown form :$s")
end

# Candidate languages: detected (top-scoring, within 0.6× the best) when :auto, else the
# explicit one with full confidence.
function _language_candidates(text, language)
    language === :auto || return [Ranked(_resolve_language(language), NormScore(1.0, [:explicit => 1.0]))]
    ranked = detect_language(text)
    best = ranked[1].score.value
    keep = filter(r -> r.score.value >= 0.6 * best, ranked)
    return isempty(keep) ? [ranked[1]] : keep
end

# Candidate forms: every supported form when :auto, else the explicit one.
_form_candidates(form, lang) = form === :auto ? supported_forms(lang) : [_resolve_form(form)]

"""
    analyze(text; language=:auto, form=:auto) -> Analysis

Analyze `text`, returning ranked candidates best-first. With `:auto`, language and form are
detected; the score combines language confidence with form fit. With an explicit language
and/or form, that axis is fixed and the score is the pure fit. `best(analysis)` is the top
candidate (still a single verdict — a confidence floor remains a deferred design question).
"""
function analyze(text::AbstractString; language = :auto, form = :auto)
    out = Candidate[]
    for lr in _language_candidates(text, language)
        lang   = lr.value
        parsed = prosodic_parse(text, lang)
        for f in _form_candidates(form, lang)
            # A form not defined for this language has no template here, so it is analyzed
            # descriptively — as if it declared no constraints (features only), not refused.
            analysis = supports(f, lang) ? _analyze_form(f, lang, parsed) : features(parsed)
            fit_score = _score_analysis(analysis)
            score = language === :auto ? combine(lr.score, fit_score) : fit_score
            push!(out, Candidate(lang, f, analysis, parsed, score))
        end
    end
    sort!(out; by = c -> c.score.value, rev = true)
    return Analysis(String(text), out)
end
