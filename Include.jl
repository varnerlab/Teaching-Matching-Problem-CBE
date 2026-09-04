const _ROOT = @__DIR__
const _PATH_TO_DATA = joinpath(_ROOT, "data")
const _PATH_TO_CONFIG = joinpath(_PATH_TO_DATA, "config")
const _PATH_TO_SRC = joinpath(_ROOT, "src")
const _PATH_TO_RESULTS = joinpath(_ROOT, "results")

# Keep the command-line solver lightweight. The legacy visualization notebook
# imports its additional plotting and file-format packages itself.
using CSV
using DataFrames
using Dates
using JSON
using PrettyTables
using SHA
using VLDataScienceMachineLearningPackage

include(joinpath(_PATH_TO_SRC, "Updates.jl"))
include(joinpath(_PATH_TO_SRC, "BuildGraph.jl"))
include(joinpath(_PATH_TO_SRC, "TeachingMatching.jl"))
