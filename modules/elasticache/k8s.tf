# ***************************************
#  Kubernetes ExternalName Service
#
#  Gives pods a stable in-cluster name for the replication group primary
#  endpoint: <name>.<namespace>.svc.cluster.local resolves to the AWS-generated
#  hostname, so client configuration survives a replication group replacement.
#
#  One Service per namespace, keyed by namespace so adding or removing one
#  never re-creates the others. Annotations and labels are passed through
#  verbatim — no baseline keys are injected, so the caller keeps full control.
#
#  No port is declared: an ExternalName Service resolves to a CNAME and
#  kube-proxy ignores declared ports. Clients keep using elasticache.port.
# ***************************************
resource "kubernetes_service" "external_name" {
  for_each = (
    var.elasticache.enabled && var.elasticache.k8s_service.enabled
    ? toset(var.elasticache.k8s_service.namespaces)
    : toset([])
  )

  metadata {
    name        = var.elasticache.k8s_service.name
    namespace   = each.key
    annotations = var.elasticache.k8s_service.annotations
    labels      = var.elasticache.k8s_service.labels
  }

  spec {
    type          = "ExternalName"
    external_name = split(":", module.elasticache[0].replication_group_primary_endpoint_address)[0]
  }
}
