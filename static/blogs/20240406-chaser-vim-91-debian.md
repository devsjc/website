---
title: "[chaser] how to install Vim 9.1 on Debian Bookworm"
subtitle: "or any package from debian testing"
author: "devsjc"
date: "2024-04-06"
tags: [vim, debian]
---

Want to use your favourite language server protocols with proper virtualtext support in Vim's latest release, 9.1 - but unable to do so from your favourite linux distro, Debian 12 Bookworm? Me too! Luckily, you can fix it - without breaking Debian!

Vim 9.1 is [available in Debian testing](https://packages.debian.org/trixie/vim). To install it, firstly create a new file in `/etc/apt/sources.list.d/` called `testing.list` with the following contents:

```txt
deb http://deb.debian.org/debian/ testing main
deb-src http://deb.debian.org/debian/ testing main
 ```

Now, running `sudo apt update` will add the new list to your sources:

```bash
$ sudo apt update
Hit:1 http://security.debian.org/debian-security bookworm-security InRelease
Hit:2 http://deb.debian.org/debian bookworm InRelease
Hit:3 http://deb.debian.org/debian bookworm-updates InRelease
Hit:4 http://deb.debian.org/debian testing InRelease
Fetched 6,572 B in 1s (9,838 B/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
524 packages can be upgraded. Run 'apt list --upgradable' to see them.
```

Debian testing can be seen in the sources. But wait - we only want Vim 9.1, and as it stands, many packages are being listed as upgradeable to their versions in testing! In order to avoid accidentally upgrading anything, we need to make another file, this time in `/etc/apt/preferences.d/` called `testing.pref`:

```txt
Package: *
Pin: release a=testing
Pin-Priority: -2
```

By specifying the priority to negative, `apt` will never choose candidates from this release when running commands unless explicitly requested - so now a `sudo apt update` shows the following:

```bash
$ sudo apt update
Hit:1 http://deb.debian.org/debian bookworm InRelease
Hit:2 http://security.debian.org/debian-security bookworm-security InRelease
Hit:3 http://deb.debian.org/debian bookworm-updates InRelease
Hit:4 http://deb.debian.org/debian testing InRelease
Fetched 6,572 B in 1s (9,547 B/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
All packages are up to date.
```

In this manner, testing has been added safely as a source! Finally, to install Vim 9.1, we can now run

```bash
$ apt install vim/testing
```

Since Vim has dependencies only on a couple of its own packages, we aren't going to be adversely affecting any core libraries with this upgrade. Check the new version is correctly installed:

```bash
$ vim --version | head -n 2
VIM - Vi IMproved 9.1 (2024 Jan 02, compiled Jan 11 2024 20:38:16)
Included patches: 1-16
```

Enjoy Vim 9.1 on your stable machine!

