# The enumerable registry. Dispatch answers "given this form and language, what are the
# specs?" but cannot enumerate "what forms exist for French?" — a function can't list the
# inputs that satisfy it. Detection needs that list, so the registry is the single source of
# truth for existence; form *behavior* still lives in code (the trait methods).
#
# Instances throughout (not a type/instance mix): every consumer gets a Form value with zero
# branching. Empty-struct forms are singletons, so set membership/equality are well-behaved;
# DataForm equality falls out field-wise.

const _FORMS = Set{Tuple{Form,Language}}()

"""
    register!(form, language)

Record that `(form, language)` is a defined cell. Built-ins call this at load; `@form` and
the TOML/JSON loader call it for user forms. Populates the same registry `supports` reads.
"""
register!(f::Form, l::Language) = (push!(_FORMS, (f, l)); nothing)

"""
    supports(form, language) -> Bool

Whether `(form, language)` is a defined cell. Derived from the registry — one source of
truth — so an undefined cell never reads as a clean fit.
"""
supports(f::Form, l::Language) = (f, l) in _FORMS

"""
    supported_forms(language) -> Vector{Form}

Forms with a defined cell for `language`, for introspection and form detection.
"""
supported_forms(l::Language) = sort!(Form[f for (f, l2) in _FORMS if l2 == l]; by = string)

"""
    supported_languages() -> Vector{Language}

Languages appearing in any defined cell.
"""
supported_languages() = unique!(Language[l for (_, l) in _FORMS])
