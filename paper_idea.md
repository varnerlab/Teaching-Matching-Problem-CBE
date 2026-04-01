# Paper Idea: Faculty-Course Assignment via Min-Cost Max-Flow

## Core contribution
- Gateway node architecture for multi-semester matching with per-semester capacity constraints
- Real-world deployment solving an actual institutional need with real preference data
- Override mechanism to bridge the gap between incomplete survey data and institutional knowledge
- Team-taught courses with fractional credit allocation

## Potential framing options

### 1. Operations research / INFORMS audience
- Focus on the formulation, scalability, and how the override mechanism handles incomplete preference data
- Emphasize the directed graph structure with gateway nodes as a modeling contribution

### 2. Engineering education audience (e.g., ASEE)
- Focus on practical deployment, equity of workload distribution, and how preference surveys map to assignments
- Probably the easiest path to publication and most impactful -- department chairs everywhere deal with this manually

### 3. Short arxiv note / tutorial
- "Minimum-Cost Flow for Faculty-Course Assignment: A Practical Guide"
- Emphasize reproducibility and the open-source implementation

## What would strengthen the paper
- Comparison against the manual process (how much better/fairer are the LP assignments?)
- Sensitivity analysis (how do results change with different override strategies?)
- A second department's data to show generalizability
- Analysis of the survey data quality issue (many courses not surveyed, blanks defaulting to worst preference)
