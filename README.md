[![Open in DevPod!](https://devpod.sh/assets/open-in-devpod.svg)](https://devpod.sh/open#https://github.com/joshyorko/room-of-requirement)

## Adding qemu-user-static Support for Cross-Arch Builds

To enable cross-architecture builds using QEMU, follow these steps:

1. Install QEMU and qemu-user-static on your local machine:
   ```sh
   sudo apt-get update
   sudo apt-get install -y qemu qemu-user-static
   ```

2. Register QEMU binary formats:
   ```sh
   docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
   ```

3. Verify that QEMU is registered:
   ```sh
   docker run --rm -t arm64v8/ubuntu uname -m
   ```

   You should see `aarch64` as the output, indicating that QEMU is correctly set up for ARM64 emulation.

4. Proceed with your Docker build commands as usual. The QEMU setup will allow you to build images for different architectures seamlessly.
