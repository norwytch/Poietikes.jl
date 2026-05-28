# Identity types and prosodic vocabulary.
#
# Design invariant: the (Form, Language) *pair* is the unit of definition, and every
# category we will ever dispatch on or want third parties to extend is a *type*, never a
# :Symbol. Symbols live only at the ergonomic edge (resolved to types before any dispatch).

# ── Languages ───────────────────────────────────────────────────────────────
abstract type Language end
struct English  <: Language end
struct Japanese <: Language end
struct French   <: Language end
struct Spanish  <: Language end
struct Italian  <: Language end
struct Sanskrit <: Language end
struct Chinese  <: Language end

# ── Forms ─────────────────────────────────────────────────────────────────────
# A {Variant} type parameter expresses named flavors sharing a name within ONE tradition
# (Shakespearean/Petrarchan sonnet). Language differences are never a parameter — they are
# the (Form, Language) axis. That is why Sonnet is parametric and Haiku is not.
abstract type SonnetVariant end
struct Shakespearean <: SonnetVariant end
struct Petrarchan    <: SonnetVariant end

abstract type Form end
struct FreeVerse    <: Form end
struct Haiku        <: Form end
struct Tanka        <: Form end
struct Endecasillabo  <: Form end         # Italian hendecasyllable: last accent on the 10th
struct Octosilabo     <: Form end         # Spanish octosyllable: 8 metrical syllables
struct Bhujangaprayata <: Form end        # Sanskrit quantitative metre: four ya-gaṇas (L H H)×4
struct Jueju <: Form end                  # Tang regulated quatrain: per-line tonal template
struct Alliterative <: Form end           # Germanic alliterative verse: stressed onsets agree
struct Sonnet{V<:SonnetVariant} <: Form end

# Data-driven forms: a single type carrying its specs as runtime data (the non-programmer
# path, loadable from TOML/JSON). Its trait methods read `specs` instead of dispatching.
# `specs` is a NamedTuple of the four constraint axes; `nothing` means "axis doesn't apply".
struct DataForm <: Form
    name::Symbol
    specs::NamedTuple
end

# ── Prosodic units ─────────────────────────────────────────────────────────────
# Data-carrying structs whose *type* doubles as the counting/dispatch tag: `Syllable` is the
# datum (it has fields), `Type{Syllable}` is the tag passed to CountSpec. No name collision.
abstract type ProsodicUnit end

struct Phoneme <: ProsodicUnit
    symbol::String          # ARPABET/IPA token, e.g. "AE1"
end

struct Syllable <: ProsodicUnit
    phonemes::Vector{Phoneme}
    stress::Int             # lexical stress digit: 0 unstressed, 1 primary, 2 secondary
    flexible::Bool          # monosyllabic word: stress is contextually assignable by the meter
    word_final::Bool        # last syllable of its word (locates caesura / line-end accent)
    heavy::Union{Bool,Nothing}   # quantitative weight, if precomputed (e.g. Sanskrit laghu/guru)
end
Syllable(p::Vector{Phoneme}, stress::Integer) = Syllable(p, Int(stress), false, false, nothing)
Syllable(p::Vector{Phoneme}, stress::Integer, flexible::Bool) = Syllable(p, Int(stress), flexible, false, nothing)
Syllable(p::Vector{Phoneme}, stress::Integer, flexible::Bool, wf::Bool) = Syllable(p, Int(stress), flexible, wf, nothing)

struct Mora <: ProsodicUnit
    content::String         # timing unit (Japanese); minimal for now
end

struct TonalSyllable <: ProsodicUnit
    tone::Char              # 'P' level (平) or 'Z' oblique (仄) — Tang regulated verse
end

# ── Metrical vocabulary (types, so they dispatch and extend) ────────────────────
abstract type Foot end
struct Iamb    <: Foot end
struct Trochee <: Foot end
struct Anapest <: Foot end
struct Dactyl  <: Foot end
struct Spondee <: Foot end
struct Pyrrhic <: Foot end

abstract type MeterKind end
struct AccentualSyllabic <: MeterKind end   # English
struct Syllabic          <: MeterKind end   # French alexandrine, Japanese count
struct Quantitative      <: MeterKind end   # Latin / Greek / Arabic length
struct Tonal             <: MeterKind end   # Tang regulated verse

# ── Independent constraint axes, each carrying data ─────────────────────────────
struct CountSpec
    unit::Type{<:ProsodicUnit}      # Mora | Syllable | Phoneme — a TYPE, not :a_symbol
    counts::Vector{Int}             # e.g. [5, 7, 5]
end

struct MeterSpec
    kind::MeterKind
    foot::Union{Type{<:Foot},Nothing}
    len::Union{Int,Nothing}             # feet (accentual-syllabic) or syllables (syllabic) per line
    caesura::Union{Int,Nothing}         # syllable after which a word boundary is required (e.g. 6)
    accents::Vector{Int}                # syllable positions that must bear a word-accent (e.g. [6,12])
    pattern::Vector{Char}               # per-position weight target for quantitative metre ('L'/'H'/'.')
end
MeterSpec(kind::MeterKind, foot, len) = MeterSpec(kind, foot, len, nothing, Int[], Char[])
MeterSpec(kind::MeterKind, foot, len, caesura) = MeterSpec(kind, foot, len, caesura, Int[], Char[])
MeterSpec(kind::MeterKind, foot, len, caesura, accents) = MeterSpec(kind, foot, len, caesura, accents, Char[])

struct RhymeSpec
    scheme::String                  # e.g. "ababcdcdefefgg"
    refrain::Bool
end

struct StructureSpec
    nlines::Union{Int,Nothing}
    nstanzas::Union{Int,Nothing}
end

struct AllitSpec
    min::Int                # minimum stressed syllables per line that must share an onset
end

# ── Analysis mode: descriptive vs prescriptive is DECLARED, not inferred ────────
abstract type AnalysisMode end
struct Descriptive  <: AnalysisMode end     # feature extraction, no template
struct Prescriptive <: AnalysisMode end     # fit against declared constraints

# ── Analysis results (one per (form, language) candidate) ───────────────────────
abstract type AnalysisResult end
struct Unsupported <: AnalysisResult end    # the (form, language) cell is not defined
