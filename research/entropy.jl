# Information-theoretic compression measures on the ±1 stress series.
# Run from the repo root:  julia --project=. research/entropy.jl

include("features.jl")

"Shannon entropy H(s) in bits — 1.0 for a balanced binary series, 0 if all one symbol."
function shannon_entropy(series)
    isempty(series) && return 0.0
    p = count(==(1), series) / length(series)
    (p == 0 || p == 1) && return 0.0
    return -p * log2(p) - (1 - p) * log2(1 - p)
end

"Conditional entropy H(sₙ | sₙ₋₁, …, sₙ₋ₖ). Order-1 ≈ 0 means \"this symbol is determined by the\nlast one\" (iambic is the canonical case); ≈ 1 means \"the past tells you nothing\"."
function conditional_entropy(series; order::Int = 2)
    n = length(series)
    n ≤ order && return 0.0
    counts = Dict{NTuple{order, Int}, Dict{Int, Int}}()
    for i in 1:(n - order)
        ctx = ntuple(j -> series[i + j - 1], order)
        nxt = series[i + order]
        d = get!(counts, ctx, Dict{Int, Int}())
        d[nxt] = get(d, nxt, 0) + 1
    end
    total = n - order
    H = 0.0
    for d in values(counts)
        N = sum(values(d))
        pctx = N / total
        Hctx = 0.0
        for cnt in values(d)
            p = cnt / N
            p > 0 && (Hctx -= p * log2(p))
        end
        H += pctx * Hctx
    end
    return H
end

"Lempel–Ziv (LZ76) complexity — the number of phrases in the LZ parse. Low = predictable, high = random-looking."
function lempel_ziv(series)
    n = length(series)
    n == 0 && return 0
    s = join(c == 1 ? '1' : '0' for c in series)
    i, c = 1, 0
    while i ≤ n
        L = 0
        while i + L ≤ n
            sub  = s[i:i+L]
            past = s[1:i+L-1]
            (isempty(past) || !occursin(sub, past)) && break
            L += 1
        end
        c += 1
        i += L + 1
    end
    return c
end

if abspath(PROGRAM_FILE) == @__FILE__
    show_row(label, s) = println(rpad(label, 30), " n=", lpad(length(s), 3),
        "  H=",      rpad(round(shannon_entropy(s);    digits = 3), 5),
        "  H(·|2)=", rpad(round(conditional_entropy(s; order = 2); digits = 3), 5),
        "  LZ=",     lempel_ziv(s))

    show_row("synthetic iambic (period 2)",  repeat([-1,  1], 7))                  # H=1, H(·|2)≈0, LZ low
    show_row("synthetic anapest (period 3)", repeat([-1, -1, 1], 5))                # H<1, H(·|2)≈0
    show_row("irregular (deterministic)",    [1,-1,-1,1,1,1,-1,-1,1,-1,1,1,-1,1])   # H≈1, H(·|2) high, LZ high

    try
        line = "Shall I compare thee to a summer's day"
        s = stress_series(line, English())
        show_row("Shakespeare (lexical)", s)
    catch e
        println("\n(skipped real-poem demo: ", sprint(showerror, e), ")")
    end
end
