---
title: "Database Connections in the Terminal"
subtitle: "Leveraging SSH and Vim to inspect remote databases"
description: "A guide to setting up a database IDE in Vim, with a focus on managing SSH tunnels."
author: devsjc
date: "2024-04-05"
tags: [vim, ssh, sql]
---

<figure>
  <img src="/images/dbui.png" alt="Vim DBUI" />
  <figcaption>Vim running DBUI</figcaption>
</figure>

Like the colour scheme? See [vim-jb](https://github.com/devsjc/vim-jb)!


## Background: What's the Aim?

As a developer, you’ll inevitably find yourself having to interact with databases. There are
GUI tools available ([DataGrip](https://www.jetbrains.com/datagrip/), [DBeaver](https://dbeaver.io/)),
but in the spirit of [my previous article](https://medium.com/@devsjc/from-jetbrains-to-vim-a-modern-vim-configuration-and-plugin-set-d58472a7d53d)
I wanted to see if I could find a frictionless setup that allowed me to stay in the terminal, and
even better, in Vim.

However, connecting to databases isn't necessarily straightforward, as often they are hosted
remotely and require SSH tunnels to access. This is something that GUI tools abstract away, so a
requirement of any terminal-based process I could come up with was to handle these cases as
seamlessly as possible. It is not uncommon to have to remember several such connections, along
with their URLs and authentication parameters. In this guide we'll learn how to leverage our SSH
config to make tunnelling easier regardless of the number and complexity of the connections.

This guide will use PostgreSQL as an example, but the principles and tools can be applied to other
databases as well, including NoSQL backends. And even if you don’t use Vim, you may learn a tip
or two about handling database connections in the terminal regardless! It assumes some familiarity
with both Vim and PostgreSQL/JDBC connection strings, but should be accessible to anyone with a bit
of experience in either.

## Vim Plugins

Handily, there already exists a set of high quality vim plugins providing much of the visual and
interactive functionality you’d expect from a GUI database tool. The plugins are called
[vim-dadbod](https://github.com/tpope/vim-dadbod) and [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui),
and can be installed with your favourite plugin manager. Alongside these, we’ll glean some extra
useful functionality with another plugin: [vim-dispatch](https://github.com/tpope/vim-dispatch).
We’ll come on to this one later.

Assuming a setup as described in ["From Jetbrains to Vim"](https://medium.com/@devsjc/from-jetbrains-to-vim-a-modern-vim-configuration-and-plugin-set-d58472a7d53d),
installation of the plugins means adding the following to your vimrc file:

```vim
function! s:packager_init(packager) abort
    ...
    call a:packager.add('tpope/vim-dadbod')
    call a:packager.add('kristijanhusak/vim-dadbod-ui')
    call a:packager.add('tpope/vim-dispatch')
endfunction
```

Running `:PackagerInstall` will clone the repositories into vim’s package directory.

The plugin `vim-dadbod` provides a set of commands and mappings to interact with databases,
including running queries, viewing tables, and managing connections. The UI plugin provides a
visual interface for these commands, and can be opened with `:DBUI`. Opening the UI now won’t
show much however, as we haven’t defined any database connections! Lets do that next.

## Defining Connections

A useful feature of any Database IDE is the ability to define connections to databases, so you can
easily interact and switch between instances without having to remember the credentials,
connection strings, or other details. The `vim-dadbod-ui` plugin ships with a few implementations
of this feature, but we will focus on the `:DBUIAddConnection` command, which provides a number of
benefits over the others, chiefly enabling restart-persistent global access, and a reducing ease of
accidental committing of credentials to version control.

### Local connections

For local databases, connection is very straightforward. The connection url is familiar to those
you might have set up in your GUIs, so to add a local PosrgresSQL database connection to
`vim-dadbod-ui` it's a simple matter of running the `:DBUIAddConnection` command, and entering the
connection details, e.g. `postgresql://localhost:5432/postgres`.

If you have a local instance of PostgreSQL running on the default port `5432`, you should now see
the connection to it when running the `:DBUI` command. If you’ve changed the user or password
from the defaults, you can specify these in the connection string, e.g.
`postgresql://username:password@localhost:5432/postgres`

Behind the scenes, the `:DBAddConnection` command appends the connection details to a JSON file in
your home directory, by default `~/.local/share/db_ui`. This file can be edited directly if you
prefer to manage your connections without incorporating Vim: the schema is a simple list of
`{"url": "","name": ""}` objects. Using this file then prevents you from requiring to remember
connection strings and authentication for any databases you work with, storing them in a
centralised and private location.

More often than not the databases you’ll be working with in production will not be on your local
machine, but rather hosted on some server or cloud provider. In these cases, you’ll often first
have to set up an SSH tunnel to access the database, which we’ll cover next.

### Remote Connections: SSH Tunnels and PortForwards

Remote databases can’t necessarily be accessed directly, as they are often hosted in private
networks. For those that can, such as BigQuery or MongoDB, connecting to them is similarly
straightforward to the local case (see `ADAPTERS` heading of `vim-dadbod`’s [help](https://github.com/tpope/vim-dadbod/blob/master/doc/dadbod.txt)).
For those that can’t, such as PostgreSQL in an RDS instance, you’ll need to set up an SSH
tunnel to access them.

**A Simple Example: PostgreSQL on a Raspberry Pi**

For instance, consider a Raspberry Pi hosting a PostgreSQL database on a local network. The Pi has
an IP address `192.168.0.5`, and a PostgreSQL instance is installed and running on the default port
`5432`. To connect to this database from your local machine, you can set up an SSH tunnel with the
following command:

```bash
$ ssh -i ~/.ssh/id_pi -N -L 5433:localhost:5432 piuser@192.168.0.5
```

This is assuming an SSH connection is set up with the `~/.ssh/id_pi` keypair. This command forwards
the local port `5433` to the Pi’s port `5432`. You can now connect to the database with the
connection string `postgresql://localhost:5433/postgres`, provided there is a terminal window open
dedicated to running the SSH tunnel.

This setup isn’t the most convenient however, requiring multiple terminal windows and the
remembering of the SSH tunnel command. In the next example we’ll look at ways to ease the 
cognitive load and simplify the tunnelling process, even in the face of a more complicated scenario.

**A Complicated Example: Bastion Hosts**

A common pattern for cloud databases is to host them in a private network, and use a minimal
virtual machine as a bastion host to connect to them. This prevents setting firewall rules on the
database itself, but necessitates creating an SSH tunnel to the bastion host in order to access the
database.

For instance, consider some data store in a private network with endpoint
`my-datastore.region.datastore.provider.com` and port `5432`. The private network has an
externally-accessible bastion instance with address `a.b.c.d.bastionhost.com` and user `username`.
Tunnelling a port from your machine to the datastore’s port through the bastion host can be done
with a command such as:

```bash
$ ssh -i ~/.ssh/id_bastion -N -L 5000:my-datastore.region.datastore.provider.com:5432 username@a.b.c.d.bastionhost.com
```

which forwards the local port `5000` to the datastore’s port `5432`. Commands like this are
cumbersome to remember though, so it’s useful to add these configurations to your SSH config file
(`~/.ssh/config`):

```sshconfig
Host bastion
  HostName a.b.c.d.bastionhost.com
  User username
  IdentityFile ~/.ssh/id_bastion
  LocalForward 5000 my-datastore.region.datastore.provider.com:5432
```

The LocalForward directive specifies any port forwarding that should be done when connecting to the
host. Now, connecting to the bastion host and forwarding the port can be done with a simple command:

```bash
$ ssh -N bastion
```

The `-N` flag tells SSH not to execute a remote command, which is useful when you just want to
forward ports.

Similarly, the Raspberry Pi example described above can be specified in the SSH config file as well:

```sshconfig
Host pi
  HostName 192.168.0.5
  User piuser
  IdentityFile ~/.ssh/id_pi
  LocalForward 5433 localhost:5432
```

With the bastion SSH command running in its own terminal window, the remote database is accessible
at port `5000`, so the connection string can be added to `vim-dadbod-ui` with the
`:DBUIAddConnection` command:

```vim
:DBUIAddConnection postgresql://dbuser:dbpass@localhost:5000/prod_database
```


## Background Tunnels: Vim Dispatch

The SSH tunnel commands described above are useful, but they require a terminal window to be open
and the command to be running at all times - not very streamlined. Ideally, the creation and
destruction of any required SSH tunnels should be handled on database connection in the UI. This
isn’t something I’ve been able to find a solution for yet, but it seems there is
[half an eye on it for the roadmap of the `vim-dadbod-ui` plugin](https://github.com/kristijanhusak/vim-dadbod-ui/issues/202).
In the meantime, we can leverage the vim-dispatch plugin installed earlier.

The `vim-dispatch` plugin enables background running of jobs in Vim. This is useful for
long-running tasks, such as SSH tunnels, as they can be run in the background without blocking the
UI. It provides the vim command `:Start!` to run a command asynchronously, enabling the following,
reasonably efficient, Vim database IDE workflow:

1. Launch Vim: `$ vim`
2. Asynchronously spin up a database connection, using the SSH config alias: `:Start ssh -N -v bastion`
3. Launch DBUI, which reads the connections defined earlier from the JSON file: `:DBUI`

Now we are able to view the tables using the vim-dadbod-ui interface! No remembering connection
strings or credentials, and no need to keep a terminal window open for the SSH tunnel.

## Wrap Up

Thus completes our setup for a vim-based database IDE. A lot of the heavy lifting in terms of ease
here is in fact done using the SSH config file.
