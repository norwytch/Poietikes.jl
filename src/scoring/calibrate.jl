# Score calibration. Fit the OTViolations→score scale from labelled verse so the boundary
# between metrical and non-metrical lines lands at score 0.5: with `score = 1/(1 + cost/s)`,
# choosing `s` as the midpoint of the two populations' mean per-line costs puts metrical lines
# (low cost) above 0.5 and controls below it.
#
# This calibrates the one score whose magnitude is most arbitrary (weighted OT violations).
# Full Harmonic-Grammar learning of the per-constraint *weights*, and calibration of the count/
# rhyme/structure kinds and `combine`, remain tracked deferred work.

_mean(xs) = isempty(xs) ? 0.0 : sum(xs) / length(xs)

"""
    metrical_costs(text, form, language) -> Vector{Float64}

Per-line weighted-violation costs of fitting `text` against an accentual-syllabic `form`
(empty if the form isn't foot-based).
"""
function metrical_costs(text::AbstractString, form::Form, lang::Language)
    a = fit(form, lang, prosodic_parse(text, lang))
    return a isa FormFit ? [lf.cost for lf in a.linefits] : Float64[]
end

"""
    calibrate_ot_scale(metrical_costs, control_costs) -> Float64

The scale placing the midpoint of the two mean costs at score 0.5. Pass per-line costs gathered
from known-metrical verse and from non-metrical controls.
"""
calibrate_ot_scale(metrical, control) = max((_mean(metrical) + _mean(control)) / 2, eps())

"Install a calibrated OTViolations scale (see `normalize_score`)."
set_ot_scale!(s::Real) = (_OT_SCALE[] = Float64(s); nothing)
