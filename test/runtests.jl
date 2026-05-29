using Poietikes
using Test

# Reach a few non-exported internals for the structural tests.
using Poietikes: countspec, meterspec, rhymespec, structurespec, allitspec, matraspec, mode, combine, register!,
    _FORMS, _estimate_syllables_english, _parse_cmudict, _morae,
    _french_syllables, _diphthong_nuclei, _ES_VOWELS, _ES_WEAK,
    _iast_weights, _iast_tokens, gana_pattern, _parse_lexique

# Deterministic, offline G2P for the pipeline tests (no network fetch).
const STUB = Dict(
    "happy"  => [Phoneme("HH"), Phoneme("AE1"), Phoneme("P"), Phoneme("IY0")],
    "little" => [Phoneme("L"), Phoneme("IH1"), Phoneme("T"), Phoneme("AH0"), Phoneme("L")],
    "cat"    => [Phoneme("K"), Phoneme("AE1"), Phoneme("T")],
    "sleeps" => [Phoneme("S"), Phoneme("L"), Phoneme("IY1"), Phoneme("P"), Phoneme("S")],
    "under"  => [Phoneme("AH1"), Phoneme("N"), Phoneme("D"), Phoneme("ER0")],
    "warm"   => [Phoneme("W"), Phoneme("AO1"), Phoneme("R"), Phoneme("M")],
    "sun"    => [Phoneme("S"), Phoneme("AH1"), Phoneme("N")],
    "hat"    => [Phoneme("HH"), Phoneme("AE1"), Phoneme("T")],     # rhymes with cat (AE T)
)
set_backend!(English(), DictBackend(STUB))

# Deterministic French G2P (Lexique phon tokens) for rhyme tests — no network fetch.
set_backend!(French(), DictBackend(Dict(
    "chat"  => [Phoneme("S"), Phoneme("a")],            # /ʃa/
    "rat"   => [Phoneme("R"), Phoneme("a")],            # /ʁa/  — rhymes with chat on /a/
    "chien" => [Phoneme("S"), Phoneme("j"), Phoneme("e~")],  # /ʃjɛ̃/
)))

const POEM = "happy little cat\nsleeps\n\nunder warm sun"

# Phase 6: @form must run at module top level (it defines a struct).
@form Lune English begin
    count = (Syllable, [3, 5, 3])      # the Kelly lune: a 3-5-3 syllable tercet
end

# Tier A: rhyme-only and structure-only forms (to exercise those axes).
@form Couplet English begin
    rhyme = ("aa", false)
end
@form Quatrain English begin
    structure = (4, nothing)
end

# Tier B: a French rhyming couplet, to exercise Lexique-backed French rhyme end-to-end.
@form FrenchCouplet French begin
    rhyme = ("aa", false)
end

# Tier D: a Sanskrit mātrā (moraic) meter — 8 mātrās per line (also exercises @form's matra axis).
@form MatraPada Sanskrit begin
    matra = ([8],)
end

# Tier D: a quantitative metre with yati (caesura) after the 4th syllable — exercises the
# word-boundary check on the L/H axis (pattern L H × 4, word break required mid-line).
@form YatiPada Sanskrit begin
    meter = (Quantitative(), nothing, 8, 4, Int[], collect("LHLHLHLH"))
end

# Tier D: a strict 4-syllable quantitative metre and its anceps variant (final position '.').
@form StrictPada Sanskrit begin
    meter = (Quantitative(), nothing, 4, nothing, Int[], collect("LHLH"))
end
@form AncepsPada Sanskrit begin
    meter = (Quantitative(), nothing, 4, nothing, Int[], Poietikes.final_anceps("LHLH"))
end

