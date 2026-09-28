# Infrastructure Testing

Test infrastructure changes before applying them to production. This project uses integration tests to validate infrastructure.

## Test Organization

```
tests/
├── terraform_test.py          # Integration tests
└── fixtures/                  # Test data and fixtures
```

## Testing Approach

Tests use Terratest (Python integration tests) to:

1. **Provision infrastructure** using `terraform apply`
2. **Validate the results** (resource exists, has correct properties)
3. **Destroy resources** using `terraform destroy`

Each test is independent and can run in any order.

## Running Tests

```bash
cd terraform
terraform init
cd ../tests
pytest terraform_test.py -v
```

## Writing a Test

```python
import subprocess
import pytest

def test_vpc_created():
    """Verify VPC is created with correct CIDR block"""
    
    # Apply terraform with test variables
    result = subprocess.run(
        ["terraform", "apply", "-auto-approve", "-var", "vpc_cidr_block=10.0.0.0/16"],
        cwd="terraform",
        capture_output=True,
        text=True
    )
    assert result.returncode == 0, f"Terraform apply failed: {result.stderr}"
    
    # Get outputs and validate
    output = subprocess.run(
        ["terraform", "output", "-json"],
        cwd="terraform",
        capture_output=True,
        text=True
    )
    outputs = json.loads(output.stdout)
    assert outputs["vpc_id"]["value"] is not None
    
    # Cleanup
    subprocess.run(["terraform", "destroy", "-auto-approve"], cwd="terraform")
```

## What to Test

- **Resource creation**: Does the resource get created?
- **Properties**: Does it have the expected configuration?
- **Dependencies**: Do dependent resources connect properly?
- **Destructibility**: Can the infrastructure be destroyed cleanly?

Avoid testing:
- Detailed provider behavior (assume providers work)
- Business logic (not applicable to IaC)
- Trivial properties that don't affect functionality
