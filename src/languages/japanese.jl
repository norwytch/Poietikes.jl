# Japanese mora-based frontend. Each kana is one mora, with the standard exceptions: small
# y-glides (ゃゅょ) and small vowels (ぁぃぅぇぉ) are absorbed into the preceding mora, while
# the sokuon (っ), the moraic nasal (ん), and the long-vowel mark (ー) each count as a mora.
#
# Kanji can't be mora-counted without a reading dictionary (MeCab and the like), so they are
# approximated as one mora each and flagged — all-kana (or furigana) input is exact.

const _KANA_SMALL = Set("ゃゅょぁぃぅぇぉ" * "ャュョァィゥェォ")

_is_kana(ch::Char)  = '぀' <= ch <= 'ヿ'    # hiragana + katakana (incl. ん っ ー)
_is_kanji(ch::Char) = '一' <= ch <= '鿿'    # CJK unified ideographs

"""
    _morae(text) -> Vector{Mora}

Segment kana text into morae. Small kana merge into the preceding mora; kanji are counted
one-each (approximate). Whitespace, punctuation, and Latin characters are ignored.
"""
function _morae(text::AbstractString)
    morae = Mora[]
    for ch in text
        if ch in _KANA_SMALL
            isempty(morae) || (morae[end] = Mora(morae[end].content * string(ch)))
        elseif _is_kana(ch) || _is_kanji(ch)
            push!(morae, Mora(string(ch)))
        end
    end
    return morae
end

function prosodic_parse(text::AbstractString, lang::Japanese)
    stanzas = Stanza[]
    for block in _split_stanzas(text)
        ls = Line[]
        for ln in split(block, '\n')
            isempty(strip(ln)) && continue
            push!(ls, Line(ProsodicUnit[_morae(ln)...], String(strip(ln))))
        end
        isempty(ls) || push!(stanzas, Stanza(ls))
    end
    return ParsedPoem(lang, stanzas, String(text))
end
