#!/usr/bin/env python3
"""Build checksum-pinned container tools with the fixed advisory-safe Go toolchain."""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import shutil
import subprocess
import tarfile
import tempfile

from package_apk import create_apk

HERE = Path(__file__).resolve().parent
PINS = json.loads((HERE / 'sources.json').read_text())
GO_VERSION = PINS['go_version']
X_NET_VERSION = PINS['x_net_version']
NATIVE_TAGS = 'grpcnotrace,libsqlite3,systemd,seccomp'
DESTINATIONS = {
    'docker-compose': '/usr/local/bin/docker-compose',
    'docker-buildx': '/usr/libexec/docker/cli-plugins/docker-buildx',
    **{name: f'/usr/bin/{name}' for name in ('containerd', 'ctr', 'containerd-shim-runc-v2')},
}
APK_DEPENDENCIES = {
    'buildah': ['containers-common', 'crun', 'fuse-overlayfs', 'merged-bin', 'netavark',
                'wolfi-baselayout'],
    'podman': ['conmon', 'containers-common', 'crun', 'netavark'],
    'skopeo': ['ca-certificates-bundle', 'containers-common'],
}


def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def extract_source(archive, expected, destination):
    """Verify before extracting and reject paths or links outside the source root."""
    if sha256(archive) != expected:
        raise ValueError(f'source checksum mismatch: {archive}')
    with tarfile.open(archive, 'r:gz') as source:
        members = source.getmembers()
        roots = set()
        for member in members:
            path = PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or not path.parts:
                raise ValueError(f'unsafe source archive path: {member.name}')
            roots.add(path.parts[0])
            if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
                raise ValueError(f'unsafe source archive entry: {member.name}')
            if member.issym() or member.islnk():
                target = (posixpath.join(posixpath.dirname(member.name), member.linkname)
                          if member.issym() else member.linkname)
                normalized = PurePosixPath(posixpath.normpath(target))
                if normalized.is_absolute() or normalized.parts[0] != path.parts[0]:
                    raise ValueError(f'unsafe source archive link: {member.name}')
        if len(roots) != 1:
            raise ValueError('source archive must have exactly one release root')
        destination.mkdir(parents=True)
        source.extractall(destination, filter='data')
    return destination / roots.pop()


def validate_go_metadata(metadata, *, static):
    """Check linked toolchain/dependencies from actual go version -m output."""
    if not metadata.splitlines() or metadata.splitlines()[0].split()[-1] != GO_VERSION:
        raise ValueError(f'binary was not built with {GO_VERSION}')
    if f'\tbuild\tCGO_ENABLED={0 if static else 1}' not in metadata.splitlines():
        raise ValueError('binary has incorrect CGO_ENABLED')
    x_net = False
    for line in metadata.splitlines()[1:]:
        fields = line.strip().split('\t')
        if fields[0] == 'dep':
            x_net = len(fields) > 2 and fields[1] == 'golang.org/x/net'
            if x_net and fields[2] != X_NET_VERSION:
                raise ValueError(f'binary has unpatched x/net: {fields[2]}')
        elif fields[0] == '=>' and x_net:
            raise ValueError('x/net replacement is not permitted')
        elif fields[0] != '=>':
            x_net = False


def run(arguments, *, cwd=None, env=None, capture=False):
    print('+ ' + ' '.join(map(str, arguments)), flush=True)
    return subprocess.run(list(map(str, arguments)), cwd=cwd, env=env, check=True,
                          text=True, stdout=subprocess.PIPE if capture else None).stdout


def build_binary(source, output, package, tags, ldflags, env, *, static, version=None):
    output.parent.mkdir(parents=True, exist_ok=True)
    run(['go', 'build', '-mod=mod', '-trimpath', '-buildvcs=false', '-tags', tags,
         '-ldflags', '-s -w ' + ldflags, '-o', output, package], cwd=source, env=env)
    metadata = run(['go', 'version', '-m', output], env=env, capture=True)
    validate_go_metadata(metadata, static=static)
    if version:
        arguments, expected = version
        actual = run([output, *arguments], env=env, capture=True)
        if expected not in actual:
            raise ValueError(f'incorrect command version for {output}: {actual}')
    return {'path': output.name, 'sha256': sha256(output), 'go_metadata': metadata}