@testset "Poietikes" begin

    @testset "registry: defined cells, undefined cells, introspection" begin
        @test supports(Haiku(), Japanese())
        @test supports(Haiku(), English())
        @test !supports(Haiku(), French())                      # undefined cell ≠ clean fit
        @test !supports(Sonnet{Shakespearean}(), French())
        @test FreeVerse() in supported_forms(English())
        @test Haiku() in supported_forms(Japanese())
        @test English() in supported_languages()
        @test French() in supported_languages()
    end

    @testset "trait dispatch: same label, language-specific reality" begin
        @test countspec(Haiku(), Japanese()).unit === Mora
        @test countspec(Haiku(), English()).unit === Syllable
        @test countspec(Haiku(), Japanese()).counts == [5, 7, 5]
        @test meterspec(Sonnet{Shakespearean}(), English()).kind isa AccentualSyllabic
        @test meterspec(Sonnet{Shakespearean}(), English()).foot === Iamb
        @test meterspec(Sonnet{Petrarchan}(), French()).kind isa Syllabic
        @test meterspec(Sonnet{Petrarchan}(), French()).len == 12
        @test rhymespec(Haiku(), Japanese()) === nothing
        @test countspec(FreeVerse(), English()) === nothing
    end

    @testset "mode is declared, not inferred from absent specs" begin
        @test mode(FreeVerse(), English()) isa Descriptive
        @test mode(FreeVerse(), Japanese()) isa Descriptive
        @test mode(Haiku(), Japanese()) isa Prescriptive
        @test mode(Sonnet{Shakespearean}(), English()) isa Prescriptive
    end

    @testset "invariant: every prescriptive cell declares ≥1 spec" begin
        for (f, l) in _FORMS
            if mode(f, l) isa Prescriptive
                specs = (countspec(f, l), meterspec(f, l), rhymespec(f, l),
                         structurespec(f, l), allitspec(f, l), matraspec(f, l))
                @test any(!isnothing, specs)
            end
        end
    end

    @testset "data-driven forms share the trait machinery" begin
        cinquain = DataForm(:cinquain, (count = CountSpec(Syllable, [2, 4, 6, 8, 2]),))
        @test countspec(cinquain, English()).counts == [2, 4, 6, 8, 2]
        @test meterspec(cinquain, English()) === nothing
        register!(cinquain, English())
        @test supports(cinquain, English())
        @test cinquain in supported_forms(English())
    end

    @testset "scoring: one comparable currency, with provenance" begin
        s1 = normalize_score(RawScore{LangConfidence}(0.9))
        s2 = normalize_score(RawScore{OTViolations}(3.0))
        @test 0 ≤ s1.value ≤ 1
        @test 0 ≤ s2.value ≤ 1
        @test s2.value ≈ 1 / (1 + 3 / Poietikes._OT_SCALE[])   # calibrated OT scale
        @test normalize_score(RawScore{OTViolations}(0.0)).value == 1.0
        c = combine(s1, s2)
        @test 0 ≤ c.value ≤ 1
        @test length(c.provenance) == 2              # provenance retained across combine
    end

    @testset "g2p + syllabification (Maximum Onset)" begin
        @test [p.symbol for p in pronounce_word(English(), "cat")] == ["K", "AE1", "T"]
        @test length(syllabify_phonemes(STUB["happy"])) == 2
        u = syllabify_phonemes(STUB["under"])         # AH1 N . D ER0  (nasal codas, MOP)
        @test length(u) == 2
        @test (u[1].stress, u[2].stress) == (1, 0)
        @test length(syllabify("happy little cat", English())) == 5
        @test length(pronounce_word(English(), "florble")) == 2   # OOV → vowel-group estimate
    end

    @testset "rule-based syllable estimate" begin
        @test _estimate_syllables_english("cat") == 1
        @test _estimate_syllables_english("happy") == 2
        @test _estimate_syllables_english("make") == 1     # silent trailing 'e'
        @test _estimate_syllables_english("little") == 2   # 'le' exception keeps the count
    end

    @testset "cmudict parser" begin
        sample = ";;; comment\na AH0\na(2) EY1\ncat K AE1 T  # felis catus\n"
        table = _parse_cmudict(IOBuffer(sample))
        @test [p.symbol for p in table["a"]] == ["AH0"]            # primary only; (2) skipped
        @test [p.symbol for p in table["cat"]] == ["K", "AE1", "T"]  # inline comment stripped
    end

    @testset "free-verse descriptive features" begin
        f = features(prosodic_parse(POEM, English()))
        @test f.n_stanzas == 2
        @test f.n_lines == 3
        @test f.syllables_per_line == [5, 1, 4]
        @test f.total_syllables == 10
        @test f.stress_per_line[1] == [1, 0, 1, 0, 1]
        @test f.stress_per_line[3] == [1, 0, 1, 1]
    end

    @testset "analyze pipeline (free verse)" begin
        a = analyze(POEM)                            # :auto → English / FreeVerse
        @test best(a).language isa English
        @test best(a).form isa FreeVerse
        @test best(a).analysis isa ProsodicFeatures
        @test best(a).analysis.syllables_per_line == [5, 1, 4]
        @test best(a).parse.lang isa English
    end

    # ── Phase 2: OT metrical parsing ──
    syl(s) = Syllable(Phoneme[], s)

    @testset "meter construction" begin
        m = build_meter(MeterSpec(AccentualSyllabic(), Iamb, 5))
        @test length(m.positions) == 10
        @test m.positions[1] isa Weak && m.positions[2] isa Strong
        @test foot_pattern(Trochee)[1] isa Strong
        @test length(build_meter(MeterSpec(AccentualSyllabic(), Anapest, 4)).positions) == 12
    end

    @testset "best_parse: alignment + violations" begin
        m = build_meter(MeterSpec(AccentualSyllabic(), Iamb, 2))   # [W,S,W,S]
        # perfectly iambic → zero cost
        p, cost, _ = best_parse(m, [syl(0), syl(1), syl(0), syl(1)])
        @test cost == 0
        @test all(length(sl) == 1 for sl in p.slots)
        # trochaic-against-iambic: stress max in weak (i3) AND trough in strong (i2)
        _, cost2, bd2 = best_parse(m, [syl(1), syl(0), syl(1), syl(0)])
        d = Dict(bd2)
        @test d[:max_in_weak] == 1
        @test d[:trough_in_strong] == 1
        @test cost2 == 4 * 1 + 2 * 1                 # weighted total
        # feminine ending: 5 syllables into 4 positions → exactly one disyllabic position
        p3, _, _ = best_parse(m, [syl(0), syl(1), syl(0), syl(1), syl(0)])
        @test p3 !== nothing
        @test count(sl -> length(sl) == 2, p3.slots) == 1
        @test sum(length, p3.slots) == 5
        # too short to align → degenerate length mismatch (weighted)
        p4, cost4, _ = best_parse(m, [syl(1)])
        @test p4 === nothing
        @test cost4 == 4 * 3                         # weight × |1 - 4|
    end

    @testset "individual constraints" begin
        m = build_meter(MeterSpec(AccentualSyllabic(), Iamb, 2))
        peak_in_weak = MetricalParse(m, [[syl(1)], [syl(0)], [syl(1)], [syl(0)]])
        @test violations(StressMaxInWeak(), peak_in_weak) == 1
        @test violations(TroughInStrong(), peak_in_weak) == 1   # the dip on position 2
        @test violations(PositionSize(), peak_in_weak) == 0
        disyllabic = MetricalParse(m, [[syl(0), syl(0)], [syl(1)], [syl(0)], [syl(1)]])
        @test violations(PositionSize(), disyllabic) == 1
        # initial inversion (line-initial trochee) is permitted — not a stress maximum
        initial_trochee = MetricalParse(m, [[syl(1)], [syl(0)], [syl(0)], [syl(1)]])
        @test violations(StressMaxInWeak(), initial_trochee) == 0
        # clash: two adjacent primary-stressed syllables
        @test violations(Clash(), MetricalParse(m, [[syl(1)], [syl(1)], [syl(0)], [syl(1)]])) == 1
        # lapse: three consecutive unstressed
        @test violations(Lapse(), MetricalParse(m, [[syl(0)], [syl(0)], [syl(0)], [syl(1)]])) == 1
        # constraint hierarchy: the cardinal constraint outweighs the rest
        @test weight(StressMaxInWeak()) > weight(TroughInStrong()) > weight(HeavyInWeak())
    end

    @testset "syllable weight (quantity)" begin
        @test is_heavy(Syllable([Phoneme("K"), Phoneme("AE1"), Phoneme("T")], 1))   # closed: coda T
        @test is_heavy(Syllable([Phoneme("B"), Phoneme("IY1")], 1))                 # long vowel IY
        @test !is_heavy(Syllable([Phoneme("DH"), Phoneme("AH0")], 0))               # open + short AH
    end

    @testset "resolution restriction" begin
        m = build_meter(MeterSpec(AccentualSyllabic(), Iamb, 2))
        light = Syllable([Phoneme("DH"), Phoneme("AH0")], 0, false)             # light, unstressed
        heavy = Syllable([Phoneme("K"), Phoneme("AE1"), Phoneme("T")], 1, false) # heavy, stressed
        funcword = Syllable([Phoneme("T"), Phoneme("UW1")], 1, true)            # light flexible monosyll
        # two resolvable syllables in a position → legal resolution
        legal = MetricalParse(m, [[light, funcword], [syl(1)], [syl(0)], [syl(1)]])
        @test violations(IllegalResolution(), legal) == 0
        # a heavy, primary-stressed syllable cannot be resolved into a shared position
        illegal = MetricalParse(m, [[light, heavy], [syl(1)], [syl(0)], [syl(1)]])
        @test violations(IllegalResolution(), illegal) == 1
        @test !Poietikes._resolvable(heavy)
        @test Poietikes._resolvable(funcword)
        # near-categorical: outweighs even the cardinal stress constraint
        @test weight(IllegalResolution()) > weight(StressMaxInWeak())
    end

    @testset "monosyllabic stress flexibility" begin
        m = build_meter(MeterSpec(AccentualSyllabic(), Iamb, 2))     # [W,S,W,S]
        phs = [Phoneme("K"), Phoneme("AE1"), Phoneme("T")]
        fixed_stressed    = Syllable(phs, 1, false)                  # polysyllable-internal stress
        flexible_monosyll = Syllable(phs, 1, true)                   # monosyllabic word
        # a fixed lexical stress forced into weak positions is a stress maximum → violation
        rigid = MetricalParse(m, [[fixed_stressed], [syl(0)], [fixed_stressed], [syl(0)]])
        @test violations(StressMaxInWeak(), rigid) ≥ 1
        # the same syllables as flexible monosyllables destress in weak → no violation
        flex = MetricalParse(m, [[flexible_monosyll], [syl(0)], [flexible_monosyll], [syl(0)]])
        @test violations(StressMaxInWeak(), flex) == 0
        # parsing marks monosyllabic words flexible, polysyllables fixed
        line1units = prosodic_parse("happy cat", English()).stanzas[1].lines[1].units
        @test !line1units[1].flexible          # "hap" — part of polysyllable "happy"
        @test line1units[end].flexible          # "cat" — monosyllabic word
    end

    @testset "prescriptive fit + analyze routing" begin
        a = analyze(POEM; form = :sonnet)            # Sonnet has meterspec → metrical fit
        @test best(a).analysis isa FormFit
        @test 0 ≤ best(a).score.value ≤ 1
        @test length(best(a).analysis.linefits) == 3
    end

    # ── Phase 3: counted forms ──
    @testset "Japanese mora counting" begin
        @test length(_morae("ふるいけや")) == 5
        @test length(_morae("きょう")) == 2          # ょ absorbed into きょ, then う
        @test length(_morae("がっこう")) == 4        # sokuon っ is its own mora
        @test length(_morae("ニャ")) == 1            # katakana glide
        @test length(_morae("とうきょう")) == 4      # to-u-kyo-u
    end

    @testset "count-fitting" begin
        basho = "ふるいけや\nかわずとびこむ\nみずのおと"        # Bashō's frog haiku (kana)
        cf = best(analyze(basho; language = :japanese, form = :haiku)).analysis
        @test cf isa CountFit
        @test cf.unit === Mora
        @test cf.expected == [5, 7, 5]
        @test cf.actual == [5, 7, 5]
        @test cf.total_distance == 0
        @test best(analyze(basho; language = :japanese, form = :haiku)).score.value == 1.0

        # English haiku count-fit on the (non-haiku) free-verse poem: lines are 5,1,4 syllables
        eh = best(analyze(POEM; form = :haiku)).analysis
        @test eh isa CountFit
        @test eh.unit === Syllable
        @test eh.actual == [5, 1, 4]
        @test eh.total_distance == 7                 # |5-5| + |7-1| + |5-4|

        @test countspec(Tanka(), Japanese()).counts == [5, 7, 5, 7, 7]
        @test supports(Tanka(), Japanese())
    end

    # ── Phase 4: Romance syllabic meter ──
    @testset "French syllabification (e-muet, elision)" begin
        fc(line) = length(_french_syllables(line)[1])
        @test fc("Le jour n'est pas plus pur que le fond de mon cœur") == 12   # Racine alexandrine
        @test fc("une amie") == 3              # elision: un(e)·a·mi(e)
        @test fc("belle") == 1                 # line-final mute e uncounted
        @test fc("belle rose") == 3            # bel·le before consonant; ro·s(e) line-final
        @test fc("que le") == 2                # mute e is the word's only vowel → counts
    end

    @testset "Spanish / Italian diphthong counting" begin
        @test _diphthong_nuclei("poeta", _ES_VOWELS, _ES_WEAK) == 3   # hiatus o·e
        @test _diphthong_nuclei("aire",  _ES_VOWELS, _ES_WEAK) == 2   # diphthong ai
        @test _diphthong_nuclei("día",   _ES_VOWELS, _ES_WEAK) == 2   # accented í breaks
    end

    @testset "Romance stress + synalepha" begin
        sp(word) = [s.stress for s in prosodic_parse(word, Spanish()).stanzas[1].lines[1].units]
        @test sp("azul")  == [0, 1]       # a·ZUL — aguda (ends in consonant)
        @test sp("poeta") == [0, 1, 0]    # po·E·ta — llana (default penult)
        @test sp("día")   == [1, 0]       # DÍ·a — written accent wins
        # synalepha merges a vowel ending one word with a vowel starting the next
        @test length(prosodic_parse("cielo azul", Spanish()).stanzas[1].lines[1].units) == 3
    end

    @testset "Italian endecasillabo" begin
        dante = "Nel mezzo del cammin di nostra vita"
        c = best(analyze(dante; language = :italian, form = :endecasillabo))
        @test c.analysis isa SyllabicFit
        @test c.analysis.actual == [11]        # ley dell'accento finale: last accent (10) + 1
        @test c.analysis.accents == [10]
        @test c.analysis.accents_ok == [true]
        @test c.analysis.total_cost == 0
        @test c.score.value == 1.0
    end

    @testset "syllabic meter fit (alexandrine)" begin
        racine = "Le jour n'est pas plus pur que le fond de mon cœur"
        c = best(analyze(racine; language = :french, form = Sonnet{Petrarchan}()))
        @test c.analysis isa SyllabicFit
        @test c.analysis.expected == 12
        @test c.analysis.actual == [12]
        @test c.analysis.caesura == 6
        @test c.analysis.caesura_ok == [true]    # "pur" ends the first hemistich
        @test c.analysis.total_cost == 0
        @test c.score.value == 1.0
        # a non-alexandrine line: wrong count and/or broken caesura raises the cost
        bad = best(analyze("un petit chat noir"; language = :french, form = Sonnet{Petrarchan}()))
        @test bad.analysis.total_cost > 0
    end

    # ── Phase 5: detection ──
    @testset "language detection (ranked)" begin
        @test detect_language("Le jour n'est pas plus pur que le fond de mon cœur")[1].value isa French
        @test detect_language("ふるいけや かわずとびこむ みずのおと")[1].value isa Japanese
        @test detect_language("the cat sat on the mat and he ran to it")[1].value isa English
        @test detect_language("el gato está en la casa y no se ve")[1].value isa Spanish
        @test length(detect_language("hello")) ≥ 1                     # always ranked, ≥ 1
        @test issorted(detect_language("the and of"); by = r -> r.score.value, rev = true)
    end

    @testset "form detection (ranked)" begin
        basho = "ふるいけや\nかわずとびこむ\nみずのおと"
        forms = detect_form(basho, Japanese())
        @test forms[1].value isa Haiku                 # best fit beats free verse
        @test forms[1].score.value > 0.5
        @test any(r -> r.value isa FreeVerse, forms)    # free verse is always a candidate
    end

    @testset "analyze with detection (:auto)" begin
        basho = "ふるいけや\nかわずとびこむ\nみずのおと"
        a = analyze(basho)                              # both auto
        @test best(a).language isa Japanese
        @test best(a).form isa Haiku
        @test length(a.candidates) ≥ 2                  # ranked set, not a scalar verdict

        e = analyze(POEM)                               # English free verse
        @test best(e).language isa English
        @test best(e).form isa FreeVerse

        # explicit axes still give the pure fit score (unchanged from earlier phases)
        @test best(analyze(POEM; language = :english, form = :haiku)).analysis isa CountFit
    end

    # ── Phase 6: extensibility ──
    @testset "@form (programmer-defined)" begin
        @test supports(Lune(), English())                      # registered by the macro
        @test countspec(Lune(), English()).counts == [3, 5, 3]
        @test mode(Lune(), English()) isa Prescriptive
        @test Lune() in supported_forms(English())
        # the macro-defined form flows through the same fit machinery → CountFit
        a = best(analyze("dog\nlazy in the sun\nasleep"; language = :english, form = Lune()))
        @test a.analysis isa CountFit
        @test a.analysis.expected == [3, 5, 3]
    end

    @testset "load_forms (TOML, data-driven)" begin
        toml = """
        [clerihew]
        language = "english"
        structure = { nlines = 4 }
        rhyme = { scheme = "aabb", refrain = false }

        [septenary]
        language = "english"
        count = { unit = "syllable", counts = [7, 7, 7] }
        """
        path = tempname() * ".toml"
        write(path, toml)
        loaded = load_forms(path)
        @test length(loaded) == 2
        sept = only(f for f in supported_forms(English()) if f isa DataForm && f.name == :septenary)
        @test countspec(sept, English()).counts == [7, 7, 7]
        @test supports(sept, English())

        # a loaded form may not shadow an existing one for the language
        bad = tempname() * ".toml"
        write(bad, "[haiku]\nlanguage = \"english\"\ncount = { unit = \"syllable\", counts = [5,7,5] }\n")
        @test_throws ErrorException load_forms(bad)
    end

    @testset "load_forms: quantitative pattern + feet" begin
        toml = """
        [tomlpada]
        language = "sanskrit"
        meter = { kind = "quantitative", len = 4, pattern = "LHLH" }

        [tomlhex]
        language = "latin"
        meter = { kind = "quantitative", feet = [["HLL", "HH"], ["HLL", "HH"], ["HLL", "HH"], ["HLL", "HH"], ["HLL", "HH"], ["HH", "HL"]] }
        """
        path = tempname() * ".toml"
        write(path, toml)
        load_forms(path)
        # fixed pattern from TOML (Sanskrit)
        pada = only(f for f in supported_forms(Sanskrit()) if f isa DataForm && f.name == :tomlpada)
        @test meterspec(pada, Sanskrit()).pattern == collect("LHLH")
        @test best(analyze("ramā ramā"; language = :sanskrit, form = pada)).analysis.total_cost == 0
        # foot alternatives from TOML (Latin) — same Aeneid line scans cleanly through the search
        hex = only(f for f in supported_forms(Latin()) if f isa DataForm && f.name == :tomlhex)
        @test length(meterspec(hex, Latin()).feet) == 6
        @test best(analyze("arma virumque canō Trōiae quī prīmus ab ōrīs"; language = :latin, form = hex)).analysis.total_cost == 0
    end

    # ── Phase 7: quantitative metre (Sanskrit) ──
    wstr(line) = String([h ? 'H' : 'L' for h in _iast_weights(_iast_tokens(line))])

    @testset "Sanskrit syllable weight (laghu/guru)" begin
        @test wstr("kamala")  == "LLL"      # all short, open
        @test wstr("rāma")    == "HL"       # long ā → guru
        @test wstr("gaṅgā")   == "HH"       # closed by cluster ṅg, then long ā
        @test wstr("buddha")  == "HL"       # geminate dd closes the first syllable
        @test wstr("saṃsāra") == "HHL"      # anusvāra → guru, long ā → guru, light final
    end

    @testset "gaṇa system + Bhujaṅgaprayāta" begin
        @test String(gana_pattern(["ya", "ya", "ya", "ya"])) == "LHHLHHLHHLHH"
        @test String(gana_pattern(["ma"])) == "HHH"
        line = "na māyā na māyā na māyā na māyā"        # (L H H) × 4
        c = best(analyze(line; language = :sanskrit, form = :bhujangaprayata))
        @test c.analysis isa QuantitativeFit
        @test c.analysis.actual == ["LHHLHHLHHLHH"]
        @test c.analysis.total_cost == 0
        @test c.score.value == 1.0
        # a line that doesn't fit the pattern accrues cost
        @test best(analyze("rāma rāma rāma"; language = :sanskrit, form = :bhujangaprayata)).analysis.total_cost > 0
    end

    @testset "Sanskrit Devanāgarī input" begin
        dvg(s) = String([h ? 'H' : 'L' for h in _iast_weights(Poietikes._sanskrit_tokens(s))])
        @test dvg("कमल")   == "LLL"     # ka·ma·la — all short, open
        @test dvg("गङ्गा") == "HH"      # gaṅ (cluster) · gā (long)
        @test dvg("रामः")  == "HH"      # rā (long) · maḥ (visarga)
        # the same Bhujaṅgaprayāta scans identically whether given in Devanāgarī or IAST
        c = best(analyze("न माया न माया न माया न माया"; language = :sanskrit, form = :bhujangaprayata))
        @test c.analysis.actual == ["LHHLHHLHHLHH"]
        @test c.analysis.total_cost == 0
    end

    @testset "mātrā (moraic) meter" begin
        c = best(analyze("rāmā rāmā"; language = :sanskrit, form = MatraPada()))
        @test c.analysis isa MatraFit
        @test c.analysis.actual == [8]          # rā·mā·rā·mā — four guru × 2 = 8 mātrās
        @test c.analysis.total_distance == 0
        # laghu syllables count 1: rā(2)·ma(1)·rā(2)·ma(1) = 6, two short of the target
        @test best(analyze("rāma rāma"; language = :sanskrit, form = MatraPada())).analysis.actual == [6]
    end

    # ── Tier D: Tang tonal regulated verse (Chinese) ──
    @testset "Tang tonal (pinyin)" begin
        line = "shui3 bei4 chun1 feng2 yu3"     # tones 3,4,1,2,3 → Z Z P P Z (the Jueju template)
        c = best(analyze(line; language = :chinese, form = :jueju))
        @test c.analysis isa TonalFit
        @test c.analysis.actual == ["ZZPPZ"]
        @test c.analysis.total_cost == 0
        # wrong tones accrue cost
        @test best(analyze("chun1 feng2 chun1 feng2 chun1"; language = :chinese, form = :jueju)).analysis.total_cost > 0
        # detection picks Chinese from pinyin-with-tones (syllables chosen to avoid Romance stopword collisions)
        @test detect_language(line)[1].value isa Chinese
    end

    # ── Tier D: Greek/Latin foot-alternative quantitative metre (dactylic hexameter) ──
    @testset "Latin dactylic hexameter" begin
        # Each of the first five feet is independently a dactyl (— ∪∪) or spondee (— —); the
        # search finds the realization matching the line. Aeneid 1.1 = D D S S D S.
        aen = best(analyze("arma virumque canō Trōiae quī prīmus ab ōrīs"; language = :latin, form = :hexameter))
        @test aen.analysis isa QuantitativeFit
        @test aen.analysis.actual == ["HLLHLLHHHHHLLHH"]
        @test aen.analysis.matched == ["HLLHLLHHHHHLLHH"]      # the winning foot pattern
        @test aen.analysis.total_cost == 0
        # A different foot mix (D D D S D S) must also scan cleanly — proves substitution search.
        ecl = best(analyze("Tītyre tū patulae recubāns sub tegmine fāgī"; language = :latin, form = :hexameter))
        @test ecl.analysis.actual == ["HLLHLLHLLHHHLLHH"]
        @test ecl.analysis.total_cost == 0
        # Consonantal i: Trōiae scans Trō-jae (4 weights H H here), not Trō-i-ae.
        @test Poietikes._iast_weights(Poietikes._latin_tokens("Trōiae")) == [true, true]
        # Non-hexameter text accrues cost.
        @test best(analyze("the cat sat on the mat and ran"; language = :latin, form = :hexameter)).analysis.total_cost > 0
        @test Hexameter() in supported_forms(Latin())
    end

    # ── Tier D: yati (quantitative caesura) — a required word boundary on the L/H axis ──
    @testset "yati (quantitative caesura)" begin
        # Both lines realize the same pattern L H L H L H L H; they differ only in word breaks.
        ok = best(analyze("ramā ramā ramā ramā"; language = :sanskrit, form = YatiPada()))
        @test ok.analysis isa QuantitativeFit
        @test ok.analysis.actual == ["LHLHLHLH"]
        @test ok.analysis.total_cost == 0                  # word break falls after syllable 4 ⇒ yati met
        # same weights, but no word boundary at syllable 4 ⇒ one yati violation, pattern still clean
        miss = best(analyze("ramā ramāramā ramā"; language = :sanskrit, form = YatiPada()))
        @test miss.analysis.actual == ["LHLHLHLH"]
        @test miss.analysis.total_cost == 1
    end

    # ── Tier D: line-final anceps (brevis in longo) via the wildcard helper ──
    @testset "final anceps" begin
        @test Poietikes.final_anceps("LHHLHHLHHLHH") == collect("LHHLHHLHHLH.")
        # a metre whose final position is anceps accepts either weight there; the strict one does not
        @test best(analyze("ramā rama"; language = :sanskrit, form = AncepsPada())).analysis.total_cost == 0
        @test best(analyze("ramā rama"; language = :sanskrit, form = StrictPada())).analysis.total_cost == 1
        @test best(analyze("ramā ramā"; language = :sanskrit, form = StrictPada())).analysis.total_cost == 0
    end

    # ── Tier D: Arabic al-Khalīl (buḥūr via the foot-alternative search; ziḥāf = foot variants) ──
    @testset "Arabic buḥūr (Ṭawīl, Kāmil)" begin
        # CV → light, CVV/CVC → heavy, same rules as Latin/Sanskrit
        wt(s) = String([h ? 'H' : 'L' for h in Poietikes._iast_weights(Poietikes._arabic_tokens(s))])
        @test wt("faʿūlun") == "LHH"          # fa(L) ʿū(H) lun(H)
        @test wt("mafāʿīlun") == "LHHH"
        @test wt("mutafāʿilun") == "LLHLH"    # the two opening shorts (contracted by iḍmār)
        # al-Ṭawīl: Imruʾ al-Qais's muʿallaqa opening hemistich scans cleanly (faʿūlun mafāʿīlun
        # faʿūlun mafāʿilun, the last foot anceps at the bayt end).
        tawil = best(analyze("qifā nabki min dhikrā ḥabībin wa manzili"; language = :arabic, form = :tawil))
        @test tawil.analysis isa QuantitativeFit
        @test tawil.analysis.actual == ["LHHLHHHLHHLHLL"]
        @test tawil.analysis.total_cost == 0
        # al-Kāmil: mutafāʿilun ×3 (base form)
        @test best(analyze("mutafāʿilun mutafāʿilun mutafāʿilun"; language = :arabic, form = :kamil)).analysis.total_cost == 0
        # iḍmār: a foot may contract L L H L H → H H L H (a *different-length* alternative the search picks)
        @test best(analyze("mustafʿilun mutafāʿilun mutafāʿilun"; language = :arabic, form = :kamil)).analysis.total_cost == 0
        # non-verse text accrues cost
        @test best(analyze("the cat sat on a mat"; language = :arabic, form = :tawil)).analysis.total_cost > 0
        @test Tawil() in supported_forms(Arabic())
    end

    # ── Tier D: Old Norse dróttkvætt — composite fit (count + line-pair allit + internal hending) ──
    @testset "Old Norse dróttkvætt" begin
        # couplet satisfying all three: 6 syllables/line; höfuðstafr f with two stuðlar on f;
        # skothending fold/vald (coda ld, differing vowel); aðalhending borg/sorg (rime org).
        good = "fold renn vald um fang gramr\nfagr ok borg við sorg renn"
        d = best(analyze(good; language = :norse, form = :drottkvaett)).analysis
        @test d isa DrottkvaettFit
        @test d.syllables == [6, 6]
        @test d.allit_cost == 0
        @test d.hending_cost == 0
        @test d.total_cost == 0
        # break the head-stave (even line opens on b; odd line carries no b-lift) → alliteration miss
        bad = best(analyze("fold renn vald um fang gramr\nbragr ok borg við sorg renn"; language = :norse, form = :drottkvaett)).analysis
        @test bad.allit_cost == 2
        # a five-syllable line costs on count
        short = best(analyze("fold renn vald um fang\nfagr ok borg við sorg renn"; language = :norse, form = :drottkvaett)).analysis
        @test short.count_cost == 1
        # s+stop alliterates only as the cluster (st), bare vowels share the key "V"
        @test Poietikes._norse_onset_key(only(Poietikes._norse_syllables("stein"))) == "st"
        @test Poietikes._norse_onset_key(only(Poietikes._norse_syllables("ól"))) == "V"
        @test Drottkvaett() in supported_forms(Norse())
    end

    # ── Tier D: Welsh cynghanedd — consonant-sequence harmony (groes) ──
    @testset "Welsh cynghanedd (groes)" begin
        # Welsh digraphs are single consonants
        @test Poietikes._welsh_cons_seq("llawn dda") == ["ll", "n", "dd"]
        # the two halves answer consonant-for-consonant: cana ef → [c,n,f] = cana fi → [c,n,f]
        harm = best(analyze("cana ef cana fi"; language = :welsh, form = :cywydd)).analysis
        @test harm isa CynghaneddFit
        @test harm.harmony_cost == 0
        # no split yields matching consonant sequences
        @test best(analyze("mab aeth allan heddiw"; language = :welsh, form = :cywydd)).analysis.harmony_cost == 1
        @test Cywydd() in supported_forms(Welsh())
    end

    # ── Tier D: consonantal axis (alliteration) ──
    @testset "alliteration (Germanic)" begin
        # hap·(HH) lit·(L) hat(HH) → two stressed onsets share HH ⇒ meets min 2
        allit = best(analyze("happy little hat"; language = :english, form = Alliterative())).analysis
        @test allit isa AllitFit
        @test allit.per_line == [2]
        @test allit.total_cost == 0
        # cat(K) sun(S) warm(W) — no two onsets agree
        @test best(analyze("cat sun warm"; language = :english, form = Alliterative())).analysis.total_cost > 0
        # vowel-initial stressed syllables alliterate with each other (key "V")
        @test Poietikes._allit_key(Syllable([Phoneme("AH1"), Phoneme("N")], 1)) == "V"
    end

    # ── Tier A: rhyme & structure axes ──
    @testset "rhyme fitting (English)" begin
        rhymed = best(analyze("warm cat\nwarm hat"; language = :english, form = Couplet()))
        @test rhymed.analysis isa RhymeFit
        @test rhymed.analysis.total_cost == 0            # cat / hat → both rime "AE T"
        unrhymed = best(analyze("warm cat\nwarm sun"; language = :english, form = Couplet()))
        @test unrhymed.analysis.total_cost > 0           # cat (AE T) vs sun (AH N)
    end

    @testset "structure fitting" begin
        ok = best(analyze("a\nb\nc\nd"; language = :english, form = Quatrain()))
        @test ok.analysis isa StructureFit
        @test ok.analysis.actual_lines == 4
        @test ok.analysis.total_cost == 0
        @test best(analyze("a\nb\nc"; language = :english, form = Quatrain())).analysis.total_cost == 1
    end

    @testset "free verse still wins detection on an unforced poem" begin
        # with the 0.6 baseline, a form must fit (near-)perfectly to beat free verse
        @test best(analyze(POEM)).form isa FreeVerse
    end

    @testset "Spanish octosílabo" begin
        verde = "verde que te quiero verde"        # Lorca — 8 metrical syllables
        c = best(analyze(verde; language = :spanish, form = :octosilabo))
        @test c.analysis isa SyllabicFit
        @test c.analysis.actual == [8]
        @test c.analysis.total_cost == 0
    end

    @testset "confidence floor" begin
        a = analyze(POEM)
        @test confidence(a) == best(a).score.value
        @test is_confident(a)                              # a clear free-verse poem
        @test !is_confident(analyze(""); threshold = 0.5)  # empty input: decline
    end

    # ── Scansion strings (human-readable output) ──
    @testset "scansion rendering" begin
        m = build_meter(MeterSpec(AccentualSyllabic(), Iamb, 2))
        syl(s) = Syllable(Phoneme[], s)
        sc = scansion(MetricalParse(m, [[syl(0)], [syl(1)], [syl(0)], [syl(1)]]))
        @test occursin("meter", sc) && occursin("+", sc) && occursin("-", sc)
        # counted form: matching lines marked ✓
        cf = best(analyze("ふるいけや\nかわずとびこむ\nみずのおと"; language = :japanese, form = :haiku)).analysis
        @test occursin("✓", scansion(cf))
        # quantitative form: shows the L/H realization
        qf = best(analyze("na māyā na māyā na māyā na māyā"; language = :sanskrit, form = :bhujangaprayata)).analysis
        @test occursin("LHH", scansion(qf))
        # whole analysis renders to a String
        @test scansion(analyze(POEM)) isa String
    end

    # ── Tier C: score calibration ──
    @testset "OT score calibration" begin
        @test calibrate_ot_scale([0.0, 0.0], [10.0, 10.0]) == 5.0     # midpoint of the two means
        old = Poietikes._OT_SCALE[]
        try
            set_ot_scale!(8.0)
            @test normalize_score(RawScore{OTViolations}(8.0)).value == 0.5   # cost == scale → 0.5
            @test normalize_score(RawScore{OTViolations}(0.0)).value == 1.0   # perfect → 1.0
        finally
            set_ot_scale!(old)                                                # restore default
        end
        # metrical_costs returns one weighted cost per line of the fit
        mc = metrical_costs("warm cat sleeps", Sonnet{Shakespearean}(), English())
        @test mc isa Vector{Float64} && length(mc) == 1
    end

    @testset "tunable weights, baseline, weight learner" begin
        reset_constraint_weights!()
        @test weight(StressMaxInWeak()) == 4.0                     # principled default
        set_constraint_weight!(StressMaxInWeak, 9.0)
        @test weight(StressMaxInWeak()) == 9.0                     # override applies
        reset_constraint_weights!()
        @test weight(StressMaxInWeak()) == 4.0                     # cleared

        learned = learn_constraint_weights(["warm cat sleeps"], ["happy little cat"])
        @test learned isa Dict && haskey(learned, StressMaxInWeak)
        @test all(v -> v >= 0, values(learned))                    # weights are non-negative

        old = Poietikes._FREEVERSE_BASELINE[]
        try
            set_freeverse_baseline!(0.9)
            @test Poietikes._FREEVERSE_BASELINE[] == 0.9
        finally
            set_freeverse_baseline!(old)
        end
    end

    # ── Tier B: French rhyme via Lexique ──
    @testset "Lexique parser + French rhyme" begin
        sample = "ortho\tphon\textra\nchat\tSa\tx\nlion\tljO~\ty\n"   # header + 2 rows
        t = _parse_lexique(IOBuffer(sample))
        @test [p.symbol for p in t["chat"]] == ["S", "a"]
        @test [p.symbol for p in t["lion"]] == ["l", "j", "O~"]       # nasal "~" combined

        @test rhyme_key(Line(ProsodicUnit[], "le chat"), French()) ==
              rhyme_key(Line(ProsodicUnit[], "le rat"), French())     # both rime /a/
        @test rhyme_key(Line(ProsodicUnit[], "le chat"), French()) !=
              rhyme_key(Line(ProsodicUnit[], "le chien"), French())   # /a/ vs /ɛ̃/
        @test rhyme_key(Line(ProsodicUnit[], "le xyzzy"), French()) isa String  # OOV → orthographic fallback

        # end-to-end: a French rhyming couplet scores cost 0; a non-rhyming one doesn't
        @test best(analyze("le chat\nle rat"; language = :french, form = FrenchCouplet())).analysis.total_cost == 0
        @test best(analyze("le chat\nle chien"; language = :french, form = FrenchCouplet())).analysis.total_cost > 0
    end

    # ── Tier A: Tier-3 candidate disambiguation (count flex) ──
    @testset "count flex (diérèse / dialefa)" begin
        # the syllabifier reports optional expansions
        @test _french_syllables("lion")[2] >= 1            # i+o → diérèse candidate
        @test _french_syllables("le chat")[2] == 0          # no diérèse site
        @test prosodic_parse("la abeja", Spanish()).stanzas[1].lines[1].expansions == 1  # one synalepha junction

        # range fit: a 7-syllable line that can dialefa to 8 fits the octosílabo; without the
        # expansion it would miss by one.
        syls = ProsodicUnit[Syllable(Phoneme[], i == 6 ? 1 : 0, false, true) for i in 1:7]  # metrical 7
        spec = meterspec(Octosilabo(), Spanish())
        flexed = ParsedPoem(Spanish(), [Stanza([Line(syls, "x", 1)])], "x")
        rigid  = ParsedPoem(Spanish(), [Stanza([Line(syls, "x", 0)])], "x")
        @test Poietikes._syllabic_fit(flexed, spec).total_cost == 0   # 8 reachable in [7, 8]
        @test Poietikes._syllabic_fit(rigid,  spec).total_cost == 1   # stuck at 7
    end

    @testset "undefined (form, language) → descriptive, not refused" begin
        # Sonnet isn't defined for Japanese; analyze it as if it had no template (features only)
        a = best(analyze("ふるいけや\nかわずとびこむ\nみずのおと"; language = :japanese, form = :sonnet))
        @test !supports(Sonnet{Shakespearean}(), Japanese())
        @test a.analysis isa ProsodicFeatures
    end

end
