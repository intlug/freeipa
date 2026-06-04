# FreeIPA Presentation - INTLUG

MARP-based presentation and lab automation for introducing FreeIPA to the INTLUG group. Covers the problem of managing Linux identity without centralised tooling, the FreeIPA architecture and key capabilities, installation, client enrollment, and a live demo.

The rendered presentation is published at the GitHub Pages URL for this repository.

## Presentation

Built with [Marp](https://marp.app/). Node.js and npm are required.

```bash
npm install
```

| Command | Output |
|---------|--------|
| `npm run serve` | Live preview in browser |
| `npm run watch` | Rebuild HTML on save |
| `npm run build` | Build `slides.html` |
| `npm run build:pdf` | Build `slides.pdf` |
| `npm run build:pptx` | Build `slides.pptx` |

The GitHub Pages site is updated automatically whenever `slides.md` or `images/` changes are pushed to `main`.

## Demo Lab

Three Fedora Server VMs provisioned via Ansible and libvirt:

| VM | Hostname | IP |
|----|----------|----|
| FreeIPA server | ipaserver.intlug | 192.168.122.10 |
| Client 1 | ipaclient1.intlug | 192.168.122.11 |
| Client 2 | ipaclient2.intlug | 192.168.122.12 |

VMs are created with FreeIPA packages pre-installed but `ipa-server-install` and `ipa-client-install` are intentionally not run — those are executed during the live demo.

### Prerequisites

```bash
sudo dnf install -y libvirt-devel

python3 -m venv .venv
source .venv/bin/activate
pip install -r ansible/requirements.txt

.venv/bin/ansible-galaxy collection install -r ansible/requirements.yml
```

Place `demokey` and `demokey.pub` in `ansible/keys/` before running.

### Provision the lab

```bash
cd ansible
ansible-playbook provision-lab.yml
```

Re-run with `-e overwrite=yes` to tear down and recreate existing VMs:

```bash
ansible-playbook provision-lab.yml -e overwrite=yes
```

To run only the package installation step on already-running VMs:

```bash
ansible-playbook provision-lab.yml --tags install
```

### Tear down the lab

```bash
ansible-playbook teardown-vms.yml
```

### FreeIPA install (demo)

```bash
ansible-playbook site.yml
```

`site.yml` is reserved for the live demo walkthrough and is not run during provisioning.
