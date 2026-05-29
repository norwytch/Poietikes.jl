using Documenter
using Poietikes

makedocs(;
    sitename = "Poietikes.jl",
    modules  = [Poietikes],
    authors  = "Julia Quinn",
    warnonly = true,        # don't fail the build on missing docstrings / source-relative links
    pages = [
        "Home"                => "index.md",
        "Adding a language"   => "adding-a-language.md",
        "vs. Python prosodic" => "comparison.md",
        "API reference"       => "api.md",
    ],
)

deploydocs(;
    repo      = "github.com/norwytch/Poietikes.jl",
    devbranch = "main",
)
