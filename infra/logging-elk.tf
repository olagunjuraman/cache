resource "kubernetes_namespace" "logging" {
  provider = kubernetes.gke
  metadata {
    name = "logging"
  }
  depends_on = [google_container_node_pool.primary_nodes]
}

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  version    = "8.5.1"
  namespace  = kubernetes_namespace.logging.metadata[0].name

  set {
    name  = "replicas"
    value = "1"
  }
  set {
    name = "minimumMasterNodes"
    value = "1"
  }
  set {
    name  = "persistence.enabled"
    value = "false"
  }
  set {
    name = "resources.requests.memory"
    value = "1Gi"
  }
    set {
    name = "resources.limits.memory"
    value = "2Gi"
  }

  depends_on = [kubernetes_namespace.logging]
}

resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  version    = "8.5.1"
  namespace  = kubernetes_namespace.logging.metadata[0].name

  set {
    name  = "elasticsearchHosts"
    value = "http://${helm_release.elasticsearch.name}-master.${kubernetes_namespace.logging.metadata[0].name}.svc.cluster.local:9200"
  }

  set {
    name = "service.type"
    value = "LoadBalancer"
  }
   set {
    name = "service.port"
    value = "80"
  }
   set {
    name = "service.targetPort"
    value = "5601"
  }

  depends_on = [helm_release.elasticsearch]
}

resource "helm_release" "logstash" {
  name       = "logstash"
  repository = "https://helm.elastic.co"
  chart      = "logstash"
  version    = "8.5.1"
  namespace  = kubernetes_namespace.logging.metadata[0].name

  values = [
    <<YAML
replicas: 1
logstashPipeline:
  logstash.conf: |
    input {
      forward {
        port => 24224
      }
    }
    filter {
      if [log] =~ /^{.*}$/ {
         json {
           source => "log"
           target => "parsed_log"
         }
      }
    }
    output {
      elasticsearch {
        hosts => ["http://${helm_release.elasticsearch.name}-master.${kubernetes_namespace.logging.metadata[0].name}.svc.cluster.local:9200"]
        index => "logstash-%%{+YYYY.MM.dd}"
      }
    }
YAML
  ]

  depends_on = [helm_release.elasticsearch]
}

resource "helm_release" "fluentbit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = "0.40.0"
  namespace  = kubernetes_namespace.logging.metadata[0].name

  values = [
    <<YAML
config:
  inputs: |
    [INPUT]
        Name                tail
        Tag                 kube.*
        Path                /var/log/containers/*.log
        Parser              docker
        DB                  /var/log/flb_kube.db
        Mem_Buf_Limit       5MB
        Skip_Long_Lines     On
        Refresh_Interval    10
        Docker_Mode         On

  outputs: |
    [OUTPUT]
        Name          forward
        Match         *
        Host          ${helm_release.logstash.name}-logstash.${kubernetes_namespace.logging.metadata[0].name}.svc.cluster.local
        Port          24224
        Retry_Limit   False

  parsers: |
    [PARSER]
        Name        docker
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z

rbac:
  create: true
serviceAccount:
  create: true

kind: DaemonSet
YAML
  ]

  depends_on = [helm_release.logstash]
}

resource "kubernetes_service_v1" "kibana_lb" {
  provider = kubernetes.gke
  metadata {
    name      = "${helm_release.kibana.name}-kibana-lb-external" 
    namespace = kubernetes_namespace.logging.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "kibana"
      "app.kubernetes.io/instance" = helm_release.kibana.name
      "created-by" = "terraform"
    }
  }
  spec {
    selector = {
      "app" = "kibana"
      "release" = helm_release.kibana.name
    }
    port {
      port        = 80
      target_port = 5601
      protocol    = "TCP"
    }
    type = "LoadBalancer"
  }
  depends_on = [helm_release.kibana]
}