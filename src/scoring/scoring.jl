# Scoring: one comparable currency, with provenance retained.
#
# A single Float64 everywhere would presuppose that language-ID confidence and OT form-fit
# live on a common scale; they do not (different ranges, opposite directions). So raw scores
# keep their kind and direction, and only NormScore — higher-better, in [0,1] — is ever
# ranked. The actual calibration (the normalize/combine maps) is tracked deferred work (see
# project_map.md → Score calibration); these are deliberate placeholders.

abstract type ScoreKind end
struct LangConfidence <: ScoreKind end      # ∈ [0,1], higher better
struct OTViolations   <: ScoreKind end      # ≥ 0 weighted violations, lower better
struct CountDistance  <: ScoreKind end      # ≥ 0 distance from target counts, lower better

struct RawScore{K<:ScoreKind}
    value::Float64
end

# The ONLY thing ranking sorts on: comparable, higher-better, in [0,1], with provenance.
struct NormScore
    value::Float64
    provenance::Vector{Pair{Symbol,Float64}}   # what fed in, raw — for explaining results
end

# OTViolations scale: weighted-violation cost mapping to score 0.5. Calibrated (scoring/
# calibrate.jl) on Shakespeare pentameter (per-line cost ≈ 0) vs length-matched trochaic
# controls (≈ 24), midpoint ≈ 12 — so 0.5 sits at ~three stress-maxima-in-weak per line.
# `set_ot_scale!` re-tunes it. Other kinds keep parameter-free 1/(1+x) (their costs are small).
const _OT_SCALE = Ref(12.0)

normalize_score(s::RawScore{LangConfidence}) = NormScore(clamp(s.value, 0, 1),       [:lang_conf => s.value])
normalize_score(s::RawScore{OTViolations})   = NormScore(1 / (1 + s.value / _OT_SCALE[]), [:ot_viol => s.value])
normalize_score(s::RawScore{CountDistance})  = NormScore(1 / (1 + s.value),          [:count     => s.value])

# combine: merge independent normalized scores into the single ranking currency.
# Geometric mean keeps the result in [0,1] and punishes any one axis scoring near zero.
# (Placeholder weighting; calibrated in Phase 5.)
function combine(scores::NormScore...)
    isempty(scores) && return NormScore(0.0, Pair{Symbol,Float64}[])
    value = prod(s.value for s in scores)^(1 / length(scores))
    prov  = reduce(vcat, (s.provenance for s in scores); init = Pair{Symbol,Float64}[])
    NormScore(value, prov)
end
