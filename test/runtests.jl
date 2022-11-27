using AxisArrayTables
using Test
using ExtendedDates
using CSV
using Plots

# Construction and basic broadcasting
a = AxisArrayTable(reshape(1:15, 5,3), period(Quarter, 1999, 2):period(Quarter, 2000, 2), [:a, :b, :c])
b = similar(a)
b .= 7

@testset "row_labels, column_labels" begin
    @test row_labels(a) === row_labels(b) === period(Quarter, 1999, 2):period(Quarter, 2000, 2)
    @test column_labels(a) === column_labels(b) == [:a, :b, :c]
end

@testset "Matrix accessor" begin
    @test Matrix(a) == reshape(1:15, 5,3)
    @test Matrix(a) isa Matrix{Int}
    @test Matrix(b) == fill(7, 5,3)
    @test Matrix(b) isa Matrix{Int}
end

@testset "parent accessor" begin
    @test parent(a) === reshape(1:15, 5,3)
    @test parent(b) == fill(7, 5,3)
end

@testset "Display" begin
    @test string(a) == """\
┌─────────┬───┬────┬────┐
│         │ a │  b │  c │
├─────────┼───┼────┼────┤
│ 1999-Q2 │ 1 │  6 │ 11 │
│ 1999-Q3 │ 2 │  7 │ 12 │
│ 1999-Q4 │ 3 │  8 │ 13 │
│ 2000-Q1 │ 4 │  9 │ 14 │
│ 2000-Q2 │ 5 │ 10 │ 15 │
└─────────┴───┴────┴────┘
"""
    @test string(b) == """\
┌─────────┬───┬───┬───┐
│         │ a │ b │ c │
├─────────┼───┼───┼───┤
│ 1999-Q2 │ 7 │ 7 │ 7 │
│ 1999-Q3 │ 7 │ 7 │ 7 │
│ 1999-Q4 │ 7 │ 7 │ 7 │
│ 2000-Q1 │ 7 │ 7 │ 7 │
│ 2000-Q2 │ 7 │ 7 │ 7 │
└─────────┴───┴───┴───┘
"""

    buf = IOBuffer()
    @test show(buf, a) === nothing
    @test show(buf, "text/plain", a) === nothing
    @test show(buf, MIME"text/plain"(), a) === nothing
    @test print(buf, a) === nothing
    @test String(take!(buf)) == string(a)^4
end

@testset "More broadcasting" begin
    @test all(b .+ a .== a .+ b)
    @test b .+ a == a .+ b
    @test 2b == b + b == (b .^ b)*2//117_649 != b
    @test 2a == a + a != (a .^ a)*2//117_649
    @test b == 1.0b
    @test eltype(b) != eltype(1.0b)
    @test .-a == 0 .- a
    @test all((a .^ 3 ./ a .^ 2) .== a)
    @test 1 .+ 1 .+ 1 .+ a == 3 .+ a == 1 .+ 1 .+ a .+ 1 == a .+ 1 .+ 1 .+ 1 ==
        a .+ [1 2 3] .+ [2 1 0] == a .+ [1, 2, 3, 4, 5] .+ [2, 1, 0, -1, -2] ==
        b .+ [1, 2, 3, 4, 5] .+ [0 5 10] .- 4 == [1, 2, 3, 4, 5] .+ [0 5 10] .- 4 .+ b
    f(a,b,c) = a+b+c
    @test f.(a, b, 1) == f.(5, 3, a) == f.(2 .* a, 7, .-a) .* 1 .+ 1
end

@testset "size and length" begin
    @test size(a) == (5, 3)
    @test length(a) == 15
end

