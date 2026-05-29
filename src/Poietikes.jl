"""
    Poietikes

A form-aware, multilingual prosodic analysis package. See `README.md` for the design and methodology.

Phase 1: the (Form × Language) type architecture, the spec/trait system, the form registry,
the scoring currency, English G2P (CMUdict + rule fallback), syllabification, and free-verse
descriptive analysis.
"""
module Poietikes

using Downloads
using TOML
import Languages                       # qualified: its English/French/… types collide with ours
using Logging: with_logger, NullLogger

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
include("languages/chinese.jl")
include("languages/latin.jl")
include("languages/arabic.jl")
include("languages/norse.jl")
include("languages/welsh.jl")
include("analysis/features.jl")
include("analysis/count.jl")
include("analysis/syllabic.jl")
include("analysis/quantitative.jl")
include("analysis/tonal.jl")
include("analysis/structure.jl")
include("analysis/rhyme.jl")
include("analysis/alliteration.jl")
include("analysis/matra.jl")
include("analysis/meter.jl")
include("analysis/ot.jl")
include("analysis/scansion.jl")
include("detection/detect.jl")
include("analysis/drottkvaett.jl")
include("analysis/cynghanedd.jl")
include("analysis/analyze.jl")
include("scoring/calibrate.jl")
include("dsl/dsl.jl")

function __init__()
    _register_builtins!()          # populate the form registry (never during precompile)
    _register_g2p_defaults!()       # install the default English G2P backend (no fetch yet)
end

# Languages
export Language, English, Japanese, French, Spanish, Italian, Sanskrit, Chinese, Latin, Arabic, Norse, Welsh
# Forms and variants
export Form, FreeVerse, Haiku, Tanka, Endecasillabo, Octosilabo, Bhujangaprayata, Jueju, Alliterative
export Hexameter, Tawil, Kamil, Drottkvaett, Cywydd
export Sonnet, DataForm, SonnetVariant, Shakespearean, Petrarchan
# Prosodic units
export ProsodicUnit, Phoneme, Syllable, Mora, TonalSyllable
# Metrical vocabulary
export Foot, Iamb, Trochee, Anapest, Dactyl, Spondee, Pyrrhic
export MeterKind, AccentualSyllabic, Syllabic, Quantitative, Tonal
# Constraint specs
export CountSpec, MeterSpec, RhymeSpec, StructureSpec, AllitSpec, MatraSpec
# Analysis mode
export AnalysisMode, Descriptive, Prescriptive
# Trait functions (extension points: users add methods or @form)
export countspec, meterspec, rhymespec, structurespec, allitspec, matraspec, mode
# Containment + parse
export Line, Stanza, ParsedPoem, prosodic_parse
# Registry / introspection
export supports, supported_forms, supported_languages
# Detection
export detect_language, detect_form
# Extensibility (DSL)
export @form, load_forms, formname
# Scoring — the comparable currency users read, the Calibration config, and the tuning knobs
export NormScore, Calibration, default_calibration, set_ot_scale!, set_freeverse_baseline!
# G2P — pluggable pronunciation backends
export G2PBackend, DictBackend, ChainBackend, RuleBackend, CMUDictBackend, LexiqueBackend
export set_backend!, g2p_backend, pronounce, pronounce_word, phonetic_transcribe
export syllabify, syllabify_phonemes
# Analysis results + the top-level pipeline
export AnalysisResult, Unsupported, ProsodicFeatures, features
export CountFit, SyllabicFit, QuantitativeFit, TonalFit, RhymeFit, StructureFit, AllitFit, MatraFit
export FormFit, DrottkvaettFit, CynghaneddFit, rhyme_key
export Ranked, Candidate, Analysis, best, confidence, is_confident, analyze, scansion

# Deliberately NOT exported — reach via `Poietikes.` if you need them. The OT metrical-parser
# internals (Meter, MetricalParse, build_meter, the MetricalConstraint set + `violations`/`weight`,
# best_parse, LineFit, the `fit` router — note `fit` is unexported to avoid clashing with
# StatsAPI.fit), the score-kind plumbing (RawScore, ScoreKind and its subtypes, normalize_score),
# and the corpus-calibration / weight-learning helpers (metrical_costs, calibrate_ot_scale,
# set_constraint_weight!, reset_constraint_weights!, learn_constraint_weights).

end # module Poietikes
