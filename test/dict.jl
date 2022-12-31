using Test
using ATP45
import ATP45: id, description
import ATP45: children, parent, nodevalue
import ATP45: LowerThan10, HigherThan10
import ATP45: ContainerGroupE, ContainerGroupF
import ATP45: TreeNode
import ATP45: build_verbose_tree, tree_to_dict, properties
using JSON3

example_tree = [
    Simplified => [
        ChemicalWeapon => [
            LowerThan10 => (:_circle_circle, 2_000, 10_000),
            HigherThan10 => (:_circle_triangle, 2_000, 10_000),
        ],
        BiologicalWeapon => [
            LowerThan10 => (:_circle_circle, 2_000, 10_000),
            HigherThan10 => (:_circle_triangle, 2_000, 10_000),
        ],
    ],
    Detailed => [
        ChemicalWeapon => [
            ReleaseTypeA => [
                LowerThan10 => (:_circle_circle, 1_000, 10_000),
                HigherThan10 => [
                    ContainerGroupE => [
                        Unstable => (:_circle_triangle, 1_000, 10_000),
                        Neutral => (:_circle_triangle, 1_000, 30_000),
                        Stable => (:_circle_triangle, 1_000, 50_000),
                    ],
                    ContainerGroupF => [
                        Unstable => (:_circle_triangle, 1_000, 15_000),
                        Neutral => (:_circle_triangle, 1_000, 30_000),
                        Stable => (:_circle_triangle, 1_000, 50_000),
                    ],
                ],
            ],
        ],
        BiologicalWeapon => (:_circle_circle, 2_000, 10_000),
    ],
]

tree = TreeNode(example_tree)

@testset "Tree to dict" begin
    newtree = build_verbose_tree(tree)

    props = properties(ChemicalWeapon())
    @test props.id == "chem"
    @test props == properties("chem")
    container = properties(ContainerGroupE())
    @test container.content == ["SHL", "BML", "MNE"]
    dict = tree_to_dict(newtree)
    @test dict isa AbstractDict
    @test dict[:id] == "root"
    jsonstring = JSON3.write(dict)
    json = JSON3.read(jsonstring)
    @test json.children[1].id == "simplified"
    open("test.json", "w") do f
        JSON3.write(f, dict)
    end
end