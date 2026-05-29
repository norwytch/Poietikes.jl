#!/usr/bin/env julia
#
# Analyze a poem from a text file, from the terminal.
#
#   julia --project=. scripts/analyze.jl <file> [language] [form]
#
# `language` and `form` are optional; omit them (or pass `auto`) to auto-detect. Examples:
#
#   julia --project=. scripts/analyze.jl poem.txt                 # detect both
#   julia --project=. scripts/analyze.jl haiku.txt japanese haiku  # fixed language + form
#   julia --project=. scripts/analyze.jl verse.txt latin hexameter

using Poietikes

if isempty(ARGS)
    println(stderr, "usage: julia --project=. scripts/analyze.jl <file> [language] [form]")
    exit(1)
end

language = length(ARGS) >= 2 ? Symbol(ARGS[2]) : :auto
form     = length(ARGS) >= 3 ? Symbol(ARGS[3]) : :auto

analysis = open(io -> analyze(io; language = language, form = form), ARGS[1])
println(scansion(analysis))     # the best candidate's verdict + a human-readable scansion
