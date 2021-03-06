# # An equation of second order in two dimmensions
#
# Let \\(\Omega = (0, 1)^2\\) the unit square and denote \\( \Gamma = \partial \Omega\\) its boundary.
# Consider the following problem. Given \\(f \in C(\Omega)\\), find a function \\(u\\) satisfying
# \Delta^2 u = f in \Omega
# u = \Delta u = 0 on \Gamma

using Revise
using SymFEL
using LinearAlgebra
using SparseArrays
using WriteVTK
using JLD2


## discretization parameters
# we use the mesh square.msh (in gmsh format)
# obtained from square.geo using gmsh
# this mesh is formed by quad elements
# we use gmsh module for read the mesh
# there are some problems using Threads and gmsh (in linux)
# the file is square.jld2 is prepared separetely
@load "square-simple.jld2"


# elementary matrices - P2 x P2
elem_M = SymFEL.get_square_hermite_em((3, 3), (0, 0), (0, 0))
elem_K = SymFEL.get_square_hermite_em((3, 3), (2, 0), (2, 0)) +
    SymFEL.get_square_hermite_em((3, 3), (2, 0), (0, 2)) +
    SymFEL.get_square_hermite_em((3, 3), (0, 2), (2, 0)) +
    SymFEL.get_square_hermite_em((3, 3), (0, 2), (0, 2))

dx = norm(nodes_coordinate[:, elements_bound[1,1]] - nodes_coordinate[:, elements_bound[2,1]])
elem_K_dx = convert(Matrix{Float64}, elem_K.subs(h, dx))
elem_M_dx = convert(Matrix{Float64}, elem_M.subs(h, dx));

# global matrices
K = SymFEL.assemble_squaremesh_FE_matrix(elem_K_dx, elements_int,
                                           order1=1, order2=1,
                                           dof1=4, dof2=4)
M = SymFEL.assemble_squaremesh_FE_matrix(elem_M_dx, elements_int,
                                           order1=1, order2 = 1,
                                           dof1=4, dof2=4)
 
f = zeros(Float64, 4*nodes_N)
f[4*((1:nodes_N) .- 1) .+ 1] = 4*pi^4*sin.(pi * nodes_coordinate[1,:]) .* sin.(pi * nodes_coordinate[2,:])
f[4*((1:nodes_N) .- 1) .+ 2] = 4*pi^5*cos.(pi * nodes_coordinate[1,:]) .* sin.(pi * nodes_coordinate[2,:])
f[4*((1:nodes_N) .- 1) .+ 3] = 4*pi^5*sin.(pi * nodes_coordinate[1,:]) .* cos.(pi * nodes_coordinate[2,:])
f[4*((1:nodes_N) .- 1) .+ 4] = 4*pi^6*cos.(pi * nodes_coordinate[1,:]) .* cos.(pi * nodes_coordinate[2,:])

F = M * f

F[4*(nodes_boundary.-1).+1] = zeros(nodes_boundary_N)
A = copy(K)

# boundary condition
tgv = 1e30
A[4*(nodes_boundary.-1).+1, 4*(nodes_boundary.-1).+1] += tgv * sparse(Matrix{Float64}(I, nodes_boundary_N, nodes_boundary_N))

u = A \ F
u_exact = zeros(Float64, 4*nodes_N)
u_exact[4*((1:nodes_N) .- 1) .+ 1] = sin.(pi * nodes_coordinate[1,:]) .* sin.(pi * nodes_coordinate[2,:])
u_exact[4*((1:nodes_N) .- 1) .+ 2] = pi * cos.(pi * nodes_coordinate[1,:]) .* sin.(pi * nodes_coordinate[2,:])
u_exact[4*((1:nodes_N) .- 1) .+ 3] = pi * sin.(pi * nodes_coordinate[1,:]) .* cos.(pi * nodes_coordinate[2,:])
u_exact[4*((1:nodes_N) .- 1) .+ 4] = pi^2 * cos.(pi * nodes_coordinate[1,:]) .* cos.(pi * nodes_coordinate[2,:])

err = u - u_exact

println("L2 error : ", sqrt(err' * M * err))
println("H2 error : ", sqrt(err' * K * err))


# export to vtk
cells = [MeshCell(VTKCellTypes.VTK_QUAD, elements_int[1:4, i]) for i = 1:elements_int_N]


points_x = nodes_coordinate[1, :]
points_y = nodes_coordinate[2, :]
vtkfile = vtk_grid("ex4-output", points_x, points_y, cells)

vtkfile["u", VTKPointData()] = u[4*((1:nodes_N) .- 1) .+ 1]
vtkfile["ux", VTKPointData()] = u[4*((1:nodes_N) .- 1) .+ 2]
vtkfile["uy", VTKPointData()] = u[4*((1:nodes_N) .- 1) .+ 3]
vtkfile["uxy", VTKPointData()] = u[4*((1:nodes_N) .- 1) .+ 4]
outfiles = vtk_save(vtkfile)
