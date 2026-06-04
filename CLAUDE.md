# FreeIPA presentation

This is a MARP project creating a presentation on FreeIPA for the INTLUG group. The purpose is to introduce FreeIPA, cover how to install FreeIPA and setting up clients.

## Presentation Outline

0. Welcome and INTLUG "promo" page
1. The problem: Linux auth without FreeIPA
   - passwd/shadow files, manual account sync across machines
   - No centralized sudo or HBAC, no PKI, no DNS security
2. What is FreeIPA?
   - Elevator pitch: Identity, Policy, Audit — integrated open source solution
   - The stack: 389 Directory Server + Kerberos + Dogtag + BIND + Apache
3. Architectural overview of FreeIPA
   a. dirsrv (389 Directory Server) — LDAP backend
   b. Kerberos (krb5kdc) — authentication
   c. Dogtag / certmonger — PKI and certificate lifecycle
   d. named-pkcs11 — BIND with DNSSEC
   e. apache / ipa-httpd — web UI and API
   f. SSSD — client-side identity/auth daemon
4. Key capabilities
   a. Users, groups, sudo rules, host-based access control (HBAC)
   b. Certificate management (certmonger + Dogtag CA)
   c. DNS and DNSSEC
5. FreeIPA vs Active Directory
   - What AD does; what FreeIPA does; where they overlap
   - Trust relationships: joining FreeIPA and AD domains
6. Who needs this?
   - Home lab: one place to manage users, SSH keys, sudo; certs for home services
   - Enterprise: compliance, HBAC, audit, scale
7. Installing freeipa-server — basic setup
8. Enrolling clients — ipa-client-install and SSSD
9. Demo — user login, sudo rule enforcement, certificate issuance
10. Honorable mentions: AD trust integration
11. Questions and information about the next meeting


## Project Layout

```
.
├── slides.md
├── images/
├── ansible/
│   ├── ansible.cfg
│   ├── inventory
│   ├── provision-lab.yml
│   ├── teardown-vms.yml
│   ├── site.yml
│   ├── requirements.yml
│   ├── keys/
│   │   ├── demokey.pub
│   │   └── demokey               (gitignored — private key)
│   ├── tasks/
│   │   └── provision_vm.yml      (per-VM provisioning, called by provision-lab.yml)
│   └── group_vars/
│       ├── all.yml
│       ├── ipa_server.yml
│       └── ipa_clients.yml
├── .venv/                        (gitignored — Python virtualenv)
└── package.json
```

## Marp Setup

```bash
npm install
```

### Slide Build Commands

```bash
npm run build
npm run build:pdf
npm run build:pptx
npm run watch
npm run serve
```

### Marp Layout Debugging Checklist

Use this when slide elements look misplaced, overlap, or ignore expected CSS.

- Verify the positioning container:
	- If using `position: absolute`, ensure the intended parent is `position: relative`.
	- Exclude special elements (like `.footnote`) from broad selectors that set `position`.
- Check selector scope and specificity:
	- Prefer targeted selectors over `section *` style broad rules.
	- Confirm no generic rule overrides component classes.
- Validate stacking order:
	- Background motifs/pseudo-elements should be lower `z-index` than content.
	- Keep overlays (`.footnote`, badges) on a higher `z-index`.
- Reserve space for fixed/absolute elements:
	- Add extra bottom padding on slides with footnotes to avoid content collision.
	- Keep footnotes above global footer and below main content.
- Confirm Marp directives on each slide:
	- Check `_class`, `_header`, `_footer`, and `_paginate` for local overrides.
	- Ensure per-slide directives are not unintentionally persisting.
- Rebuild and inspect in both modes:
	- Use `npm run watch` for live checks.
	- Run `npm run build` to confirm final output matches preview.
- Debug quickly with temporary styling:
	- Add temporary borders/background colors to identify real layout boxes.
	- Remove temporary debug styles before commit.

## Demo lab

A local libvirtd daemon is accessible by the workstation on qemu:///system. Using ansible, 3 Fedora Server VMs should be created, one will be the FreeIPA server, the other two clients. The VMs should have all the packages installed for FreeIPA use, but not have the install scripts run yet.

