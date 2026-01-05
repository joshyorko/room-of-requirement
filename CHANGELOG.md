# Changelog

## [1.3.3](https://github.com/joshyorko/room-of-requirement/compare/v1.3.2...v1.3.3) (2026-01-05)


### 🐛 Bug Fixes

* Update Brewfile paths for persistence and improve fallback logic in justfile ([0fae8b1](https://github.com/joshyorko/room-of-requirement/commit/0fae8b1d206738e61b126dc8f7dc71c837e0c1aa))

## [1.3.2](https://github.com/joshyorko/room-of-requirement/compare/v1.3.1...v1.3.2) (2026-01-05)


### 🐛 Bug Fixes

* Switch to root user for system operations and update packages to address security vulnerabilities ([b42ebbb](https://github.com/joshyorko/room-of-requirement/commit/b42ebbbbebc2ecfda52d5fc27ebb257578f8219f))
* Update SLSA generator reference to use semantic version tag and adjust allowlist configuration ([2b357f0](https://github.com/joshyorko/room-of-requirement/commit/2b357f055f4b7ee61561738e0178cbbb12804d2f))

## [1.3.1](https://github.com/joshyorko/room-of-requirement/compare/v1.3.0...v1.3.1) (2026-01-05)


### 🐛 Bug Fixes

* Remove unused subproject reference ([6f6a89c](https://github.com/joshyorko/room-of-requirement/commit/6f6a89c5b765a3ee5d88f3f9387fb625b156587e))
* Update Homebrew environment variables and PATH for improved tool accessibility ([f639230](https://github.com/joshyorko/room-of-requirement/commit/f6392301581c737ee4af65b22a5ea1697b7f2408))
* Update Playwright installation instructions and remove obsolete commands ([71c115e](https://github.com/joshyorko/room-of-requirement/commit/71c115e844785c00b1bafccd9ba5bad2f242bee2))

## [1.3.0](https://github.com/joshyorko/room-of-requirement/compare/v1.2.2...v1.3.0) (2026-01-03)


### ✨ Features

* Add CodeQL workflow for security vulnerability scanning and update Dockerfile for npm and package security ([9792dae](https://github.com/joshyorko/room-of-requirement/commit/9792dae2bc5d730e4922537c04ed5268032545ac))
* Update GitHub Actions workflows and maintenance scripts for improved version pinning and SHA handling ([cbbe87a](https://github.com/joshyorko/room-of-requirement/commit/cbbe87a61ea11a1dc5817b98acc33bbe4161f99e))


### 🐛 Bug Fixes

* Add vulnerability ignore rules for npm tar package and BusyBox ([173765d](https://github.com/joshyorko/room-of-requirement/commit/173765d19d99f0d9fb7793798a7c08448eac402e))
* Refactor output handling to use heredoc for multi-line JSON in build process ([6e934c1](https://github.com/joshyorko/room-of-requirement/commit/6e934c1056b0e02f1aea5cf0baeaa1f5dbca8396))
* Update build-image workflow to trigger on merged PRs and refine path conditions ([554c7c9](https://github.com/joshyorko/room-of-requirement/commit/554c7c9d2f1ba2ba4dd11f9454c0bc40fb73e090))
* Update CodeQL workflow to scan Python code and GitHub Actions ([35e72b1](https://github.com/joshyorko/room-of-requirement/commit/35e72b10b6e6018eb81eb7c21ee0f2eea80a9517))
* Update GitHub Actions cleanup action version and add it to allowlist ([5ba1c83](https://github.com/joshyorko/room-of-requirement/commit/5ba1c8361955affcc1604c5116efdde713fb8660))
* Update GitHub Actions workflows to pin action versions and improve SHA handling ([cab092c](https://github.com/joshyorko/room-of-requirement/commit/cab092c71f03e269315dcd1e4d025710032d8609))

## [1.2.2](https://github.com/joshyorko/room-of-requirement/compare/v1.2.1...v1.2.2) (2026-01-03)


### 🐛 Bug Fixes

* Update RCC version to v18.13.0 in maintenance workflow ([dfafdaa](https://github.com/joshyorko/room-of-requirement/commit/dfafdaa5bb5f9158827fce9052659ccd30b0fead))

## [1.2.1](https://github.com/joshyorko/room-of-requirement/compare/v1.2.0...v1.2.1) (2026-01-03)


### 🐛 Bug Fixes

* Skip VS Code gcompat installation on Wolfi OS ([#96](https://github.com/joshyorko/room-of-requirement/issues/96)) ([f559507](https://github.com/joshyorko/room-of-requirement/commit/f55950706dec65e542e69fb2ae345d397acb822c))

## [1.2.0](https://github.com/joshyorko/room-of-requirement/compare/v1.1.2...v1.2.0) (2026-01-02)


### ✨ Features

* add bash configuration and enhance starship prompt for cloud integration ([bdb7d60](https://github.com/joshyorko/room-of-requirement/commit/bdb7d6016f33ff27e38e72038d6e971edc697bd5))


### 🐛 Bug Fixes

* update Dockerfile dependencies for Playwright and enhance justfile output ([981f4e5](https://github.com/joshyorko/room-of-requirement/commit/981f4e5c4c08b3a7ea0dc5a4ee944a7cc6483600))


### ♻️ Refactoring

* update devcontainer feature description and remove unused options ([01f9893](https://github.com/joshyorko/room-of-requirement/commit/01f989363b3d510e8475580e0515ae4780fb22b3))

## [1.1.2](https://github.com/joshyorko/room-of-requirement/compare/v1.1.1...v1.1.2) (2026-01-02)


### ♻️ Refactoring

* update CI workflows to improve DevContainer image build triggers and remove cicd.yaml ([d9dfb3a](https://github.com/joshyorko/room-of-requirement/commit/d9dfb3a0650e1f56c889b13288f2c2a281a2e8d4))

## [1.1.1](https://github.com/joshyorko/room-of-requirement/compare/v1.1.0...v1.1.1) (2026-01-02)


### ♻️ Refactoring

* remove direct push trigger from build-image workflow to prevent duplicate builds ([d5fed99](https://github.com/joshyorko/room-of-requirement/commit/d5fed999f66d9ae7c2e3a5fcd50bcf202352411e))
* update build-image workflow to trigger on specific paths to prevent duplicate builds ([7e1c8a4](https://github.com/joshyorko/room-of-requirement/commit/7e1c8a4c23f3d1700f4a304a8cff589cf7276636))

## [1.1.0](https://github.com/joshyorko/room-of-requirement/compare/v1.0.1...v1.1.0) (2026-01-02)


### ✨ Features

* Add Brewfiles for CLI tools, cloud tools, data tools, development tools, Kubernetes tools, and security tools ([0411e07](https://github.com/joshyorko/room-of-requirement/commit/0411e073f71ff6257ffcc71df115e50c92f49273))
* add k3d to Brewfile and update first-run notice with new environment details ([7ed370a](https://github.com/joshyorko/room-of-requirement/commit/7ed370a8e5af64bff1ea703c1a8d0db283252b7d))
* Disable VS Code shell integration to resolve conflicts with Starship prompt ([e63639f](https://github.com/joshyorko/room-of-requirement/commit/e63639f87e88b8cbea1990c7489b7bcf17e5aa85))
* enhance DevContainer setup with zsh plugins and improved Brewfile handling ([73c3197](https://github.com/joshyorko/room-of-requirement/commit/73c3197425fe718e2ec763ae97a04b23dec21818))
* Enhance Dockerfile and justfile for improved Playwright support and Brewfile management ([7ad1b04](https://github.com/joshyorko/room-of-requirement/commit/7ad1b0438a596be82d8718d9a9799462738d632e))
* Re-add bbrew to Brewfile (gcc now available for source builds) ([ed1b454](https://github.com/joshyorko/room-of-requirement/commit/ed1b4541f0e299ca30716f1a585b2d6a62a4fd66))
* Replace oh-my-zsh with zinit for modern zsh plugin management ([6aa92cb](https://github.com/joshyorko/room-of-requirement/commit/6aa92cb138be25a7f0862ef269efd14fe76f59f5))
* Update Dockerfile to refine Playwright dependencies for Wolfi compatibility ([72aa796](https://github.com/joshyorko/room-of-requirement/commit/72aa796eff99e2c5c165e98cd6b5591110071007))
* Update Homebrew installation and configuration for improved usability ([2af944b](https://github.com/joshyorko/room-of-requirement/commit/2af944b635b3747e64491c4eb1939b10bfef03b8))
* Update zsh history configuration and add directory-based history management ([46f9a65](https://github.com/joshyorko/room-of-requirement/commit/46f9a65d37e9c8a36dc139c4bf130bd66dbb8743))


### 🐛 Bug Fixes

* add explicit openssl package for CLI binary ([eb7274d](https://github.com/joshyorko/room-of-requirement/commit/eb7274d563b4fd932895297ea09b8baf1f4520bf))
* Docker permissions, Brewfile errors, and enable source builds ([c4ce609](https://github.com/joshyorko/room-of-requirement/commit/c4ce609400a841e76e4fe5a5d74f7602d0606baf))
* enhance Docker-in-Docker installation script with additional packages and improved cgroup v2 handling ([b8342f5](https://github.com/joshyorko/room-of-requirement/commit/b8342f538893a13fec1d78fa6a9ca8a0fc3f7d07))
* remove redundant version checks for git and mount in Dockerfile ([17f4b1c](https://github.com/joshyorko/room-of-requirement/commit/17f4b1ccbf4ccef7f1b015a9e88530bdca1eedff))
* remove unsupported config input from anchore/scan-action ([f9d0fdf](https://github.com/joshyorko/room-of-requirement/commit/f9d0fdf1bc127fc7d5cf2a2873e6745134cc5fab))
* streamline Dockerfile and post-create script by removing redundant flags and improving error handling ([95d0ff3](https://github.com/joshyorko/room-of-requirement/commit/95d0ff36311efa515d12aa19eccca9f49acd2628))
* use literal image name in SLSA workflow call ([9b33074](https://github.com/joshyorko/room-of-requirement/commit/9b330741ddbca9845ce4d477312b20792d6e42a4))

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