@testset "Indexing" begin
    @test a[1, 1] == 1
    @test a[1, :a] == 1
    @test a[1, :b] == 6

    @test a.c == a[:, :c] == a[1:5, 3] == a[1:5, :c] == a[:, 3] == a[:, [3]]
    @test a.c isa AxisArrayTable
    @test size(a.c) == (5, 1)

    @test a[1:3, [:c,:b]] isa AxisArrayTable
    @test size(a[1:3, [:c,:b]]) == (3, 2)
    @test a[1:3, [:b, :c]] != a[2:4, [:b, :c]]

    @test a[3, [:a, :b]] isa AxisArrayTable
    @test size(a[3, [:a, :b]]) == (1, 2)
    @test a[3, [:a, :b]] == a[3, [:b, :a]] # Is this the behavior we want?

    @test a[1:3, :a] isa AxisArrayTable
    @test size(a[1:3, :a]) == (3, 1)
    @test a[1:3, :a] == a[1:3, [:a]] == a[1:3, [1]] == a[1:3, 1] == a[1:3, 1:1]
end

@testset "Legacy" begin
    r1 = hash.(reshape(1:12, 4, 3))./typemax(UInt) # Like random, but less random and more consistent
    r2 = hash.(reshape(13:24, 4, 3))./typemax(UInt)
    ta1 = AxisArrayTable(r1, Undated(11):Undated(14), [:a, :b, :c])
    ta2 = AxisArrayTable(r2, period(Week, 1935, 2):period(Week, 1935, 5), [:a, :b, :c])

    @test string(ta2[:b]) == """\
┌─────────┬───────────┐
│         │         b │
├─────────┼───────────┤
│ 1935-W2 │ 0.0955064 │
│ 1935-W3 │  0.454083 │
│ 1935-W4 │  0.812642 │
│ 1935-W5 │    0.1712 │
└─────────┴───────────┘
"""

    @test string(ta2[WeekSE(1935, 3)]) == """\
┌─────────┬───────────┬──────────┬────────┐
│         │         a │        b │      c │
├─────────┼───────────┼──────────┼────────┤
│ 1935-W3 │ 0.0198456 │ 0.454083 │ 0.8883 │
└─────────┴───────────┴──────────┴────────┘
"""

    @test string(ta2[:b, :c]) == """\
┌─────────┬───────────┬──────────┐
│         │         b │        c │
├─────────┼───────────┼──────────┤
│ 1935-W2 │ 0.0955064 │ 0.529768 │
│ 1935-W3 │  0.454083 │   0.8883 │
│ 1935-W4 │  0.812642 │ 0.246866 │
│ 1935-W5 │    0.1712 │ 0.605429 │
└─────────┴───────────┴──────────┘
"""

    @test string(ta2[WeekSE(1935, 3)..WeekSE(1935, 4)]) == """\
┌─────────┬───────────┬──────────┬──────────┐
│         │         a │        b │        c │
├─────────┼───────────┼──────────┼──────────┤
│ 1935-W3 │ 0.0198456 │ 0.454083 │   0.8883 │
│ 1935-W4 │  0.378389 │ 0.812642 │ 0.246866 │
└─────────┴───────────┴──────────┴──────────┘
"""

    @test string(ta2[WeekSE(1935, 3)..WeekSE(1935, 4), [:b, :c]]) == """\
┌─────────┬──────────┬──────────┐
│         │        b │        c │
├─────────┼──────────┼──────────┤
│ 1935-W3 │ 0.454083 │   0.8883 │
│ 1935-W4 │ 0.812642 │ 0.246866 │
└─────────┴──────────┴──────────┘
"""

    @test ta2[WeekSE(1935, 3), :c] === 0.888299622520944

    @test AxisArrayTables.data(ta2.b).data ≈ AxisArrayTables.data(ta2[:b])
    @test AxisArrayTables.data(ta2[:b]) ≈ AxisArrayTables.data(ta2)[:,:b].data
    @test AxisArrayTables.data(ta2[WeekSE(1935, 3)]) ≈ reshape(AxisArrayTables.data(ta2)[2, :], 1, 3)
    @test AxisArrayTables.data(ta2[:b, :c]) ≈ AxisArrayTables.data(ta2)[:, [2, 3]]
    @test AxisArrayTables.data(ta2[WeekSE(1935, 3)..WeekSE(1935, 4)]) ≈ AxisArrayTables.data(ta2)[[2, 3], :]
    @test AxisArrayTables.data(ta2[WeekSE(1935, 3)..WeekSE(1935, 4), [:b, :c]]) ≈ AxisArrayTables.data(ta2)[[2, 3], [2,3]]
    @test ta2[WeekSE(1935, 3), :c] == AxisArrayTables.data(ta2)[2, 3]

    @test all(AxisArrayTables.data(log.(ta1)) ≈ log.(AxisArrayTables.data(ta1)))
    @test ta1 + ta1 == 2*ta1