### Ansible venv setup

Use Ansible through a local venv at `.venv/` in the project root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install ansible
```

Use the venv's `ansible-galaxy` to install required collections:

```bash
.venv/bin/ansible-galaxy collection install -r ansible/requirements.yml
```

The `requirements.yml` must include at minimum `community.libvirt`.

### Overwrite flag

Run with `-e overwrite=yes` to allow the playbook to tear down and recreate existing VMs and disk images:

```bash
ansible-playbook ansible/provision-lab.yml -e overwrite=yes
```

Without this flag, the playbook stops if VMs or QCOW2 files already exist.

### Infrastructure

Base cloud image: `/VirtualMachines/Fedora-Server-Guest-Generic-44-1.7.x86_64.qcow2`
Storage pool: `FastStorage` (`/VirtualMachines/`), accessed via `qemu:///system`
Network: Default network pool (`192.168.122.0/24`). DHCP starts at `.20`, so static IPs below that are safe to use.

### VM definitions

| VM | Hostname | IP | Cores | RAM |
|----|----------|----|-------|-----|
| FreeIPA server | ipaserver.intlug | 192.168.122.10 | 2 | 4 GiB |
| Client 1 | ipaclient1.intlug | 192.168.122.11 | 1 | 4 GiB |
| Client 2 | ipaclient2.intlug | 192.168.122.12 | 1 | 4 GiB |

### Networking and DNS — libvirt MAC mapping

Static IPs and name resolution are handled entirely within libvirt — no changes to the workstation's `/etc/hosts` or DNS config are needed.

Each VM is assigned a fixed MAC address at creation time. The playbook uses `virsh net-update` to register each MAC→IP→hostname mapping in the default network's dnsmasq configuration:

```bash
virsh net-update default add ip-dhcp-host \
  '<host mac="52:54:00:xx:xx:xx" name="ipaserver.intlug" ip="192.168.122.10"/>' \
  --live --config
```

libvirt's dnsmasq (listening on `virbr0` at `192.168.122.1`) then:
- Assigns the fixed IP to the VM via DHCP when it boots
- Resolves `ipaserver.intlug` (and short name `ipaserver`) for all guests on the network

The existing mappings already present in the default network definition follow this same pattern. The Ansible inventory uses the static IPs directly; the VMs resolve each other by hostname via dnsmasq.

### General provisioning process

1. **Guard check** — if VMs or QCOW2 overlay files already exist, stop unless `-e overwrite=yes` is set.

2. **Validate base image** — confirm the template QCOW2 exists and is readable. Set it read-only if it is not already (`chmod a-w`).

3. **Register MAC→IP→hostname mappings** — add each VM's entry to the default network via `virsh net-update` so dnsmasq is ready before the VMs boot.

4. **Create overlay images** — create a 30 GiB QCOW2 overlay per VM backed by the template, stored in `/VirtualMachines/`.

5. **Build and attach cloud-init ISOs** — generate a cloud-init `user-data` / `meta-data` / `network-config` ISO for each VM. The cloud-init config must:
   - Create the `ansible` user with full passwordless sudo (`NOPASSWD: ALL`)
   - Create the `demo` user with full passwordless sudo
   - Add `demokey.pub` as an authorised SSH key for both users
   - Copy the `demokey` private key into `demo`'s `~/.ssh/` (the demo user will SSH between VMs)
   - Set the hostname and configure the network interface with the static IP, gateway `192.168.122.1`, and DNS `192.168.122.1` with search domain `intlug`

6. **Define and start VMs** — create each VM via `virt-install` or the `community.libvirt` module with the correct disk, ISO, network, memory, and CPU settings.

7. **Verify connectivity** — wait for SSH to become available on each VM, then verify each client can reach the server by ping. Do this before any package work; networking problems should be caught here.

8. **Install packages** — on the server install `freeipa-server` and `freeipa-server-dns`; on the clients install `freeipa-client`. Do not run `ipa-server-install` or `ipa-client-install` — that is reserved for the demo.

9. **Final check** — confirm the expected packages are installed and services are inactive (not yet configured).
