# Changelog

## [1.0.1](https://github.com/joshyorko/room-of-requirement/compare/v1.0.0...v1.0.1) (2026-01-02)


### 🐛 Bug Fixes

* add ENTRYPOINT for docker-init.sh and install Oh My Zsh ([289ce98](https://github.com/joshyorko/room-of-requirement/commit/289ce98cffe7250d0032b4ca452cf199d5c27051))
* update Dockerfile entrypoint and devcontainer configuration for improved Docker-in-Docker support ([bb045ff](https://github.com/joshyorko/room-of-requirement/commit/bb045ff1135429274fbd0ab80e10b076354946b4))

## 1.0.0 (2026-01-02)


### ✨ Features

* add AWS CLI installation to Dockerfile and update allowlists ([ec79797](https://github.com/joshyorko/room-of-requirement/commit/ec79797648380ff3670b33a8f9d399ca968a67a3))
* add container-use version and SHA256 to Dockerfile and downloads.json ([1d834ed](https://github.com/joshyorko/room-of-requirement/commit/1d834edfb2491f59df0186b33e8162a488a51006))
* add Dagger version and SHA256 to Dockerfile and downloads.json ([2ff0808](https://github.com/joshyorko/room-of-requirement/commit/2ff08089a4769c464f4e1c7a1310033aebf6f2cb))
* add hauler installation to Dockerfile and update downloads.json allowlist ([ea95c0e](https://github.com/joshyorko/room-of-requirement/commit/ea95c0e072b69981122b5d9288b9be87bc46b07c))
* add npm support for fetching package versions ([c6d9823](https://github.com/joshyorko/room-of-requirement/commit/c6d98235148c2d30593f15410213cc32f06883b7))
* **maintenance-robot:** add PyPI support for downloads updater ([a9af859](https://github.com/joshyorko/room-of-requirement/commit/a9af859ddfc28d4292fdc5a2aa17b7bae279c5c1))


### 🐛 Bug Fixes

* add --silent flag to RCC run command in maintenance workflow ([bb784f3](https://github.com/joshyorko/room-of-requirement/commit/bb784f3ff982463e743090376598fc0c69f0c0c5))
* add GITHUB_TOKEN environment variable for maintenance robot execution ([b7cd85b](https://github.com/joshyorko/room-of-requirement/commit/b7cd85bc1826631b773103d15b060dd7ac8f3e16))
* Add security-events permission for SARIF upload ([9843a0c](https://github.com/joshyorko/room-of-requirement/commit/9843a0c730c66f3f95bd7880f73523fe9088ccce))
* Add workflow_call triggers for reusable workflows ([b654c0d](https://github.com/joshyorko/room-of-requirement/commit/b654c0d1944d6bd79e358bceb7b9aecd75caab97))
* Bake post-create.sh into image for pre-built image usage ([830f21e](https://github.com/joshyorko/room-of-requirement/commit/830f21e2250898647186128fa633d231ce628422))
* Bump nushell and zoxide versions to 1.0.1 ([39f19f9](https://github.com/joshyorko/room-of-requirement/commit/39f19f997cf2c30a1ab502130c0650e35edb5ad2))
* Capture digest from docker push output and update CodeQL to v4 ([e3c3132](https://github.com/joshyorko/room-of-requirement/commit/e3c3132cee0c675781c3b99e97b695e8bb5e270b))
* **ci:** use only tag names for imageTag in devcontainers/ci step ([7ebf09e](https://github.com/joshyorko/room-of-requirement/commit/7ebf09edc16807d1e3da09c2f76633931ceae021))
* enhance Dockerfile and CI workflow for security and validation improvements ([c74b00b](https://github.com/joshyorko/room-of-requirement/commit/c74b00ba44e0ee099699721ee228b57f339377c3))
* Make postCreateCommand tolerate missing script for pre-built images ([b10dc6f](https://github.com/joshyorko/room-of-requirement/commit/b10dc6f5912c4eb481af4ae454ffa24a95624d39))
* Publish image to ghcr.io/OWNER/ror instead of ghcr.io/OWNER/REPO/ror ([785e987](https://github.com/joshyorko/room-of-requirement/commit/785e987509d7f38668fbde586c2b937cbc820389))
* remove .gitconfig bind mount - causes directory issue on Kubernetes ([2bf9c0b](https://github.com/joshyorko/room-of-requirement/commit/2bf9c0b0ba13c9594be0f27677e9503a14bc6b32))
* Remove comments from devcontainer.json ([86d1aa4](https://github.com/joshyorko/room-of-requirement/commit/86d1aa41b7b04cd89a9768625c915f3fee2d970e))
* Remove redundant multiline tags output from build step ([293149b](https://github.com/joshyorko/room-of-requirement/commit/293149b049b388c23ceacf2461c42d2f92d3fa03))
* remove redundant postStartCommand - feature entrypoint handles docker init ([b851924](https://github.com/joshyorko/room-of-requirement/commit/b851924b3c4517e0b8dfc6626ab5904f2d0d40e8))
* set CodeQL language to yaml instead of auto ([8be586b](https://github.com/joshyorko/room-of-requirement/commit/8be586b6459742da3f7ea5398bd104485585810b))
* Simplify release.yml to avoid permission issues ([58e2f07](https://github.com/joshyorko/room-of-requirement/commit/58e2f07f137598fa6fc795d6612b9454de727eef))
* Update lockfile to nushell/zoxide v1.0.1 ([a4f8b0b](https://github.com/joshyorko/room-of-requirement/commit/a4f8b0bd27180177ad4542e681ddd25b886981f7))
* update maintainer email in Dockerfile for accuracy ([5f5a607](https://github.com/joshyorko/room-of-requirement/commit/5f5a607db0cce1baede7177f4e3864bec559c87b))
* update Python and Node.js versions in conda.yaml ([9d70282](https://github.com/joshyorko/room-of-requirement/commit/9d70282c7c4e1bf8ec466216b71b5c9c31d30aba))
* update RCC version to v18.12.1 in maintenance workflow ([2351be2](https://github.com/joshyorko/room-of-requirement/commit/2351be2849184f1bd2decec093866d3bcdb18fc8))
* Use compact JSON output for GITHUB_OUTPUT ([ed50981](https://github.com/joshyorko/room-of-requirement/commit/ed50981be030c002c30fb4042dbabfbac534fcdb))
* Use direct download for nushell instead of homebrew ([2008a93](https://github.com/joshyorko/room-of-requirement/commit/2008a936f522d4007921ab6db7acb712eb168c12))
* Use direct download for zoxide instead of homebrew ([fbfc63a](https://github.com/joshyorko/room-of-requirement/commit/fbfc63ae08b8a4f9c0a2b10dcfb5795dbacc66f9))


### 📚 Documentation

* add CLAUDE.md for project guidance and maintenance instructions ([757f818](https://github.com/joshyorko/room-of-requirement/commit/757f818fc6e48fe3593d78dd30eedc727d279ecf))
* Add container-use to user-facing documentation ([b2077ee](https://github.com/joshyorko/room-of-requirement/commit/b2077ee93053189340a11b3fb0702addcf51c51a))
* add repository guidelines for project structure, commands, and best practices ([0283a51](https://github.com/joshyorko/room-of-requirement/commit/0283a516435c9997fe957b7db216f43c73089e13))
