---
title: "How uv Helps Me to Not Hate Python"
subtitle: "and how to let it help you, too"
description: "A guide to using uv across the python development lifecycle."
author: devsjc
date: 2025-04-11
tags: [uv, python, guide]
---

I'm not a huge fan of Python. Or at least, that's the shortest way to describe how, whilst it's
undeniably extremely capable and accessible at the same time, it is also sprawling with libraries
and tools, has an ecosystem that doesn't feel unified, makes it easy to profliferate bad practice,
and makes it hard to ensure proper code safety. Using it and reading it has always felt like a
chore; packaging and deploying it to production like a recipie for disaster.

Compared to carrying out the development lifecycle in other languages, like Rust or Go, where
types are static and tools are unified, Python has always felt like it got in the way more than it
enabled.

But now `uv` has come along, and made a lot of my dislikes about Python redundant. Install it with

```bash
$ curl -LsSf https://astral.sh/uv/install.sh | sh
```

and lets see how it can help you hate python a little bit less, too.


## For local development

I have [already written a blog post](#p20240406)
on using `pyproject.toml` to manage Python projects, in which the claim is made that it can be laid
out in a tool-agnostic manner. Helpfully, `uv` isn't bucking that trend, and so, provided that I
am cloning a repository that has a `pyproject.toml` file similar to as in that post, getting started
with development is extremely quick:

```bash
$ git clone git@github.com:some-user/some-repo.git
$ cd some-repo
$ uv sync
```

Because `uv` manages dependencies sensibly (pinning versions in `pyproject.toml` and using a
lockfile), creating the environment for someone else's `uv`-managed project actually works! It may
seem like a very low bar, but from all previous experience working with Python, where it was
anyone's guess as to whether a project would work out of the box, this is, all the same, a bar that
warranted clearing...

If I'm lucky enough to have the chance to do some greenfield development, creating a well-laid-out
project is equally simple:

```bash
$ uv init --app --package some-package --build-backend setuptools
$ cd some-package
$ uv venv
```

This creates a new directory called `some-package` with a `pyproject.toml` file, a `README.md`,
and a `src` directory with a folder for the python package inside, as well as a `.venv` folder.
Adding dependencies and installing them to the virtual environment is then done by `uv add`:

```bash
$ uv add requests
```

And dev dependencies - anything not required to run the app itself, such as packages required for
testing - are added with `uv add --dev`:

```bash
$ uv add --dev hypothesis ruff
```

This updates the `pyproject.toml` file for me! It feels like using some language that isn't Python,
where the package manager is sensible and dependencies are well managed. Note how `uv` enables good
practice - source layout, separation of dependencies, dependency pinning and so on - encouraging
better behaviour to help [even the most uncaring developer](https://josvisser.substack.com/p/you-cant-teach-caring)
structure and manage their codebase in a robust way.

Also note how at no point have I had to activate or even thing about a virtual environment, because
provided there is a `.venv` directory in your working folder, `uv` commands will use it
automatically. If I want to spawn a python shell, or run my app through it's entrypoint, or run a
test suite, or lint or typecheck my code - it's just a matter of prefixing the usual commands with
`uv`:

```bash
$ uv run python
$ uv run my-entrypoint
$ uv run python -m unittest discover -s src -p "test_*.py"
$ uv run ruff check --fix .
$ uv run mypy .
```

<aside>
I haven't mentioned ruff in here, but it is definitely another key component of the tooling making
python less painful to use - see the pyproject blog post I mentioned earlier for more on that.
</aside> 

`uv`'s caching will ensure you don't end up in a node-modules -esque world of sprawling
multi-gigabyte `.venv` directories as it hardlinks from the cache directory by default. And I'm not
just limited to python commands: I can run anything in the virtual environment, so

```bash
$ uv run vim .
```

in an environment with `python-lsp-server`, for instance, as a development dependency creates a
vim instance with LSP support - an ease of integration that impresses me every time.

<aside>
Of course, you'll need to have LSP support set up in vim, but 
<a href="https://bsky.app/profile/crmarsh.com/post/3lgvhzdfrps26">here's a blog post</a>
on how to do that too! I like to also have <code>python-lsp-ruff</code> and 
<code>pylsp-mypy</code> in the dev dependency group to get linting and type checking through LSP
too.
</aside>


## In Docker containers

Building a container is also improved using `uv`. Here is an example Dockerfile, with comments
describing each stage, that is designed to be optimal for production use. It uses a layered
approach, building dependencies in one stage and the application in another, slimmer one. The
dependency builder stage only reruns when when the dependencies change; the application builder
stage when the application code changes. This keeps builds quick and efficient.

```Dockerfile
# --- Dependency builder image (can use python-3.12 if need gcc etc) --- #
FROM python:3.12-slim-bookworm AS build-deps

# Install build requirements into build image
# * UV for python packaging
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Add only files required for dependencies
# * pyproject.toml: Project configuration
# * uv.lock: Dependency lockfile
WORKDIR /opt/app
COPY pyproject.toml uv.lock /opt/app/

# Make UV behave in a container-orientated way
# * Compile bytecode to reduce startup time
# * Disable cache to reduce image size
ENV UV_COMPILE_BYTECODE=1 \
    UV_NO_CACHE=1 \
    UV_LINK_MODE=copy

# Install dependecies
# * mkdir src: Required if application uses src layout
# * --no-dev: Do not install development dependencies
# * --no-install-project: Only install dependencies
# * --no-editable: Copy the source code into site-packages
RUN mkdir src && \
    uv sync --no-dev --no-install-project --no-editable

# Remove tests (Pandas ship loads, for instance)
# * Remove this line if causing problems
RUN rm -rf /opt/app/.venv/lib/python3.12/site-packages/**/tests

# --- App builder image --- #
FROM build-deps AS build-app

# Install the project
COPY src /opt/app/src
RUN uv sync --no-dev --no-editable

# --- Runtime image (use distroless if feasible for 100MB saving) --- #
FROM python:3.12-slim-bookworm AS runtime

WORKDIR /opt/app
# Copy just the virtual environment into a runtime image
COPY --from=build-app --chown=app:app /opt/app/.venv /opt/app/.venv

ENTRYPOINT ["/opt/app/.venv/bin/some-entrypoint"]
```

Whilst these Dockerfiles are absolutely not as lightweight as those you get when using Go, thanks
to `uv` and the staged setup they do build reasonably quickly, reducing CI wait times. If you have
particularly large dependencies, you can also mount your local cache directory when running the
dependency install step, and enable cahce useage, as it isn't copied over into the final image
anyway so won't affect image size - however `uv` is so fast I didn't really notice much difference!


## Publishing to PyPI

Publishing to PyPI is, again, dead easy and quick. Just get a PyPI token (or even better, set up
[trusted publishing](https://docs.pypi.org/trusted-publishers/)) and then

```bash
$ uv build
$ uv publish -t <token>
```

This is very easy to port to CI/CD pipelines.

## Final thoughts

In summary then, I'm indebted to Charlie Marsh and the [astral.sh](https://docs.astral.sh/) team
for bringing the Python ecosystem into a state in which even the most anti-python developers, 
forced to use it for work or ML, can be productive and even find a bit of joy in it. If their
[upcoming static type checker](https://bsky.app/profile/crmarsh.com/post/3lgvhzdfrps26) is as good
and as paradigm-shifting as `uv` and `ruff` were, well, I might just change my stance from thinking
I don't like Python to realising that I just don't like bad code, which, with this improved
tooling, doesn't have to be partly to blame on the Python ecosystem anymore.

<aside>
And if type hinting proliferates as a result, maybe I'll finally shut up about Python altogether...
<a href="https://bsky.app/profile/jack-kelly.com/post/3ldijzckh6c2c">I agree, Jack!</a>
</aside>

