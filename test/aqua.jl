using Aqua

# Explicit, fast subset of Aqua's quality checks — the ones the General registry cares about.
# We skip `test_all` to avoid the slow `persistent_tasks` check and `ambiguities` noise that
# leaks in from upstream packages (Languages.jl).
@testset "Aqua" begin
    Aqua.test_undefined_exports(Poietikes)
    Aqua.test_project_extras(Poietikes)
    Aqua.test_deps_compat(Poietikes)
    Aqua.test_piracies(Poietikes)
    Aqua.test_unbound_args(Poietikes)
end
