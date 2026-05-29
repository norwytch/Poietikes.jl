# Spectral analysis of stress patterns. Naive O(n²) DFT (poems are short → no FFTW dep).
# Run from the repo root:  julia --project=. research/spectral.jl

include("features.jl")

"Power spectrum of a mean-removed ±1 series at frequencies 0, 1/n, …, 0.5 (cycles/syllable)."
function stress_spectrum(series::AbstractVector{<:Real})
    n = length(series)
    x = series .- (sum(series) / n)
    nf = n ÷ 2
    freqs = [k / n for k in 0:nf]
    power = [let re = sum(x[t+1] * cos(-2π * k * t / n) for t in 0:n-1),
                 im = sum(x[t+1] * sin(-2π * k * t / n) for t in 0:n-1)
             (re^2 + im^2) / n end for k in 0:nf]
    return freqs, power
end

"Frequency of peak power (DC ignored). ≈0.5 for clean iambic alternation; ≈1/p for period-p rhythm."
function dominant_frequency(series)
    length(series) < 2 && return 0.0
    freqs, power = stress_spectrum(series)
    ac = @view power[2:end]
    (isempty(ac) || maximum(ac) ≤ 1e-12) && return 0.0
    return freqs[argmax(ac) + 1]
end

if abspath(PROGRAM_FILE) == @__FILE__
    show_demo(label, series) = println(rpad(label, 28), " n=", length(series),
        "  dominant freq=", round(dominant_frequency(series); digits = 3))

    # 1. Self-validation: known periods must show the right peak.
    show_demo("synthetic iambic (period 2)",  repeat([-1,  1], 7))        # → 0.5
    show_demo("synthetic anapest (period 3)", repeat([-1, -1, 1], 5))     # → 0.333
    show_demo("flat (no variation)",          fill(1, 14))                # → 0.0 (guard)

    # 2. A real English line's LEXICAL stress (fetches CMUdict once on first run).
    try
        line = "Shall I compare thee to a summer's day"
        s = stress_series(line, English())
        println("\nShakespeare line lexical ±1: ", s)
        show_demo("Shakespeare (lexical)", s)
        println("\ncost_vector(\"$line\", English()):")
        println("  ", cost_vector(line, English()))
    catch e
        println("\n(skipped real-poem demo: ", sprint(showerror, e), ")")
    end
end
