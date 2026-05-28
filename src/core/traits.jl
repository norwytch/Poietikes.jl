# Trait functions: the heart of the (Form, Language) abstraction.
#
# Default = "this axis does not apply to this form." Specialize per (Form, Language) in
# forms/. A form's realized constraints are whatever its (Form, Language) cell declares —
# same identity label, language-specific reality.

countspec(::Form, ::Language)     = nothing
meterspec(::Form, ::Language)     = nothing
rhymespec(::Form, ::Language)     = nothing
structurespec(::Form, ::Language) = nothing
allitspec(::Form, ::Language)     = nothing

# Data-driven forms read their specs from carried data instead of dispatched methods.
countspec(f::DataForm, ::Language)     = get(f.specs, :count, nothing)
meterspec(f::DataForm, ::Language)     = get(f.specs, :meter, nothing)
rhymespec(f::DataForm, ::Language)     = get(f.specs, :rhyme, nothing)
structurespec(f::DataForm, ::Language) = get(f.specs, :structure, nothing)
allitspec(f::DataForm, ::Language)     = get(f.specs, :allit, nothing)

# Descriptive vs prescriptive is a positive declaration, so a constraint-free form (on
# purpose) is distinguishable from a prescriptive form whose specs were never written.
mode(::Form, ::Language)      = Prescriptive()      # default: you owe me specs
mode(::FreeVerse, ::Language) = Descriptive()       # constraint-free ON PURPOSE
