"""
    Poietikes

A form-aware, multilingual prosodic analysis library. See `project_map.md` for the design.

Phase 1: the (Form × Language) type architecture, the spec/trait system, the form registry,
the scoring currency, English G2P (CMUdict + rule fallback), syllabification, and free-verse
descriptive analysis.
"""
module Poietikes

using Downloads
using TOML

include("core/types.jl")
include("core/traits.jl")
include("core/containment.jl")
include("scoring/scoring.jl")
include("analysis/results.jl")
include("registry/registry.jl")
include("forms/builtin.jl")
include("languages/g2p.jl")
include("languages/english.jl")
include("languages/japanese.jl")
include("languages/romance.jl")
include("languages/lexique.jl")
include("languages/sanskrit.jl")
include("analysis/features.jl")
include("analysis/count.jl")
include("analysis/syllabic.jl")
include("analysis/quantitative.jl")
include("analysis/structure.jl")
include("analysis/rhyme.jl")
include("analysis/meter.jl")
include("analysis/ot.jl")
include("detection/detect.jl")
include("analysis/analyze.jl")
include("scoring/calibrate.jl")
include("dsl/dsl.jl")

function __init__()
    _register_builtins!()          # populate the form registry (never during precompile)
    _register_g2p_defaults!()       # install the default English G2P backend (no fetch yet)
end

# Languages
export Language, English, Japanese, French, Spanish, Italian, Sanskrit
# Forms and variants
export Form, FreeVerse, Haiku, Tanka, Endecasillabo, Octosilabo, Bhujangaprayata, Sonnet, DataForm
export SonnetVariant, Shakespearean, Petrarchan
# Prosodic units
export ProsodicUnit, Phoneme, Syllable, Mora
# Metrical vocabulary
export Foot, Iamb, Trochee, Anapest, Dactyl, Spondee, Pyrrhic
export MeterKind, AccentualSyllabic, Syllabic, Quantitative, Tonal
# Constraint specs
export CountSpec, MeterSpec, RhymeSpec, StructureSpec
# Analysis mode
export AnalysisMode, Descriptive, Prescriptive
# Trait functions (extension points: users add methods or @form)
export countspec, meterspec, rhymespec, structurespec, mode
# Containment + parse
export Line, Stanza, ParsedPoem, prosodic_parse
# Registry / introspection
export supports, supported_forms, supported_languages
# Detection
export detect_language, detect_form
# Extensibility (DSL)
export @form, load_forms, formname
# Scoring
export ScoreKind, LangConfidence, OTViolations, CountDistance, RawScore, NormScore, normalize_score
export metrical_costs, calibrate_ot_scale, set_ot_scale!
# G2P
export G2PBackend, DictBackend, ChainBackend, RuleBackend, CMUDictBackend, LexiqueBackend
export set_backend!, g2p_backend, pronounce, pronounce_word, phonetic_transcribe
export syllabify, syllabify_phonemes
# Metrical parsing (OT)
export Strength, Strong, Weak, Meter, MetricalParse, build_meter, foot_pattern
export MetricalConstraint, violations, weight, default_constraints, is_heavy
export StressMaxInWeak, TroughInStrong, Clash, Lapse, HeavyInWeak, PositionSize, IllegalResolution
export best_parse, LineFit, FormFit, fit
# Analysis
export AnalysisResult, Unsupported, ProsodicFeatures, features, CountFit, SyllabicFit, QuantitativeFit
export RhymeFit, StructureFit, rhyme_key
export Ranked, Candidate, Analysis, best, confidence, is_confident, analyze

end # module Poietikes
