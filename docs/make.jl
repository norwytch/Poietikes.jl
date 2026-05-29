using Documenter
using Poietikes

# Build the site into docs/build. Deployment is handled by the Documentation workflow via the
# GitHub Actions Pages source (upload-pages-artifact + deploy-pages), not deploydocs/gh-pages.
makedocs(;
    sitename = "Poietikes.jl",
    modules  = [Poietikes],
    authors  = "Julia Quinn",
    warnonly = true,        # don't fail the build on missing docstrings / source-relative links
    pages = [
        "Home"                => "index.md",
        "Methodology"         => "methodology.md",
        "Adding a language"   => "adding-a-language.md",
        "vs. Python prosodic" => "comparison.md",
        "API reference"       => "api.md",
    ],
)