def stage_podman_support(source, payload):
    """Mirror upstream install.bin/install.systemd without building documentation."""
    binary_dir = payload / 'usr/bin'
    (binary_dir / 'podmansh').symlink_to('podman')
    for kind in ('system', 'user'):
        units = payload / f'usr/lib/systemd/{kind}'
        units.mkdir(parents=True, exist_ok=True)
        for source_file in (source / 'contrib/systemd/system').iterdir():
            if not (source_file.name.endswith(('.service.in', '.timer', '.socket'))):
                continue
            name = source_file.name.removesuffix('.in')
            content = source_file.read_text().replace('@@PODMAN@@', '/usr/bin/podman')
            if kind == 'user' and name == 'podman-clean-transient.service':
                content = ''.join(line for line in content.splitlines(keepends=True)
                                  if not line.startswith(('Requires=', 'After=')))
            (units / name).write_text(content)
        generator_dir = payload / f'usr/lib/systemd/{kind}-generators'
        generator_dir.mkdir(parents=True, exist_ok=True)
        generator = 'podman-system-generator' if kind == 'system' else 'podman-user-generator'
        (generator_dir / generator).symlink_to('../../../libexec/podman/quadlet')
    user_unit = source / 'contrib/systemd/user/podman-user-wait-network-online.service'
    shutil.copyfile(user_unit, payload / 'usr/lib/systemd/user' / user_unit.name)
    tmpfiles = payload / 'usr/lib/tmpfiles.d'
    tmpfiles.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source / 'contrib/tmpfile/podman.conf', tmpfiles / 'podman.conf')


def elf_dependencies(metadata):
    """Read direct ELF NEEDED SONAMEs, including the empty static-binary case."""
    return {'so:' + soname for soname in re.findall(
        r'\(NEEDED\)\s+Shared library:\s+\[([^\]\s/]+)\]', metadata)}


def native_dependencies(binaries, initial, env):
    """Record direct ELF library contracts without executing the built binary."""
    dependencies = set(initial)
    for binary in binaries:
        dynamic = run(['readelf', '--dynamic', binary], env=dict(env, LC_ALL='C'), capture=True)
        dependencies.update(elf_dependencies(dynamic))
    return sorted(dependencies)


