# Ghostty support provenance

The vendored assets come from Ghostty tag `v1.3.1`.

- Annotated tag object: `22efb0be2bbea73e5339f5426fa3b20edabcaa11`
- Resolved commit: `332b2aefc6e72d363aa93ab6ecfc86eeeeb5ed28`
- Upstream source: https://github.com/ghostty-org/ghostty/tree/v1.3.1

The terminfo source was reconstructed with `infocmp -x xterm-ghostty` from
Bluefin's installed Ghostty 1.3.1 terminfo database; it retains the upstream
`xterm-ghostty` and `ghostty` lookup names and extended capabilities.

Asset SHA-256 values:

- `terminfo/xterm-ghostty.terminfo`: `64c39c554279ae6a17ee7279d48732871424ee45b51907938957149cce19f214`
- `shell-integration/bash/ghostty.bash`: `b255abb65ee23aafd2329a39580318c038ae4edd217140b4440237a649f8fe95`
- `shell-integration/bash/bash-preexec.sh`: `24d8b80577fa0e630e89a6b0284205323df568559ea85b4168074714832996e4`
- `shell-integration/zsh/ghostty-integration`: `91df01faa8e8ba2f5acf8a6a1aa6fb1aee0d5974b0c9ada8255ae4812fc8212d`
- `LICENSE`: `386211873e5b7a02f663ae4d7adf96285999f91608f8f9f31fecfd0f4095e6f1`

The Ghostty project license is retained in `LICENSE`. The Bash and Zsh
integration files retain their upstream GPLv3 and Kitty attribution headers.
The full GPLv3 text is included in `COPYING.GPLv3` (from Debian's
`/usr/share/common-licenses/GPL-3`). `Ghostty` is the terminfo description;
`xterm-ghostty` and `ghostty` are the lookup names.
