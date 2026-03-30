
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


"""
    update_edge_capacity!(model::MyDirectedBipartiteGraphModel, bounds::Array{Float64,2};
        source::Int64 = 1, target::Int64 = 1, lb::Float64 = 0.0, ub::Float64 = 1.0)

Update the capacity bounds for a specific (source, target) edge.
Unlike `update_capacity_array!`, this targets a single edge rather than all edges from a source node.
"""
function update_edge_capacity!(model::MyDirectedBipartiteGraphModel, bounds::Array{Float64,2};
    source::Int64 = 1, target::Int64 = 1, lb::Float64 = 0.0, ub::Float64 = 1.0)

    for (k, v) ∈ model.edgesinverse
        if v[1] == source && v[2] == target
            bounds[k, 1] = lb
            bounds[k, 2] = ub
        end
    end
end


"""
    extract_matching(flow, gateway_nodes, course_nodes, faculty_df, courses_df) -> Dict{String, Vector{String}}

Extract faculty-to-course assignments from the flow solution for one semester.

# Arguments
- `flow`: Dict{Tuple{Int,Int}, Float64} — flow on each edge
- `gateway_nodes`: Vector{Int} — gateway node indices (one per faculty)
- `course_nodes`: Vector{Int} — course node indices for the semester
- `faculty_df`: DataFrame — faculty data (must have :name column, rows aligned with gateway_nodes)
- `courses_df`: DataFrame — course data (must have :course column, rows aligned with course_nodes)
"""
function extract_matching(flow::Dict{Tuple{Int,Int}, Float64},
    gateway_nodes::Vector{Int}, course_nodes::Vector{Int},
    faculty_df::DataFrame, courses_df::DataFrame)

    matching = Dict{String, Vector{String}}()
    for i in eachindex(gateway_nodes)
        gw = gateway_nodes[i]
        faculty_name = String(faculty_df[i, :name])
        assigned = String[]
        for j in eachindex(course_nodes)
            cn = course_nodes[j]
            fv = get(flow, (gw, cn), 0.0)
            if fv > 0.0
                push!(assigned, String(courses_df[j, :course]))
            end
        end
        matching[faculty_name] = assigned
    end
    return matching
end