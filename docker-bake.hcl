# Raw Dockerfile debugging only. Published images use Dev Container Features.
variable "IMAGE_NAME" {
  default = "ror-debug"
}

group "default" {
  targets = [
    "ubuntu-noble",
    "debian-trixie",
    "wolfi"
  ]
}

target "ubuntu-noble" {
  context = "."
  dockerfile = "src/ubuntu-noble/.devcontainer/Dockerfile"
  tags = [
    "${IMAGE_NAME}:ubuntu-noble"
  ]
}

target "debian-trixie" {
  context = "."
  dockerfile = "src/debian-trixie/.devcontainer/Dockerfile"
  tags = [
    "${IMAGE_NAME}:debian-trixie"
  ]
}

target "wolfi" {
  context = "."
  dockerfile = "src/wolfi/.devcontainer/Dockerfile"
  tags = [
    "${IMAGE_NAME}:wolfi"
  ]
}
