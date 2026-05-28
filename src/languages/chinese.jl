# Chinese frontend for Tang regulated verse (近體詩). Tonal meter classifies each syllable as
# level (平, píng) or oblique (仄, zè). Input is pinyin with tone numbers (e.g. "chun1 mian2
# bu4"); tones 1–2 → level, 3–4 → oblique. (Hanzi input needs a character→reading dictionary,
# deferred; and Mandarin has lost the entering tone 入聲 — classically oblique — so a few
# characters mis-classify under this mapping. Documented limitations.)

function _chinese_syllables(line::AbstractString)
    units = ProsodicUnit[]
    for m in eachmatch(r"[a-zA-ZüÜ]+[1-5]", line)
        d = last(m.match)
        d == '5' && continue                                   # neutral tone (not classical)
        push!(units, TonalSyllable(d in ('1', '2') ? 'P' : 'Z'))
    end
    return units
end

function prosodic_parse(text::AbstractString, lang::Chinese)
    stanzas = Stanza[]
    for block in _split_stanzas(text)
        ls = Line[]
        for ln in split(block, '\n')
            isempty(strip(ln)) && continue
            push!(ls, Line(_chinese_syllables(ln), String(strip(ln))))
        end
        isempty(ls) || push!(stanzas, Stanza(ls))
    end
    return ParsedPoem(lang, stanzas, String(text))
end

# One canonical pentasyllabic tonal template, 仄仄平平仄 (checked per line). The full
# regulated-verse structure (4/8 lines) and the 粘/對 inter-line rules are deferred.
meterspec(::Jueju, ::Chinese) = MeterSpec(Tonal(), nothing, 5, nothing, Int[], ['Z', 'Z', 'P', 'P', 'Z'])
