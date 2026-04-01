resource "helm_release" "this" {
  for_each = var.applications

  name             = each.key
  repository       = each.value.repository
  chart            = each.value.chart
  version          = each.value.version
  namespace        = each.value.namespace
  create_namespace = each.value.create_namespace
  atomic           = each.value.atomic
  wait             = each.value.wait
  timeout          = each.value.timeout

  # Only pass values when non-empty; avoids feeding an empty YAML string to Helm.
  values = each.value.values != "" ? [each.value.values] : []

  set = [for key, value in each.value.set : { name = key, value = value }]
}
