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

"Install a calibrated OTViolations scale on the default `Calibration` (see `normalize_score`)."
set_ot_scale!(s::Real) = (c = default_calibration();
    _DEFAULT_CALIBRATION[] = Calibration(Float64(s), c.freeverse_baseline, c.constraint_weights); nothing)

"Set the free-verse baseline (on the default `Calibration`) a constrained form must beat in detection."
set_freeverse_baseline!(x::Real) = (c = default_calibration();
    _DEFAULT_CALIBRATION[] = Calibration(c.ot_scale, Float64(x), c.constraint_weights); nothing)

"""
    learn_constraint_weights(metrical, control; form, language) -> Dict{DataType,Float64}

A simple discriminative estimate of metrical-constraint weights: each weight ← how much more
the constraint fires (per line) in non-metrical `control` verse than in known-metrical verse.
This exposes what a corpus can pin down — a constraint the controls never exercise gets ~0,
revealing under-determination (full Harmonic-Grammar weight learning needs near-metrical
minimal pairs). Returns a Dict installable via `set_constraint_weight!`; not auto-applied.
"""
function learn_constraint_weights(metrical, control;
                                  form = Sonnet{Shakespearean}(), language = English(),
                                  constraints = default_constraints())
    meter = build_meter(meterspec(form, language))
    function meanviol(texts)
        totals = Dict{DataType,Float64}(typeof(c) => 0.0 for c in constraints)
        n = 0
        for t in texts, l in lines(prosodic_parse(t, language))
            syls = Syllable[u for u in l.units if u isa Syllable]
            parse, _, _ = best_parse(meter, syls, constraints)
            parse === nothing && continue
            for c in constraints
                totals[typeof(c)] += violations(c, parse)
            end
            n += 1
        end
        return n == 0 ? totals : Dict(k => v / n for (k, v) in totals)
    end
    mv, cv = meanviol(metrical), meanviol(control)
    return Dict(k => max(cv[k] - mv[k], 0.0) for k in keys(cv))
end
