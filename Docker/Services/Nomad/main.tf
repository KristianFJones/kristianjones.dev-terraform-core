terraform {
  required_providers {
    consul = {
      source = "hashicorp/consul"
      version = "2.12.0"
    }

    docker = {
      source = "kreuzwerker/docker"
      version = "2.15.0"
    }

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }

    time = {
      source = "hashicorp/time"
      version = "0.7.2"
    }
  }
}

data "docker_network" "meshSpineNet" {
  name = "meshSpineNet"
}

resource "docker_config" "NomadConfig" {
  name = "nomad-config-${replace(timestamp(), ":", ".")}"

  data = base64encode(
    templatefile("${path.module}/Configs/Nomad/Config.hcl",
      {
        LogLevel = var.LogLevel

        Consul = var.Consul
      }
    )
  )

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}

resource "docker_config" "NomadEntryScriptConfig" {
  name = "nomad-entryconfig-${replace(timestamp(), ":", ".")}"
  data = base64encode(file("${path.module}/Configs/Nomad/start.sh"))

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = true
  }
}



resource "docker_service" "Nomad" {
  name = "Nomad"

  task_spec {
    container_spec {
      image = "multani/nomad:${var.Version}"

      command = ["/start.sh"]

      #
      # TODO: Tweak this, Caddy, Prometheus, Loki, etc
      #
      env = {
        NODE_HOST = "{{.Node.Hostname}}Nomad"
      }

      hostname = "{{.Node.Hostname}}Nomad"

      # env = {
      #   CONSUL_BIND_INTERFACE = "eth0"
      #   CONSUL_CLIENT_INTERFACE = "eth0"
      #   CONSUL_HOST = "Consul{{.Task.Slot}}"
      # }

      # dir    = "/root"
      #user   = "1000"
      # groups = ["docker", "foogroup"]

      # privileges {
      #   se_linux_context {
      #     disable = true
      #     user    = "user-label"
      #     role    = "role-label"
      #     type    = "type-label"
      #     level   = "level-label"
      #   }
      # }

      # read_only = true

      mounts {
        target    = "/etc/timezone"
        source    = "/etc/timezone"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/etc/localtime"
        source    = "/etc/localtime"
        type      = "bind"
        read_only = true
      }

      mounts {
        target    = "/Data"
        source    = "{{.Node.Hostname}}nomad-data"
        type      = "volume"
      }

      #
      # Docker Configs
      # 

      #
      # Consul Configuration
      #
      configs {
        config_id   = docker_config.NomadConfig.id
        config_name = docker_config.NomadConfig.name

        file_name   = "/Config/Config.hcl"
      }

      configs {
        config_id   = docker_config.NomadEntryScriptConfig.id
        config_name = docker_config.NomadEntryScriptConfig.name

        file_name   = "/entry.sh"
        file_uid = "1000"
        file_mode = 7777
      }


      # hosts {
      #   host = "testhost"
      #   ip   = "10.0.1.0"
      # }


      # dns_config {
      #   nameservers = ["1.1.1.1", "1.0.0.1"]
      #   search      = ["kristianjones.dev"]
      #   options     = ["timeout:3"]
      # }

      #
      # Stolon Database Secrets
      #
      # healthcheck {
      #   test     = ["CMD", "curl", "-f", "http://localhost:8080/health"]
      #   interval = "5s"
      #   timeout  = "2s"
      #   retries  = 4
      # }
    }

    runtime      = "container"
    networks     = [data.docker_network.meshSpineNet.id]

    log_driver {
      name = "loki"

      options = {
        loki-url = "https://loki.kristianjones.dev:443/loki/api/v1/push"
      }
    }
  }

  mode {
    global = true
  }

  #
  # TODO: Finetune this
  # 
  update_config {
    parallelism       = 1
    delay             = "0s"
    failure_action    = "pause"
    monitor           = "0s"
    max_failure_ratio = "0.8"
    order             = "stop-first"
  }

  # rollback_config {
  #   parallelism       = 1
  #   delay             = "5ms"
  #   failure_action    = "pause"
  #   monitor           = "10h"
  #   max_failure_ratio = "0.9"
  #   order             = "stop-first"
  # }

  endpoint_spec {
    ports {
      name           = "srv"
      protocol       = "tcp"
      target_port    = "4646"
      published_port = "4646"
      publish_mode   = "host"
    }

    ports {
      name           = "rpc"
      protocol       = "tcp"
      target_port    = "4647"
      published_port = "4647"
      publish_mode   = "host"
    }

    ports {
      name           = "srv-tcp"
      protocol       = "tcp"
      target_port    = "4648"
      published_port = "4648"
      publish_mode   = "host"
    }

    ports {
      name           = "srv-udp"
      protocol       = "udp"
      target_port    = "4648"
      published_port = "4648"
      publish_mode   = "host"
    }
  }
}