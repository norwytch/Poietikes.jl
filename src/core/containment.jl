# Containment hierarchy. The prosodic parse is RELATIVE to a language hypothesis — the same
# string parses differently under each candidate language — so a ParsedPoem carries the
# language it was parsed under. Construction (prosodic_parse) lands in languages/ next slice.

struct Line
    units::Vector{ProsodicUnit}     # ordered prosodic units under the language hypothesis
    surface::String                 # the raw line text
    expansions::Int                 # optional syllable additions (diérèse/dialefa) — count flex
end
Line(units::Vector{ProsodicUnit}, surface::AbstractString) = Line(units, String(surface), 0)

struct Stanza
    lines::Vector{Line}
end

struct ParsedPoem
    lang::Language                  # the hypothesis this parse is relative to
    stanzas::Vector{Stanza}
    source::String                  # original text
end

lines(p::ParsedPoem) = Iterators.flatten(s.lines for s in p.stanzas)