end

@testset "lead, lag, and diff" begin

    @test string(lag(a)) == """\
┌─────────┬─────────┬─────────┬─────────┐
│         │       a │       b │       c │
├─────────┼─────────┼─────────┼─────────┤
│ 1999-Q2 │ missing │ missing │ missing │
│ 1999-Q3 │       1 │       6 │      11 │
│ 1999-Q4 │       2 │       7 │      12 │
│ 2000-Q1 │       3 │       8 │      13 │
│ 2000-Q2 │       4 │       9 │      14 │
└─────────┴─────────┴─────────┴─────────┘
"""

    @test string(lead(a)) == """\
┌─────────┬─────────┬─────────┬─────────┐
│         │       a │       b │       c │
├─────────┼─────────┼─────────┼─────────┤
│ 1999-Q2 │       2 │       7 │      12 │
│ 1999-Q3 │       3 │       8 │      13 │
│ 1999-Q4 │       4 │       9 │      14 │
│ 2000-Q1 │       5 │      10 │      15 │
│ 2000-Q2 │ missing │ missing │ missing │
└─────────┴─────────┴─────────┴─────────┘
"""

    @test string(diff(a)) == """\
┌─────────┬─────────┬─────────┬─────────┐
│         │       a │       b │       c │
├─────────┼─────────┼─────────┼─────────┤
│ 1999-Q2 │ missing │ missing │ missing │
│ 1999-Q3 │       1 │       1 │       1 │
│ 1999-Q4 │       1 │       1 │       1 │
│ 2000-Q1 │       1 │       1 │       1 │
│ 2000-Q2 │       1 │       1 │       1 │
└─────────┴─────────┴─────────┴─────────┘
"""

    @test string(diff(a, 2)) == """\
┌─────────┬─────────┬─────────┬─────────┐
│         │       a │       b │       c │
├─────────┼─────────┼─────────┼─────────┤
│ 1999-Q2 │ missing │ missing │ missing │
│ 1999-Q3 │ missing │ missing │ missing │
│ 1999-Q4 │       2 │       2 │       2 │
│ 2000-Q1 │       2 │       2 │       2 │
│ 2000-Q2 │       2 │       2 │       2 │
└─────────┴─────────┴─────────┴─────────┘
"""

    if VERSION ≥ v"1.9.0-DEV.1795"
        @testset "No allocations" begin
            function allocations(f,x)
                a = @allocated y = f(x)
                a, y
            end
            @test isequal(allocations(lead, a), (0, lead(a)))
            @test isequal(allocations(lag, b), (0, lag(b)))
        end
    end
end