def build_bundle(output, wolfi=False, source_cache=None):
    if not hasattr(tarfile, 'data_filter'):
        raise RuntimeError('Source builder requires Python with tarfile.data_filter support')
    configuration = json.loads((HERE / 'sources.json').read_text())
    env = dict(os.environ, GOTOOLCHAIN='local', GOOS='linux', GOFLAGS='', CGO_ENABLED='0',
               GOMAXPROCS=os.environ.get('GOMAXPROCS', '2'))
    version = run(['go', 'env', 'GOVERSION'], env=env, capture=True).strip()
    if version != GO_VERSION:
        raise ValueError(f'fixed Go toolchain required: expected {GO_VERSION}, got {version}')
    architecture = run(['go', 'env', 'GOARCH'], env=env, capture=True).strip()
    apk_arch = {'amd64': 'x86_64', 'arm64': 'aarch64'}[architecture]
    output.mkdir(parents=True, exist_ok=True)
    (output / 'manifest.json').unlink(missing_ok=True)
    artifacts = []
    build_metadata = []
    selected = ['compose', 'buildx', 'containerd'] + (['buildah', 'podman', 'skopeo'] if wolfi else [])
    with tempfile.TemporaryDirectory(prefix='ror-container-tools-') as temporary:
        work = Path(temporary)
        for name in selected:
            spec = configuration['sources'][name]
            archive = work / (name + '.tar.gz')
            cached = Path(source_cache) / archive.name if source_cache else None
            if cached and cached.is_file():
                shutil.copyfile(cached, archive)
            else:
                run(['curl', '-fSL', '--connect-timeout', '15', '--max-time', '180',
                     '--output', archive, spec['url']])
            source = extract_source(archive, spec['sha256'], work / name)
            native = name in ('buildah', 'podman', 'skopeo')
            project_env = dict(env, CGO_ENABLED='1' if native else '0')
            run(['go', 'get', 'golang.org/x/net@' + X_NET_VERSION], cwd=source, env=project_env)
            project_version = spec['version']
            revision = spec['revision']
            if not native:
                prefix = output / 'bin'
                if name == 'compose':
                    commands = [('docker-compose', './cmd', 'e2e',
                                 f'-X github.com/docker/compose/v5/internal.Version=v{project_version}',
                                 (['version'], project_version))]
                elif name == 'buildx':
                    package = 'github.com/docker/buildx'
                    flags = f'-X {package}/version.Version=v{project_version} -X {package}/version.Revision={revision} -X {package}/version.Package={package}'
                    commands = [('docker-buildx', './cmd/buildx', '', flags, (['version'], project_version))]
                else:
                    package = 'github.com/containerd/containerd/v2'
                    flags = f'-X {package}/version.Version=v{project_version} -X {package}/version.Revision={revision} -X {package}/version.Package={package}'
                    commands = [(binary, './cmd/' + binary,
                                 'urfave_cli_no_docs,osusergo,netgo,static_build' + (',no_grpc' if 'shim' in binary else ''),
                                 flags, (['--version'], project_version))
                                for binary in ('containerd', 'ctr', 'containerd-shim-runc-v2')]
                for binary, package, tags, flags, check_version in commands:
                    result = build_binary(source, prefix / binary, package, tags, flags,
                                          project_env, static=True, version=check_version)
                    build_metadata.append(result)
                    artifacts.append({'path': f'bin/{binary}', 'sha256': result['sha256'],
                                      'destination': DESTINATIONS[binary]})
                continue
            payload = work / (name + '-payload')
            commands = []
            if name == 'podman':
                package = 'go.podman.io/podman/v6'
                flags = (f'-X {package}/libpod/define.gitCommit={revision} '
                         f'-X {package}/libpod/define.buildInfo=0 '
                         f'-X {package}/libpod/config._installPrefix=/usr '
                         f'-X {package}/libpod/config._etcDir=/etc '
                         f'-X {package}/pkg/systemd/quadlet._binDir=/usr/bin '
                         '-X go.podman.io/common/pkg/config.additionalHelperBinariesDir=/usr/libexec/podman')
                commands = [('usr/bin/podman', './cmd/podman', NATIVE_TAGS, flags),
                            ('usr/bin/podman-remote', './cmd/podman', NATIVE_TAGS + ',remote', flags),
                            ('usr/libexec/podman/rootlessport', './cmd/rootlessport', '', ''),
                            ('usr/libexec/podman/quadlet', './cmd/quadlet', NATIVE_TAGS, flags)]
            else:
                flags = f'-X main.GitCommit={revision} -X main.buildInfo=0' if name == 'buildah' else ''
                tags = 'containers_image_openpgp' if name == 'skopeo' else NATIVE_TAGS
                commands = [('usr/bin/' + name, './cmd/' + name, tags, flags)]
            binaries = []
            for relative, package, tags, flags in commands:
                binary = payload / relative
                check_version = (['--version'], project_version) if binary.name in ('podman', 'podman-remote', 'buildah', 'skopeo') else None
                result = build_binary(source, binary, package, tags, flags, project_env,
                                      static=False, version=check_version)
                build_metadata.append(result)
                binaries.append(binary)
            if name == 'podman':
                stage_podman_support(source, payload)
            provenance = payload / f'usr/share/ror/container-tools/{name}.json'
            provenance.parent.mkdir(parents=True, exist_ok=True)
            provenance.write_text(json.dumps({'source': spec, 'go_version': GO_VERSION,
                                              'x_net_version': X_NET_VERSION}, indent=2) + '\n')
            package_name = 'podman-6.0' if name == 'podman' else name
            apk_path = output / f'apk/{package_name}-{project_version}-r1000.apk'
            dependencies = native_dependencies(binaries, APK_DEPENDENCIES[name], project_env)
            package_version = project_version + '-r1000'
            aliases = (['podman', 'cmd:podman', 'cmd:podman-remote']
                       if name == 'podman' else ['cmd:' + name])
            create_apk(package_name, package_version, apk_arch, dependencies, payload, apk_path,
                       provides=[alias + '=' + package_version for alias in aliases])
            artifacts.append({'path': str(apk_path.relative_to(output)), 'sha256': sha256(apk_path)})
    shutil.copyfile(HERE / 'install.sh', output / 'install.sh')
    (output / 'install.sh').chmod(0o755)
    manifest = {'go_version': GO_VERSION, 'x_net_version': X_NET_VERSION,
                'sources': {name: configuration['sources'][name] for name in selected},
                'artifacts': artifacts, 'build_metadata': build_metadata}
    (output / 'manifest.json.tmp').write_text(json.dumps(manifest, indent=2) + '\n')
    (output / 'manifest.json.tmp').replace(output / 'manifest.json')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--wolfi', action='store_true')
    parser.add_argument('--source-cache', type=Path)
    arguments = parser.parse_args()
    build_bundle(arguments.output.resolve(), arguments.wolfi, arguments.source_cache)


if __name__ == '__main__':
    main()
