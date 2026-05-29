# Research scripts

The `research/` folder holds exploratory analyses that build *on top of* poietikês's parse and
fits — spectral, information-theoretic, and (eventually) embedding/optimal-transport — without
adding their dependencies to the core package. Each file is a standalone Julia script you run
from the repo root:

```bash
julia --project=. research/spectral.jl
julia --project=. research/entropy.jl
```

## Foundation: form-independent features

[`research/features.jl`](https://github.com/norwytch/Poietikes.jl/blob/main/research/features.jl)
exposes two per-poem extractors that feed everything else:

- **`stress_series(parsed | text, language) -> Vector{Int}`** — the poem's **lexical** stress as
  a ±1 sequence, one entry per syllable. Deliberately form-independent: it reads each syllable's
  citation stress, never a meter-assigned realization, so the downstream analyses don't
  presuppose a form. (The clean meter-realized alternation that peaks at 0.5 lives in the OT
  parse — that's a separate, form-dependent series.)
- **`cost_vector(text, language) -> NamedTuple`** — the poem's fit score against every supported
  form for `language`, a point in form-space. The substrate for embedding (UMAP/t-SNE) and
  optimal-transport analyses across a corpus.

## Spectral analysis

[`research/spectral.jl`](https://github.com/norwytch/Poietikes.jl/blob/main/research/spectral.jl)
runs a naive (O(n²)) DFT on the ±1 stress series — poems are short, so an FFTW dependency isn't
worth it.

- **`stress_spectrum(series)`** returns `(freqs, power)` at frequencies `0, 1/n, …, 0.5` cycles
  per syllable.
- **`dominant_frequency(series)`** returns the peak (DC ignored): ≈ 0.5 for iambic, ≈ 1/p for any
  period-p rhythm, 0.0 when there's no variation.

A self-validating demo confirms the method on synthetic series before touching real poems:

```
synthetic iambic (period 2)  n=14  dominant freq=0.5
synthetic anapest (period 3) n=15  dominant freq=0.333
flat (no variation)          n=14  dominant freq=0.0
Shakespeare (lexical)        n=10  dominant freq=0.5
```

The Shakespeare line's lexical stress isn't cleanly alternating, yet the spectrum still peaks at
0.5 — the kind of disagreement worth chasing across a corpus.

## Information-theoretic compression

[`research/entropy.jl`](https://github.com/norwytch/Poietikes.jl/blob/main/research/entropy.jl)
gives single-number summaries of "how predictable is this rhythm" that don't assume a form:

- **`shannon_entropy(series)`** — `H(s)` in bits; 1.0 for a balanced binary series.
- **`conditional_entropy(series; order = k)`** — `H(sₙ | sₙ₋₁, …, sₙ₋ₖ)`. The discriminator
  between *balanced* and *predictable*: iambic has `H = 1` but `H(·|2) = 0`.
- **`lempel_ziv(series)`** — LZ76 phrase count. Low = predictable, high = random-looking.

```
synthetic iambic (period 2)    n= 14  H=1.0    H(·|2)=0.0    LZ=3
synthetic anapest (period 3)   n= 15  H=0.918  H(·|2)=0.0    LZ=3
irregular (deterministic)      n= 14  H=0.985  H(·|2)=0.792  LZ=6
Shakespeare (lexical)          n= 10  H=0.881  H(·|2)=0.594  LZ=5
```

`H` and `H(·|k)` together separate **balanced** from **predictable**: the iambic and irregular
series have nearly identical Shannon `H` but very different conditional entropy.

## What's next

The features `stress_series` and `cost_vector` are the substrate for the corpus-level analyses
sketched in the project's notes — UMAP/t-SNE embeddings, Wasserstein distances between poets,
recurrence-quantification, persistent homology of score landscapes. Those each add a real
dependency (UMAP.jl, OptimalTransport.jl, Ripserer.jl) and would warrant their own
`research/Project.toml`; they are not implemented yet.
