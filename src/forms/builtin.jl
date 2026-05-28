# Built-in (Form, Language) specs as dispatched trait methods, plus their registration.
#
# Note how the same identity label `Sonnet` carries a completely different reality per
# language: accentual-syllabic iambic pentameter in English, syllabic alexandrine in French.

# ── Counted forms: morae in Japanese, approximated by syllables in English ──
countspec(::Haiku, ::Japanese) = CountSpec(Mora,     [5, 7, 5])
countspec(::Haiku, ::English)  = CountSpec(Syllable, [5, 7, 5])
countspec(::Tanka, ::Japanese) = CountSpec(Mora,     [5, 7, 5, 7, 7])
countspec(::Tanka, ::English)  = CountSpec(Syllable, [5, 7, 5, 7, 7])

# ── Sonnet ──
meterspec(::Sonnet{Shakespearean}, ::English) = MeterSpec(AccentualSyllabic(), Iamb, 5)
rhymespec(::Sonnet{Shakespearean}, ::English) = RhymeSpec("ababcdcdefefgg", false)
structurespec(::Sonnet, ::English)            = StructureSpec(14, nothing)
meterspec(::Sonnet, ::French)                 = MeterSpec(Syllabic(), nothing, 12, 6, [6, 12])  # alexandrine
structurespec(::Sonnet, ::French)             = StructureSpec(14, nothing)

# ── Italian endecasillabo: 11 syllables (by the final-accent rule), main accent on the 10th ──
meterspec(::Endecasillabo, ::Italian) = MeterSpec(Syllabic(), nothing, 11, nothing, [10])

# ── Spanish octosílabo: 8 metrical syllables (the count itself, by the final-accent rule) ──
meterspec(::Octosilabo, ::Spanish) = MeterSpec(Syllabic(), nothing, 8, nothing, Int[])

# Called from __init__ (never during precompile): populate the registry with built-ins.
function _register_builtins!()
    register!(FreeVerse(), English())
    register!(FreeVerse(), Japanese())
    register!(FreeVerse(), French())
    register!(FreeVerse(), Spanish())
    register!(FreeVerse(), Italian())
    register!(Octosilabo(), Spanish())
    register!(FreeVerse(), Sanskrit())
    register!(Bhujangaprayata(), Sanskrit())
    register!(Haiku(), Japanese())
    register!(Haiku(), English())
    register!(Tanka(), Japanese())
    register!(Tanka(), English())
    register!(Endecasillabo(), Italian())
    register!(Sonnet{Shakespearean}(), English())
    register!(Sonnet{Petrarchan}(),    French())
    return nothing
end