@testset "merge" begin
    @test string(merge(a, b)) == """\
┌─────────┬───┬────┬────┬────┬────┬────┐
│         │ a │  b │  c │ a2 │ b2 │ c2 │
├─────────┼───┼────┼────┼────┼────┼────┤
│ 1999-Q2 │ 1 │  6 │ 11 │  7 │  7 │  7 │
│ 1999-Q3 │ 2 │  7 │ 12 │  7 │  7 │  7 │
│ 1999-Q4 │ 3 │  8 │ 13 │  7 │  7 │  7 │
│ 2000-Q1 │ 4 │  9 │ 14 │  7 │  7 │  7 │
│ 2000-Q2 │ 5 │ 10 │ 15 │  7 │  7 │  7 │
└─────────┴───┴────┴────┴────┴────┴────┘
"""

    c = AxisArrayTable(reshape(1:.5:4.5, 4,2), period(Quarter, 2000, 2):period(Quarter, 2001, 1), [:a, :beta])
    @test string(c) === """\
┌─────────┬─────┬──────┐
│         │   a │ beta │
├─────────┼─────┼──────┤
│ 2000-Q2 │ 1.0 │  3.0 │
│ 2000-Q3 │ 1.5 │  3.5 │
│ 2000-Q4 │ 2.0 │  4.0 │
│ 2001-Q1 │ 2.5 │  4.5 │
└─────────┴─────┴──────┘
"""

    @test string(merge(a, b, c)) == """\
┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
│         │       a │       b │       c │      a2 │      b2 │      c2 │      a3 │    beta │
├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
│ 1999-Q2 │       1 │       6 │      11 │       7 │       7 │       7 │ missing │ missing │
│ 1999-Q3 │       2 │       7 │      12 │       7 │       7 │       7 │ missing │ missing │
│ 1999-Q4 │       3 │       8 │      13 │       7 │       7 │       7 │ missing │ missing │
│ 2000-Q1 │       4 │       9 │      14 │       7 │       7 │       7 │ missing │ missing │
│ 2000-Q2 │       5 │      10 │      15 │       7 │       7 │       7 │     1.0 │     3.0 │
│ 2000-Q3 │ missing │ missing │ missing │ missing │ missing │ missing │     1.5 │     3.5 │
│ 2000-Q4 │ missing │ missing │ missing │ missing │ missing │ missing │     2.0 │     4.0 │
│ 2001-Q1 │ missing │ missing │ missing │ missing │ missing │ missing │     2.5 │     4.5 │
└─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
"""

    @test string(merge(a, c, b)) == """\
┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
│         │       a │       b │       c │      a2 │    beta │      a3 │      b2 │      c2 │
├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
│ 1999-Q2 │       1 │       6 │      11 │ missing │ missing │       7 │       7 │       7 │
│ 1999-Q3 │       2 │       7 │      12 │ missing │ missing │       7 │       7 │       7 │
│ 1999-Q4 │       3 │       8 │      13 │ missing │ missing │       7 │       7 │       7 │
│ 2000-Q1 │       4 │       9 │      14 │ missing │ missing │       7 │       7 │       7 │
│ 2000-Q2 │       5 │      10 │      15 │     1.0 │     3.0 │       7 │       7 │       7 │
│ 2000-Q3 │ missing │ missing │ missing │     1.5 │     3.5 │ missing │ missing │ missing │
│ 2000-Q4 │ missing │ missing │ missing │     2.0 │     4.0 │ missing │ missing │ missing │
│ 2001-Q1 │ missing │ missing │ missing │     2.5 │     4.5 │ missing │ missing │ missing │
└─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
"""
end

@testset "CSV.write, CSV.read" begin
    path = tempdir()
    @test String(read(CSV.write(joinpath(path, "test.csv"), a))) == """\
time,a,b,c
1999-Q2,1,6,11
1999-Q3,2,7,12
1999-Q4,3,8,13
2000-Q1,4,9,14
2000-Q2,5,10,15
"""

    @test CSV.read(CSV.write(joinpath(path, "test.csv"), a), AxisArrayTable) == a
    @test CSV.read(CSV.write(joinpath(path, "test.csv"), b, delim=';'), AxisArrayTable) == b

    buf = IOBuffer()
    @test CSV.write(buf, a; delim=';') === buf
    @test String(take!(buf)) == """\
time;a;b;c
1999-Q2;1;6;11
1999-Q3;2;7;12
1999-Q4;3;8;13
2000-Q1;4;9;14
2000-Q2;5;10;15
"""
    @test CSV.write(buf, Float64.(a); delim=' ', decimal=',') === buf
    @test String(take!(buf)) == """\
time a b c
1999-Q2 1,0 6,0 11,0
1999-Q3 2,0 7,0 12,0
1999-Q4 3,0 8,0 13,0
2000-Q1 4,0 9,0 14,0
2000-Q2 5,0 10,0 15,0
"""
end

@testset "Plots" begin
    plot(a.b)
    plot!(a[2:end, 1])
    plot!(b.c .+ 1)
    scatter!(a.a)
end
