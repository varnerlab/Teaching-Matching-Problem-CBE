
"""
    function update_cost_array!(model::MyDirectedBipartiteGraphModel, weights::Array{Float64,1}; cost::Float64 = 0.0, 
            faculty::Int64 = 1, course::Int64 = 1)

Update the cost array for the directed bipartite graph model.

# Arguments
- `model::MyDirectedBipartiteGraphModel`: The directed bipartite graph model.
- `weights::Array{Float64,1}`: The array of weights (costs) for each edge.
- `wv::Float64`: The weight value to assign to the specified edge.
- `faculty::Int64`: The faculty index (default is 1).
- `course::Int64`: The course index (default is 1).

# Returns
- `Nothing`: The function updates the model in place.
"""
function update_cost_array!(model::MyDirectedBipartiteGraphModel, weights::Array{Float64,1}; 
    wv::Float64 = 0.0, faculty::Int64 = 1, course::Int64 = 1)

    # loop over all edges    
    for (k,v) ∈ model.edgesinverse

        # get the edge index
        edge_index = k;
        s = v[1]; # source node
        t = v[2]; # target node

        if (s == faculty) && (t == course)
            # set the weight
            weights[edge_index] = wv; # weight
        end
    end
end

"""
    function update_capacity_array!(model::MyDirectedBipartiteGraphModel, bounds::Array{Float64,2}; 
        lb::Float64 = 0.0, ub::Float64 = 1.0, faculty::Int64 = 1, course::Int64 = 1, bos::Int64 = 1)

Update the capacity bounds array for the directed bipartite graph model.

# Arguments
- `model::MyDirectedBipartiteGraphModel`: The directed bipartite graph model.
- `bounds::Array{Float64,2}`: The array of capacity bounds for each edge.
- `lb::Float64`: The lower bound to assign to the specified edge (default is 0.0).
- `ub::Float64`: The upper bound to assign to the specified edge (default is 1.0).
- `faculty::Int64`: The faculty index (default is 1).
- `bos::Int64`: The index of the "beginning of source" node (default is 1).
"""
function update_capacity_array!(model::MyDirectedBipartiteGraphModel, bounds::Array{Float64,2}; 
    lb::Float64 = 0.0, ub::Float64 = 1.0, faculty::Int64 = 1, bos::Int64 = 1)


    # main loop over all faculty
    for (k,v) ∈ model.edgesinverse       
        edge_index = k;  # get the edge index
        s = v[1]; # source node
        t = v[2]; # target node

        # update the faculty to course capacity
        if (faculty == s)
            # set the bounds
            bounds[edge_index, 1] = lb; # lower bound
            bounds[edge_index, 2] = ub; # upper bound
        end

        # update BOS to this faculty
        if (s == bos) && (t == faculty)
            # set the bounds
            bounds[edge_index, 1] = 0.0; # lower bound
            bounds[edge_index, 2] = ub; # upper bound
        end
    end
end