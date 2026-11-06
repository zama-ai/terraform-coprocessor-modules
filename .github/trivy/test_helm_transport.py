"""Exercise the custom check through Trivy's Terraform parser and Rego engine."""

import json
from pathlib import Path
import subprocess
import tempfile


def main():
    cases = [
        ('repository = "https://charts.example.com"', 0),
        ('repository = "oci://registry.example.com/charts"', 0),
        ('repository = "http://charts.example.com"', 1),
        ('insecure_skip_tls_verify = true', 1),
        ('insecure_skip_tls_verify = false', 0),
    ]
    for attributes, expected in cases:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "main.tf").write_text(
                'resource "helm_release" "test" {\n'
                '  name = "test"\n  chart = "test"\n'
                f'  {attributes}\n'
                '}\n'
            )
            report = path / "results.json"
            subprocess.run(
                [
                    "trivy", "config", "--quiet",
                    "--config", ".github/trivy/config.yml",
                    "--misconfig-scanners", "terraform",
                    "--format", "json", "--output", str(report),
                    "--exit-code", "0", str(path),
                ],
                check=True,
            )
            results = json.loads(report.read_text()).get("Results", [])
            findings = [
                finding
                for result in results
                for finding in result.get("Misconfigurations", [])
                if finding["ID"] == "ZAMA-HELM-001"
            ]
            if len(findings) != expected:
                raise AssertionError(
                    f"{attributes}: expected {expected} findings, got {len(findings)}"
                )
            print(f"PASS: {attributes}")


if __name__ == "__main__":
    main()
