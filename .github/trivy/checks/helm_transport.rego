# METADATA
# title: Helm chart downloads must use secure transport
# description: Helm releases must not disable TLS verification or use HTTP chart repositories.
# scope: package
# schemas:
#   - input: schema["terraform-raw"]
# custom:
#   id: ZAMA-HELM-001
#   severity: HIGH
#   short_code: helm-secure-transport
#   recommended_actions: Use HTTPS or OCI repositories and keep TLS verification enabled.
#   input:
#     selector:
#       - type: terraform-raw
package user.helm.secure_transport

import rego.v1

deny contains res if {
    some module in input.modules
    some block in module.blocks
    block.kind == "resource"
    block.type == "helm_release"
    attr := block.attributes.insecure_skip_tls_verify
    attr.value == true
    res := result.new("Helm release disables TLS verification", attr)
}

deny contains res if {
    some module in input.modules
    some block in module.blocks
    block.kind == "resource"
    block.type == "helm_release"
    attr := block.attributes.repository
    startswith(lower(attr.value), "http://")
    res := result.new("Helm chart repository uses unencrypted HTTP", attr)
}
