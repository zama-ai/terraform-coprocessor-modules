# ***************************************
#  Kubernetes ExternalName Service
#
#  Gives pods a stable in-cluster name for the replication group primary
#  endpoint: <name>.<namespace>.svc.cluster.local resolves to the AWS-generated
#  hostname, so client configuration survives a replication group replacement.
#
#  One Service per enabled namespace entry, keyed by namespace so adding or
#  removing one never re-creates the others. Each namespace resolves its own
#  name, annotations and labels: the k8s_service baseline merged with the
#  namespace's own values, which win per key. No baseline keys are injected, so
#  the caller keeps full control -- an annotation set on one namespace does not
#  appear on any other.
#
#  No port is declared: an ExternalName Service resolves to a CNAME and
#  kube-proxy ignores declared ports. Clients keep using elasticache.port.
# ***************************************
locals {
  k8s_external_name_services = (
    var.elasticache.enabled && var.elasticache.k8s_service.enabled
    ? {
      for namespace, config in var.elasticache.k8s_service.namespaces :
      namespace => {
        name        = coalesce(config.name, var.elasticache.k8s_service.name)
        annotations = merge(var.elasticache.k8s_service.annotations, config.annotations)
        labels      = merge(var.elasticache.k8s_service.labels, config.labels)
      } if config.enabled
    }
    : {}
  )
}

resource "kubernetes_service" "external_name" {
  for_each = local.k8s_external_name_services

  metadata {
    name        = each.value.name
    namespace   = each.key
    annotations = each.value.annotations
    labels      = each.value.labels
  }

  spec {
    type          = "ExternalName"
    external_name = split(":", module.elasticache[0].replication_group_primary_endpoint_address)[0]
  }
}
