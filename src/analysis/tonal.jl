# Tonal-meter fitting (Tang regulated verse). A line realizes a fixed pattern of level (平→'P')
# and oblique (仄→'Z') tones; each line's tones are compared to the target position by position
# ('.' = either). This is the same pattern-matching shape as quantitative meter, with tone as
# the per-syllable property instead of weight — the framework reaching a third pattern-based
# principle. The full regulated-verse inter-line rules (粘/對) and the four distinct line
# templates are deferred; this checks each line against one declared template.

struct TonalFit <: AnalysisResult
    pattern::Vector{Char}
    actual::Vector{String}        # per line: the realized P/Z string
    total_cost::Int
end

function _tonal_fit(parsed::ParsedPoem, ms::MeterSpec)
    pat = ms.pattern
    rows, cost = String[], 0
    for l in lines(parsed)
        tones = [u.tone for u in l.units if u isa TonalSyllable]
        push!(rows, String(tones))
        for i in 1:min(length(tones), length(pat))
            pat[i] == '.' && continue
            tones[i] == pat[i] || (cost += 1)
        end
        cost += abs(length(tones) - length(pat))
    end
    return TonalFit(pat, rows, cost)
end
