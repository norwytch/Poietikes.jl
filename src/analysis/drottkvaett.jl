# Old Norse dróttkvætt — the richest consonantal form, and the one that forces a *composite*
# fit: three constraints hold at once, so it can't be routed to a single axis like the other
# forms. A dedicated `fit(::Drottkvaett, ::Norse, …)` checks all three and sums their costs:
#
#   • count       — six syllables per line;
#   • alliteration — a line-PAIR phenomenon (unlike the per-line AllitFit): the even line's first
#     lift (the höfuðstafr, "head-stave") sets the sound, and the odd line must carry two lifts
#     (stuðlar, "props") on it;
#   • hending      — internal rhyme WITHIN each line (unlike line-final RhymeFit): odd lines take
#     skothending (half-rhyme: shared coda, differing vowel), even lines aðalhending (full rhyme:
#     shared vowel and coda).
#
# Vowel-initial lifts all alliterate (key "V"); s+stop (sp/st/sk) alliterates only as the cluster
# — the Germanic rule. The orthographic frontend (languages/norse.jl) keeps this approximate.

# Onset alliteration key of a syllable: "V" if vowel-initial; the sp/st/sk cluster if one; else
# the first consonant.
function _norse_onset_key(s::Syllable)
    onset, _, _ = _norse_parts(s)
    isempty(onset) && return "V"
    (length(onset) >= 2 && onset[1] == 's' && onset[2] in ('p', 't', 'k')) && return onset[1:2]
    return string(first(onset))
end

_norse_lifts(line::Line) = Syllable[u for u in line.units if u isa Syllable && u.stress == 1]

# Line-pair alliteration cost: how far the odd line falls short of two lifts matching the even
# line's head-stave (0 = satisfied, up to 2 = none match / no head-stave).
function _drottkvaett_allit(odd::Line, even::Line)
    evlifts = _norse_lifts(even)
    isempty(evlifts) && return 2
    head = _norse_onset_key(first(evlifts))
    return max(2 - count(s -> _norse_onset_key(s) == head, _norse_lifts(odd)), 0)
end

# Internal-rhyme cost for one line: 0 if some syllable pair rhymes in the required mode, else 1.
# `full` (aðalhending) needs identical vowel+coda; otherwise (skothending) a shared coda on
# differing vowels. Either way a rhyme needs a coda to land on.
function _hending_cost(line::Line, full::Bool)
    rimes = Tuple{String,String}[]
    for u in line.units
        u isa Syllable || continue
        _, v, c = _norse_parts(u)
        isempty(c) || push!(rimes, (v, c))
    end
    for a in 1:length(rimes), b in (a+1):length(rimes)
        (va, ca), (vb, cb) = rimes[a], rimes[b]
        full ? (va == vb && ca == cb && return 0) : (ca == cb && va != vb && return 0)
    end
    return 1
end

struct DrottkvaettFit <: AnalysisResult
    syllables::Vector{Int}        # syllables per line
    count_cost::Int               # Σ|syllables − 6|
    allit_cost::Int               # line-pair alliteration misses
    hending_cost::Int             # internal-rhyme misses (skothending odd / aðalhending even)
    total_cost::Int
end

function _drottkvaett_fit(parsed::ParsedPoem)
    ls = collect(lines(parsed))
    syllables = Int[count(u -> u isa Syllable, l.units) for l in ls]
    count_cost = sum(abs.(syllables .- 6); init = 0)
    allit_cost, hending_cost = 0, 0
    for i in 1:2:(length(ls) - 1)                       # couplets (1,2), (3,4), …
        allit_cost += _drottkvaett_allit(ls[i], ls[i+1])
        hending_cost += _hending_cost(ls[i], false)      # odd: skothending (half)
        hending_cost += _hending_cost(ls[i+1], true)     # even: aðalhending (full)
    end
    total = count_cost + allit_cost + hending_cost
    return DrottkvaettFit(syllables, count_cost, allit_cost, hending_cost, total)
end

# A six-syllable count is also declared (satisfies the "prescriptive cell has a spec" invariant
# and documents the constraint); the composite fit overrides routing to check all three axes.
countspec(::Drottkvaett, ::Norse) = CountSpec(Syllable, [6])
fit(::Drottkvaett, ::Norse, parsed::ParsedPoem, ::Calibration = default_calibration()) = _drottkvaett_fit(parsed)

_score_analysis(a::DrottkvaettFit, cal::Calibration = default_calibration()) =
    normalize_score(RawScore{CountDistance}(Float64(a.total_cost)), cal)

function scansion(a::DrottkvaettFit)
    head = "dróttkvætt (6 syll/line; line-pair alliteration; hending):"
    rows = ["  line $i: $(a.syllables[i]) syllables" for i in eachindex(a.syllables)]
    foot = "  costs — count $(a.count_cost), alliteration $(a.allit_cost), hending $(a.hending_cost)"
    return head * "\n" * join(rows, "\n") * "\n" * foot
end
