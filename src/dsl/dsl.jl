# User extensibility, two paths (the "do both" decision):
#   • @form     — programmers define a new Form type with trait methods, by dispatch.
#   • load_forms — non-programmers define DataForms in TOML, interpreted at runtime.
# Both register into the same _FORMS and flow through the same fit(). A loaded/declared form
# may not shadow an existing form for a language (built-ins and earlier registrations win).

# Stable name of a form, for collision detection. Derived from the type name by default;
# DataForms carry their own.
formname(f::Form)     = Symbol(lowercase(String(nameof(typeof(f)))))
formname(::FreeVerse) = :free_verse
formname(f::DataForm) = f.name

# ── @form: programmer-defined forms ──
const _AXIS = Dict(:count     => (:CountSpec, :countspec),
                   :meter     => (:MeterSpec, :meterspec),
                   :rhyme     => (:RhymeSpec, :rhymespec),
                   :structure => (:StructureSpec, :structurespec),
                   :allit     => (:AllitSpec, :allitspec),
                   :matra     => (:MatraSpec, :matraspec))

"""
    @form Name Language begin
        count = (Syllable, [3, 5, 3])
        rhyme = ("aabb", false)
        ...
    end

Define a new form `Name` for `Language` by dispatch: emits `struct Name <: Form`, a trait
method per declared axis, and registration. Each axis value is splatted into its spec
constructor (`count` → `CountSpec(args...)`, etc.). Use at module top level (the registration
runs at load — in a precompiled package, place it under `__init__` instead).
"""
macro form(name::Symbol, lang::Symbol, block::Expr)
    # Reference Poietikes' own names absolutely (GlobalRef), so the generated trait methods
    # extend Poietikes.countspec etc. regardless of how the caller imported the package; the
    # user-written `name`, `lang`, and axis values resolve in the caller's scope.
    defs = Any[:(struct $name <: $(GlobalRef(Poietikes, :Form)) end)]
    for stmt in block.args
        stmt isa LineNumberNode && continue
        (stmt isa Expr && stmt.head === :(=)) || error("@form: expected `axis = (args...)`, got $stmt")
        axis = stmt.args[1]::Symbol
        haskey(_AXIS, axis) || error("@form: unknown axis `$axis` (count/meter/rhyme/structure)")
        spectype, trait = _AXIS[axis]
        val = stmt.args[2]
        push!(defs, :($(GlobalRef(Poietikes, trait))(::$name, ::$lang) =
                          $(GlobalRef(Poietikes, spectype))($val...)))
    end
    push!(defs, :($(GlobalRef(Poietikes, :register!))($name(), $lang())))
    return esc(Expr(:block, defs..., name))    # user names resolve in the caller; GlobalRefs stay absolute
end

# ── load_forms: data-driven forms from TOML ──
_resolve_unit(s) = s == "syllable" ? Syllable : s == "mora" ? Mora : s == "phoneme" ? Phoneme :
    error("load_forms: unknown unit \"$s\"")

function _resolve_meterkind(s)
    s == "accentual_syllabic" && return AccentualSyllabic()
    s == "syllabic"           && return Syllabic()
    s == "quantitative"       && return Quantitative()
    s == "tonal"              && return Tonal()
    error("load_forms: unknown meter kind \"$s\"")
end

const _FOOTS = Dict("iamb" => Iamb, "trochee" => Trochee, "anapest" => Anapest,
                    "dactyl" => Dactyl, "spondee" => Spondee, "pyrrhic" => Pyrrhic)
_resolve_foot(s) = get(() -> error("load_forms: unknown foot \"$s\""), _FOOTS, s)

function _meterspec_from_toml(m)
    MeterSpec(_resolve_meterkind(m["kind"]),
              haskey(m, "foot") ? _resolve_foot(m["foot"]) : nothing,
              haskey(m, "len") ? Int(m["len"]) : nothing,
              haskey(m, "caesura") ? Int(m["caesura"]) : nothing,
              haskey(m, "accents") ? Vector{Int}(m["accents"]) : Int[],
              haskey(m, "pattern") ? collect(String(m["pattern"])) : Char[],      # fixed L/H/. pattern
              haskey(m, "feet") ? Vector{String}[Vector{String}(f) for f in m["feet"]] : Vector{String}[])
end                                                                               # foot alternatives

function _specs_from_toml(spec)
    p = Pair{Symbol,Any}[]
    haskey(spec, "count") &&
        push!(p, :count => CountSpec(_resolve_unit(spec["count"]["unit"]), Vector{Int}(spec["count"]["counts"])))
    haskey(spec, "meter") && push!(p, :meter => _meterspec_from_toml(spec["meter"]))
    haskey(spec, "rhyme") &&
        push!(p, :rhyme => RhymeSpec(spec["rhyme"]["scheme"], get(spec["rhyme"], "refrain", false)))
    haskey(spec, "structure") &&
        push!(p, :structure => StructureSpec(get(spec["structure"], "nlines", nothing),
                                             get(spec["structure"], "nstanzas", nothing)))
    return (; p...)
end

"""
    load_forms(path) -> Vector{DataForm}

Load forms from a TOML file and register them. Each top-level table is a form; `language` (or
`languages`) names where to register it, and `count`/`meter`/`rhyme`/`structure` give its
specs. A form whose name already exists for a language is rejected (built-ins/earlier wins).
"""
function load_forms(path::AbstractString)
    data = TOML.parsefile(path)
    loaded = DataForm[]
    for (name, spec) in data
        df = DataForm(Symbol(name), _specs_from_toml(spec))
        langs = haskey(spec, "languages") ? spec["languages"] : [spec["language"]]
        for lstr in langs
            lang = _resolve_language(Symbol(lstr))
            Symbol(name) in (formname(f) for f in supported_forms(lang)) &&
                error("load_forms: form :$name collides with an existing form for $(typeof(lang))")
            register!(df, lang)
        end
        push!(loaded, df)
    end
    return loaded
end
