# Result containers. Both detection (single-axis) and analysis (combined) speak one score
# currency, NormScore.

# Single-axis ranked detection result (a language or a form), best-first when collected.
struct Ranked{T}
    value::T
    score::NormScore
end

# One candidate interpretation of the input under a (language, form) hypothesis.
struct Candidate
    language::Language
    form::Form
    analysis::AnalysisResult      # ProsodicFeatures | Unsupported | (FormFit, Phase 2)
    parse::ParsedPoem             # the parse belongs to the candidate (it is language-relative)
    score::NormScore
end

struct Analysis
    input::String
    candidates::Vector{Candidate}     # ranked best-first
end

"""
    best(analysis) -> Candidate

The top-ranked candidate. (Note: still a single verdict — a confidence floor is a deferred
design question.)
"""
best(a::Analysis) = first(a.candidates)

"""
    confidence(analysis) -> Float64

Score of the top candidate (0 if none) — how much to trust `best`.
"""
confidence(a::Analysis) = isempty(a.candidates) ? 0.0 : first(a.candidates).score.value

"""
    is_confident(analysis; threshold=0.15) -> Bool

Whether the top candidate clears a confidence floor, so callers can decline rather than assert a
verdict on weak evidence. The default threshold is a placeholder pending score calibration.
"""
is_confident(a::Analysis; threshold::Real = 0.15) = confidence(a) >= threshold
