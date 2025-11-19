resource "kubernetes_manifest" "cluster_autoscaler_rbac" {
  manifest = yamldecode(file("${path.module}/clusterautoscaler.yml"))
}

resource "kubernetes_manifest" "cluster_autoscaler_deployment" {
  manifest = yamldecode(file("${path.module}/test.yml"))
}
