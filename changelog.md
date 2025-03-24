
---
### 1.0.1
*March 23th 2025*

- Use community package repository (pkgs.k8s.io). (Google ones are dead)
- Use GitHub to determine latest version (required due to the above).
- Add validation for `--k8s-version` parameter.
- Reorder steps, placing prerequisite config between package install and `kubeadm [init|join]`. Also place splash and sudo checks at top of script.
- Add script version to banner.
- Change CIDR generator code so it doesn't break syntax highlighting.
- Added `--k8s-kubeadm-options` parameter.
- Added `set -euo pipefail` to terminate script on failure.
- Update documentation.
- Added 1 second sleep before `apt-get update` due to observed file locks / race conditions.
- Added changelog.md.

Tested with:

- Ubuntu Server 24.04
- Kubernetes Version 1.32.3
