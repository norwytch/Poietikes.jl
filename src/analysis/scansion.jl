# Human-readable scansion strings (inspired by Python prosodic's output — see docs/src/comparison.md).
# `scansion(x)` renders any analysis result as text for inspection: metrical parses show the
# position template over the realized stress; counted/syllabic/quantitative fits show actuals
# against targets. Output is thus available both as structured result types and as
# human-readable scansion strings.

_pos_glyph(::Strong) = '+'        # strong metrical position (ictus)
_pos_glyph(::Weak)   = '-'        # weak position
_stress_glyph(pr::Int) = pr >= 2 ? '+' : pr == 1 ? ':' : '-'   # realized prominence per syllable

"""
    scansion(x) -> String

A human-readable rendering of a parse or analysis result.
"""
function scansion(p::MetricalParse)
    _, str, pr = _realized(p)
    meter  = join((_pos_glyph(s) for s in str), " ")
    stress = join((_stress_glyph(x) for x in pr), " ")
    return "  meter:  $meter\n  stress: $stress"
end

function scansion(lf::LineFit)
    head = '"' * lf.line.surface * '"'
    body = lf.parse === nothing ? "  (does not scan — $(Dict(lf.breakdown)))" : scansion(lf.parse)
    return head * "\n" * body
end

scansion(f::FormFit) = join((scansion(lf) for lf in f.linefits), "\n\n")

function scansion(m::MatraFit)
    rows = ["  line $i: $(m.actual[i]) mātrās (want $(i <= length(m.expected) ? string(m.expected[i]) : "–"))" for i in eachindex(m.actual)]
    return "mātrā count (laghu=1, guru=2):\n" * join(rows, "\n")
end

function scansion(c::CountFit)
    rows = map(eachindex(c.actual)) do i
        want = i <= length(c.expected) ? string(c.expected[i]) : "–"
        ok = i <= length(c.expected) && c.actual[i] == c.expected[i]
        "  line $i: $(c.actual[i]) (want $want) " * (ok ? "✓" : "✗")
    end
    return "count by $(nameof(c.unit)):\n" * join(rows, "\n")
end

function scansion(s::SyllabicFit)
    head = "syllabic (target $(s.expected)" * (s.caesura === nothing ? "" : ", caesura $(s.caesura)") * "):"
    rows = ["  line $i: $(s.actual[i]) syllables" for i in eachindex(s.actual)]
    return head * "\n" * join(rows, "\n")
end

function scansion(q::QuantitativeFit)
    isempty(q.matched) || return "quantitative (foot search):\n" *
        join(["  line $i: $(q.actual[i])  (best fit $(q.matched[i]))" for i in eachindex(q.actual)], "\n")
    rows = ["  line $i: $(q.actual[i])" for i in eachindex(q.actual)]
    return "quantitative:\n  target: $(join(q.pattern))\n" * join(rows, "\n")
end

function scansion(t::TonalFit)
    rows = ["  line $i: $(t.actual[i])" for i in eachindex(t.actual)]
    return "tonal (平=P 仄=Z):\n  target: $(join(t.pattern))\n" * join(rows, "\n")
end

function scansion(a::AllitFit)
    rows = ["  line $i: lifts $(a.keys[i]) — $(a.per_line[i]) share an onset" for i in eachindex(a.keys)]
    return "alliteration (need $(a.min_required) sharing an onset):\n" * join(rows, "\n")
end

scansion(f::ProsodicFeatures) = "free verse: $(f.n_lines) line(s), syllables/line $(f.syllables_per_line)"
scansion(::Unsupported) = "(unsupported form for this language)"

scansion(c::Candidate) =
    "$(nameof(typeof(c.language))) / $(nameof(typeof(c.form)))  (score $(round(c.score.value, digits=3)))\n" *
    scansion(c.analysis)
scansion(a::Analysis) = scansion(best(a))
