# Infrastructure Diagramming

Document infrastructure topology using the `diagrams` library. Diagrams are generated from Python code, versionable in git, and reviewed alongside code changes.

## When to Diagram

Use diagrams for:
- **Network topology** — VPCs, subnets, load balancers, traffic flow
- **System architecture** — how services and infrastructure layers connect
- **Deployment topology** — nodes, clusters, availability zones
- **Data flow** — which systems connect and how

**Do not** diagram:
- Implementation details (how a service scales, handles retries)
- Trivial systems (single resource doesn't need a diagram)
- Sequences (use flowcharts for request lifecycles)
- UI or application flows

## One Layer Per Diagram

Each diagram shows one abstraction layer to stay readable:

- **Infrastructure**: Network topology, load balancers, compute nodes, storage
- **Orchestration**: Control planes, worker nodes, pod replicas
- **Application**: Microservices, databases, job queues

A reader should understand each diagram in 30 seconds without context-switching.

## Structure

Diagrams live in `docs/architecture/`:

```
docs/architecture/
├── network-topology.py
├── network-topology.md
├── compute-cluster.py
├── compute-cluster.md
└── output/
    ├── network-topology.png
    └── compute-cluster.png
```

### Python Script: `docs/architecture/<name>.py`

```python
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import VPC, ALB
from diagrams.aws.compute import EC2

diagram = Diagram(
    "System Architecture - Layer",
    filename="docs/architecture/output/<name>",
    show=False,
    direction="TB",
)

with diagram:
    # Build the infrastructure topology using Clusters and Edges
    pass
```

Run to generate the PNG:

```bash
python docs/architecture/network-topology.py
```

### Markdown: `docs/architecture/<name>.md`

Document the diagram's scope and intent:

```markdown
# Network Topology - Infrastructure Layer

Shows inbound traffic from users through load balancers to compute nodes.

![Diagram](output/network-topology.png)

## Scope

**Layer**: Infrastructure only — VPC, subnets, load balancers, ENIs.

**What it shows**: Traffic entry points and network boundaries.

## What Is NOT Shown

- Individual pod replicas or instance counts
- Security groups or firewall rules (too detailed)
- Internal service mesh
- DNS or routing policies

## Key Contracts

- User traffic → Load Balancer (SSL termination)
- Load Balancer → Compute Nodes (target routing)
- Compute Nodes ↔ Database (private subnet)

## Related Diagrams

- [compute-cluster.md](compute-cluster.md) — orchestration layer (pods, services)
```

## Using the diagrams Library

Install the library:

```bash
pip install diagrams graphviz
```

Create diagrams using AWS/Azure/GCP stencils:

```python
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import ALB, VPC
from diagrams.aws.compute import EC2
from diagrams.onprem.client import Users

with Diagram("Architecture", show=False):
    users = Users("Users")
    
    with Cluster("VPC"):
        lb = ALB("Load Balancer")
        
        with Cluster("Private Subnet"):
            servers = [EC2(f"App {i}") for i in range(1, 3)]
    
    users >> lb >> servers
```

## Best Practices

- **Simplicity over completeness**: Show critical path, not every detail
- **Clear labels**: Name resources clearly (load-balancer, database, etc.)
- **Consistent direction**: Use top-down (TB) or left-right (LR), not mixed
- **Update together**: When architecture changes, update the diagram and markdown together
- **Version in git**: Commit both `.py` scripts and generated `.png` images

## Commands

Generate all diagrams:

```bash
mkdir -p docs/architecture/output
python docs/architecture/*.py
```

Commit changes:

```bash
git add docs/architecture/
git commit -m "docs: update infrastructure topology diagram"
```
