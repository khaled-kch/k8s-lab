terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "random_password" "password" {
  length = 16
}
resource "kubernetes_secret" "mongo-secret" {
  metadata {
    name      = "mongo-secret"
    namespace = var.tenant
  }

  type = "Opaque"

  data = {
    mongo-user     = "admin"
    mongo-password = random_password.password.result
  }
}
resource "kubernetes_config_map" "mongo-config" {
  metadata {
    name      = "mongo-config"
    namespace = var.tenant
  }

  data = {
    mongo-url = "mongo-service"
  }

}

# mongo
resource "kubernetes_deployment" "mongo-deployment" {
  metadata {
    name      = "mongo"
    namespace = var.tenant
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "mongo"
      }
    }
    template {
      metadata {
        labels = {
          app = "mongo"
        }
      }
      spec {
        container {
          image = "mongo:5.0"
          name  = "mongodb-container"
          port {
            container_port = 27017
          }
          env {
            name = "MONGO_INITDB_ROOT_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongo-secret.metadata[0].name
                key  = "mongo-user"
              }
            }
          }
          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongo-secret.metadata[0].name
                key  = "mongo-password"
              }
            }
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "mongo-service" {
  metadata {
    name      = "mongo-service"
    namespace = var.tenant
  }
  spec {
    selector = {
      app = kubernetes_deployment.mongo-deployment.spec.0.template.0.metadata.0.labels.app
    }
    port {
      port        = 27017
      target_port = 27017
    }

  }
}

# webapp
resource "kubernetes_deployment" "webapp-deployment" {
  metadata {
    name      = "webapp"
    namespace = var.tenant
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "webapp"
      }
    }
    template {
      metadata {
        labels = {
          app = "webapp"
        }
      }
      spec {
        container {
          image = "nanajanashia/k8s-demo-app:v1.0"
          name  = "webapp-container"
          port {
            container_port = 27017
          }
          env {
            name = "USER_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongo-secret.metadata[0].name
                key  = "mongo-user"
              }
            }
          }
          env {
            name = "USER_PWD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongo-secret.metadata[0].name
                key  = "mongo-password"
              }
            }
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "webapp-service" {
  metadata {
    name      = "webapp-service"
    namespace = var.tenant
  }
  spec {
    type = "NodePort"
    selector = {
      app = kubernetes_deployment.webapp-deployment.spec.0.template.0.metadata.0.labels.app
    }
    port {
      port        = 3000
      target_port = 3000
      node_port   = 30100
    }

  }
}

