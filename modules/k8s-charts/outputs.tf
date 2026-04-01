output "application_status" {
  description = "Map of release name to Helm release status."
  value       = { for key, value in helm_release.this : key => value.status }
}
