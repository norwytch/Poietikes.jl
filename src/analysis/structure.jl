# Structure fitting: does the poem have the declared number of lines / stanzas? The simplest
# axis — a pure count of the containment hierarchy against the form's StructureSpec.

struct StructureFit <: AnalysisResult
    expected_lines::Union{Int,Nothing}
    expected_stanzas::Union{Int,Nothing}
    actual_lines::Int
    actual_stanzas::Int
    total_cost::Int
end

function _structure_fit(parsed::ParsedPoem, ss::StructureSpec)
    nl = sum(length(s.lines) for s in parsed.stanzas; init = 0)
    ns = length(parsed.stanzas)
    cost = 0
    ss.nlines   === nothing || (cost += abs(nl - ss.nlines))
    ss.nstanzas === nothing || (cost += abs(ns - ss.nstanzas))
    return StructureFit(ss.nlines, ss.nstanzas, nl, ns, cost)
end
