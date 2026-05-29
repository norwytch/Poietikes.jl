# Scoring: one comparable currency, with provenance retained.
#
# A single Float64 everywhere would presuppose that language-ID confidence and OT form-fit
# live on a common scale; they do not (different ranges, opposite directions). So raw scores
# keep their kind and direction, and only NormScore — higher-better, in [0,1] — is ever
# ranked. The actual calibration (the normalize/combine maps) is tracked deferred work; the
# current maps are deliberate placeholders.

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

# ── Calibration: the tunables that turn raw costs into scores, carried as a value ──
# Holding them in a `Calibration` (rather than globals) lets `analyze`/`detect_form` take one and
# score reproducibly and thread-safely: pass your own and nothing global is consulted. Fields:
#   • ot_scale — the OTViolations cost mapping to score 0.5; calibrated (scoring/calibrate.jl) on
#     Shakespeare pentameter (per-line cost ≈ 0) vs length-matched trochaic controls (≈ 24),
#     midpoint ≈ 12 (so 0.5 ≈ three stress-maxima-in-weak per line);
#   • freeverse_baseline — the score a constrained form must beat to win over "it's just free
#     verse" (0.6 ⇒ only a near-perfect fit wins);
#   • constraint_weights — per-constraint weight overrides keyed by type; empty ⇒ principled defaults.
struct Calibration
    ot_scale::Float64
    freeverse_baseline::Float64
    constraint_weights::Dict{DataType,Float64}
end
Calibration(; ot_scale = 12.0, freeverse_baseline = 0.6, constraint_weights = Dict{DataType,Float64}()) =
    Calibration(ot_scale, freeverse_baseline, constraint_weights)

# The process default, consulted when a call isn't given a Calibration. The `set_*` knobs
# (scoring/calibrate.jl) mutate it; for reproducible/concurrent runs, pass an explicit Calibration.
const _DEFAULT_CALIBRATION = Ref(Calibration())
default_calibration() = _DEFAULT_CALIBRATION[]

normalize_score(s::RawScore{LangConfidence}, ::Calibration = default_calibration()) =
    NormScore(clamp(s.value, 0, 1), [:lang_conf => s.value])
normalize_score(s::RawScore{OTViolations}, cal::Calibration = default_calibration()) =
    NormScore(1 / (1 + s.value / cal.ot_scale), [:ot_viol => s.value])
normalize_score(s::RawScore{CountDistance}, ::Calibration = default_calibration()) =
    NormScore(1 / (1 + s.value), [:count => s.value])

# combine: merge independent normalized scores into the single ranking currency.
# Geometric mean keeps the result in [0,1] and punishes any one axis scoring near zero.
# (Placeholder weighting; calibrated in Phase 5.)
function combine(scores::NormScore...)
    isempty(scores) && return NormScore(0.0, Pair{Symbol,Float64}[])
    value = prod(s.value for s in scores)^(1 / length(scores))
    prov  = reduce(vcat, (s.provenance for s in scores); init = Pair{Symbol,Float64}[])
    NormScore(value, prov)
end
