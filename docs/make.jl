using AxisArrayTables
using Documenter

DocMeta.setdocmeta!(AxisArrayTables, :DocTestSetup, :(using AxisArrayTables); recursive=true)

makedocs(;
    modules=[AxisArrayTables],
    authors="Lilith Hafner <Lilith.Hafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/AxisArrayTables.jl/blob/{commit}{path}#{line}",
    sitename="AxisArrayTables.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/AxisArrayTables.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/AxisArrayTables.jl",
    devbranch="main",
)
