variable "REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAME" {
  default = "joshyorko/room-of-requirement"
}

group "default" {
  targets = [
    "ubuntu-noble",
    "debian-trixie",
    "wolfi"
  ]
}

group "codespaces" {
  targets = [
    "ubuntu-noble-dind"
  ]
}

target "ubuntu-noble" {
  context = "."
  dockerfile = "src/ubuntu-noble/.devcontainer/Dockerfile"
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:ubuntu-noble",
    "${REGISTRY}/${IMAGE_NAME}:latest"
  ]
}

target "ubuntu-noble-dind" {
  inherits = ["ubuntu-noble"]
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:ubuntu-noble-dind",
    "${REGISTRY}/${IMAGE_NAME}:codespaces"
  ]
}

target "debian-trixie" {
  context = "."
  dockerfile = "src/debian-trixie/.devcontainer/Dockerfile"
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:debian-trixie"
  ]
}

target "wolfi" {
  context = "."
  dockerfile = "src/wolfi/.devcontainer/Dockerfile"
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:wolfi",
    "${REGISTRY}/${IMAGE_NAME}:secure"
  ]
}
