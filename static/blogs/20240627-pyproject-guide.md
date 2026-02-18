---
title: "The Complete Guide to pyproject.toml"
subtitle: "the simplest way to manage and package python projects"
description: "A walkthrough detailing a python setup that ditches poetry, setup.py, and even requirements.txt."
author: devsjc
date: 2024-06-27
tags: [pyproject, python, packaging, guide]
---

*Just looking for a `pyproject.toml` to copy to your new project? See the
[accompanying gist](https://gist.github.com/devsjc/86b896611d780e3e3c937b9c48682f31)!*

## Background: Why do we need pyproject?

Let's get the elephant in the room out of the way first, because I know what some of you are
thinking: Isn't `pyproject.toml` the [poetry](https://python-poetry.org/) configuration file?
Well, yes it is, but you might not know that it's actually a general python project configuration
file that works with many build frontends and backends[[1]](https://packaging.python.org/en/latest/tutorials/packaging-projects/#choosing-a-build-backend),
poetry being one such frontend example. So this blog won't be talking about poetry at all. In fact,
in favour of creating the most ubiquitous, understandable, and portable python project setup
possible, I'll be explaining how to use pyproject with the most widely used build
frontend - `pip` - and backend - `setuptools`[[2]](https://drive.google.com/file/d/1U5d5SiXLVkzDpS0i1dJIA4Hu5Qg704T9/view).

<aside>
Although, I'd highly recommend using <a href="https://docs.astral.sh/uv/">uv</a> for both! I
suspect it will dethrone the others in short order. Tempting as it is to change all the code
examples to use it, the point of this article is to show that pyproject can be agnostic to the
developer toolchain.
</aside>

So what is wrong with the current way of packaging python projects that might warrant a switch to
pyproject-based management? Consider the following not-too-far-fetched pattern for the root of a
python repo:

```
cool-python-project
├── requirements.txt
├── requirements-dev.txt
├── setup.py
├── setup.cfg
├── README.md
├── mypy.ini
├── tox.ini
├── .isort.cfg
├── environment.yaml
└── main.py
```

So many files! Lets talk through why each of these files are here, and why they perhaps shouldn't be.

It has been known for a long time the security risk posed by `setup.py` files[[3]](https://www.siliconrepublic.com/enterprise/python-package-security-flaw-setup-vulnerability-hack-developers) -
the code within is executed on download of a `sdist` format package by pip, and since it's
editable by the author of the package, could contain malicious code. This is partially solved by
the introduction of `wheels` and the use of the declarative `setup.cfg`, often used to defining
linting configuration and package metadata, but you will regularly still encounter a "dummy"
`setup.py` even in projects defined through `setup.cfg`. The `requirements.txt` file, whilst at
first order seems to be alright at describing the package dependencies, falls down when you want to
separate development dependencies from the subset of those required purely to run an app in
production - so you might end up with mulitple requirements files for different contexts.
Furthermore, installing a project that is structured like this (with source files alongside
configuration files) for local development has knock on effects on writing tests, as imports may be
inaccurate reflections of their path when installed as a full package[[4]](https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/).
The `environment.yaml` is an example of a virtual-environment -specific dependency file. The
inclusion of these types of files serves to reduce the portability of a package, as they require
specific tools to be installed outside of the standard python toolkit to begin to work on the
project. Finally, the various configuration files for linters and the like (`mypy.ini`, `.isort.cfg`
etc.) add further clutter, diluting the repo root and reducing the speed with which a
newly-onboarded developer can parse where the important parts of the repository lie. 

The good news is, all of the functionality found in these files can be incorporated neatly into a
single, declarative file: `pyproject.toml`. This isn't new news by any stretch, but the lack of
uptake and understanding I have experienced has compelled me to write this guide to hopefully aid
in moving the community forward to a more straightforward python packaging setup.

But don't just take my word for it! In case you needed any more convincing, the official python.org
packaging guide[[5]](https://packaging.python.org/en/latest/tutorials/packaging-projects/)
specifies `pyproject.toml` as the recommended way to specify all the metadata, dependencies and
build tools required to package a project. And to restate the title, it is agnostic to your
environment manager: all it needs is `pip`, which comes preinstalled with most python environments[[6]](https://pip.pypa.io/en/stable/installation/#installation).
As such it is an eminently portable setup, reducing the friction for developers working on the code.

Lets get to work cleaning up the roots of those repos!


## Ditching requirements.txt

The first piece of functionality we'll investigate is that of managing your dependencies with
`pyproject.toml`. The main metadata section of the `pyproject.toml` file comes under the
`[project]` header, and its this section that dependencies are defined, using the `dependencies`
key. Lets create a basic file with the mandatory keys, and add some dependencies. Remember to first
create a new virtual environment with your favourite virtual environment tool (most likely `venv`[[2]](https://drive.google.com/file/d/1U5d5SiXLVkzDpS0i1dJIA4Hu5Qg704T9/view))!

```toml
[project]
name = "cool-python-project"
version = "0.1.0"
dependencies = [
    "numpy == 1.26.4",
    "structlog == 22.1.0"
]
```

Since pip doesn't yet have the functionality for automatically modifying `pyproject.toml` files[[7]](https://discuss.python.org/t/poetry-add-but-for-pep-621/22957/21), these requirements are added in manually, pinning them at the version desired by the developer. Whilst you can specify unversioned dependencies, lets leave
that habit at the door along with the `requirements.txt` that encourage it! Now we can install the
desired packages into our virtual environment with 

```bash
$ pip install -e .
```

The dependencies will now be installed into the `site_packages` folder of your virtual environment.
(For non-python users, this is similar to a `node-modules` or `vendor` folder - it's where your
build frontend stores dependency source code.)


### Editable and normal installations

What's that `-e` flag? This tells pip to perform an *editable* install, which is the install mode
best for development of a project. Normally when you install a dependency (such as `requests`), pip
copies the source code files as distributed into your site-packages folder. When you instantiate or
import the package, it reads the code from that folder. But when you're developing your own
project, you want your changes to the source code to be immediately reflected in instantiation, for
instance when importing into tests or trying out command-line invocations. As such, you can
instruct pip to install your project in editable mode, which means imports of the project resolve
at the source code in the repo. This then acts as the source of truth for the package (instead of a
copy in `site-packages`) and enables you to quickly iterate on and test code changes. This is a
golden rule when developing with a `pyproject.toml` file:
*when working locally, always do an editable install of your package*.

It is all to easy to mess up your PYTHONPATH, and accidentally import your package in normal mode,
halting development progress whilst you recreate your virtual environment. You can (and should)
further ensure import consistency by laying out your python project in the `src` layout, again as
recommended by `python.org`[[4]](https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/).

For more information on editable installations, see the Setuptools' guide to Development Mode[[8]](https://setuptools.pypa.io/en/latest/userguide/development_mode.html).


### Optional dependencies

The `pyproject.toml` file improves upon `requirements.txt` by allowing the specification of
*optional dependencies* - dependencies required for parts of local development of the project, but
not integral to running it when distributed. These could be test-
or [linting](#configuring-linters)-specific requirements, and can be grouped by a key describing
their utility in the `pyproject.toml` file.

For instance, say our project has its test suite written in [pytest](https://pypi.org/project/pytest/),
with a few [behave](https://pypi.org/project/behave/) features thrown in. Furthermore, these tests
are running against mock s3 services requiring the [moto](https://pypi.org/project/moto) library.
The moto wheel is nearly 4 Mb by itself, which may not sound a lot, but these numbers add up as
more external libraries are pulled in: failure to keep an eye on dependency sizes leads to bloated,
slow-to-download dockerfiles, wheels, long build pipelines, and frustrated developers! So lets be
vigilant and namespace these requirements under an optional dependency group:

```toml
[dependency-groups]
test = [
    "moto[s3] == 4.2.11",
    "pytest == 8.2.0",
    "behave == 1.2.6",
]
```

Now, as before, running `pip install -e .` installs only the dependencies specified in the
`dependencies` array under the `[project]` heading. To install the test dependencies as well, we
have to explicitly request them:

```bash
$ pip install -e .[test]
```

<aside>
Note that `zsh` users (that's likely you if you're using a Mac) will need to escape the square
brackets with a backslash, e.g. <code>pip install -e .\[test\]</code>! This is because
<code>zsh</code> uses square brackets for pattern matching<a href="https://zsh.sourceforge.io/Guide/zshguide05.html#l135">[9]</a>.
</aside>

Now we also want to lint our project to ensure consistency of code, but again, we don't want to
include their distributions in our production build as, again, they aren't necessary for running
the service - so we do the same thing, this time with a linting section:

```toml
[dependency-groups]
test = [
    "moto[s3] == 4.2.11",
    "pytest == 8.2.0",
    "behave == 1.2.6",
]
lint = [
    "ruff == 0.4.4",
    "mypy == 1.10.0",
]
```

Now, developers can install the linting requirements as above, swapping `test` for `lint`. 

This separation is useful as it clearly defines the concerns each requirement corresponds to, but
it might get annoying for a developer adding features to the codebase to remember to install both
the `test` and `lint` optional dependencies every time they set up their virtual environment.
Thankfully, we can make an easy shorthand for them whilst keeping the modularity brought by the
separation of dependencies.

```toml
[dependency-groups]
test = [
    "moto[s3] == 4.2.11",
    "pytest == 8.2.0",
    "behave == 1.2.6",
]
lint = [
    "ruff == 0.4.4",
    "mypy == 1.10.0",
]
dev = [
    "cool-python-project[test,lint]",
]
```

Here we have added a `dev` section to out optional dependencies, intended for local development,
which installs all the optional groups required for that task - in this case, `test` and `lint`.
Note that `cool-python-project` must be taken verbatim from the `name` field in the `[project]`
section, so change this accordingly! Now all a new developer has to do is 

```bash
$ pip install -e .[dev]
```

to pull in everything they might need, but someone else who just wants to run the test suite can
still do so, as we haven't lost the granularity of pulling only the necessary requirements for testing.

<aside>
If you're using <code>uv</code>, the command <code>uv sync</code> will automatically install the
<code>dev</code> dependency group, so it has a special significance in that context.
As a result of this, I now just put anything not needed for production in the <code>dev</code>
group and eschew further grouping. <code>uv</code> is so fast it feels unecessary to split more!
</aside>


Phew! We've entirely replaced `requirements.txt` and some, enabling extra useful functionality to
boot. But now we've got our dependencies sorted, how do we make sure all developers are linting and
formatting the code in the same way? Lets go about removing some more config files, and while we're
at it, lets learn what we were on about in the `lint` dependency array with "ruff" and "mypy"...


## Configuring Linters

The next piece of functionality we'll glean from `pyproject.toml` is that provided by many
tool-specific config, dot, and ini files - linting (and formatting, and fixing!). Using
`pyproject.toml`, we'll remove the need for `mypy.ini`, `tox.ini`, and `.isort.cfg`, further
reducing the file-soup in the root of our repository.


Ruff
----

There are many linting and fixing tools available for python (`Flake8`, `isort`, `Black` to name a
few), all of which would often be configured in `setup.cfg`, `tox.ini`, or other tool-specific
dotfiles. Even before we consolidate configuration to our `pyproject,toml` file, lets go one
further and consolidate these tools into one first - `ruff`. If you've already heard of it, great!
I hope you're using it already. If you haven't or aren't, now is a great time to start - it's quick[[10]](https://astral.sh/blog/the-ruff-formatter),
it's fast[[11]](https://docs.astral.sh/ruff/#testimonials), and it's got pace[[12]](https://www.youtube.com/watch?v=AfQarImZ97Y&t=228s).
It also bundles all three tools mentioned above, integrates well with IDEs, and of course, is
configurable using `pyproject.toml`. Lets add a section for it, using some example values (but by
no means the final word on how to configure ruff! It depends on your own or your organisations'
preferences).


```toml
[tool.ruff]
line-length = 100
indent-width = 4

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
line-ending = "auto"

[tool.ruff.lint]
select = [
    "F",   # pyflakes
    "E",   # pycodestyle
    "I",   # isort
    "ANN", # flake8 type annotations
    "RUF", # ruff-specific rules
]
fixable = ["ALL"]

[tool.ruff.lint.pydocstyle]
convention = "google"
```

I won't go into extreme detail about the above configuration, as a better reference would be the
ruff docs themselves[[13]](https://docs.astral.sh/ruff/configuration/). It is worth noting that the
headings and format of the ruff configuration section are subject to change, and the latest version
of ruff may expect something different to what is shown in this post. So, make sure to give the
documentation a read through in case of any unexpected errors!

In short, we've told ruff to expect a line length of 100 chars
(agreeing with Linus Torvalds[[14]](https://linux.slashdot.org/story/20/05/31/211211/linus-torvalds-argues-against-80-column-line-length-coding-style-as-linux-kernel-deprecates-it)),
an indent width of 4 spaces, and to use double quotes. We've also specified a set of rules to check
against and fix, pulling from `flake8`, `pycodestyle`, `pyflakes` and `isort`. We can now run ruff
against our codebase using 

```bash
$ ruff check --fix
```

For updates on file changes, we can also run `ruff check --watch`, but it's often easier to use
some IDE integration (VSCode[[15]](https://marketplace.visualstudio.com/items?itemName=charliermarsh.ruff),
JetBrains[[16]](https://plugins.jetbrains.com/plugin/20574-ruff), Vim[[17]](https://github.com/dense-analysis/ale)).

Adding ruff into the `pyproject.toml` configuration file like this, as well as pinning the version of
ruff in the dependencies, ensures that any other developers of our code will have the same working
configuration of ruff present to keep their code style consistent with the already existing codebase.
In this manner, a uniform development experience can be had by all contributors.


### MyPy

A blank project is also the best time[[18]](https://mypy.readthedocs.io/en/stable/existing_code.html)
to integrate `mypy`, which bring static type checking to python *a la* compiled languages. The
benefits of type safety and compiled languages, and the usage of mypy, is a blog post in itself;
suffice to say here that our code will be more understandable to new developers and less error
prone if we incorporate type hints and utilise a type checker such as mypy. I would make the
argument that we should absolutely include it in our new-fangled `pyproject.toml`-based python
program being set up here, and so, as with ruff, we will add a section for it:

```toml
[tool.mypy]
python_version = "3.12"
warn_return_any = true
disallow_untyped_defs = true
```

The python version should match the version of python you're using in your virtual environment.
Now we can run

```bash
$ mypy .
```

to type-check any code we have in our codebase, and act on any errors accordingly. For more in
depth usage instructions, see the mypy documentation[[19]](https://mypy.readthedocs.io/en/stable/index.html).
Again, there are integrations available for your usual IDEs (VSCode[[20]](https://github.com/microsoft/vscode-mypy),
JetBrains[[21]](https://github.com/leinardi/mypy-pycharm), Vim[[22]](https://github.com/dense-analysis/ale)).


Alright! Our development environment is in great shape! Anyone trying to work on our codebase needs
only python and pip to follow a frictionless entrypoint to consistent coding bliss. I can already
picture the glorious short, easy-to-understand nature of the "Development" section of the README!
So now lets switch our focus to building our code, and see how the `pyproject.toml` file once again
lets us keep things consolidated.


## Packaging for Distribution

If your project is intended as use as an installable library, or a command line tool, chances are
you're going to want to publish a distribution of it to PyPi. Building an `sdist` or `wheel`
requires the use of a build backend, as mentioned in the [Background](#background-why-do-we-need-pyproject).
Here, we'll use `setuptools`. The desire to use setuptools as our build backend must be specified
in a `[build-system]` section of the `pyproject.toml`:

```toml
[build-system]
requires = ["setuptools==69"]
build-backend = "setuptools.build_meta"
```

Now, running our `pip install` commands from before also installs the build system packages. Not
very exciting! So what can we do with this now we have it available?


### Entrypoints

We now need to make some assumptions about the layout of our project. Lets say we were paying
attention in the [editable installations](#editable-and-normal-installations) section, and have
laid out our codebase using the `src` structure similar to the following:

```
cool-python-project
├── pyproject.toml
└── src
    └── my_package
        └── main.py
```

Lets also assume that our `main.py` contains within it a function, `main`, that acts as the
entrypoint to a command-line interface for the project:

```python
"""main.py"""

import argparse

parser = argparse.ArgumentParser(prog="coolprojectcli")
parser.add_argument("echo", help="String to print back to the console")

def main():
    args = parser.parse_args()
    print(args.echo)
```

We might be tempted to run this with something like `python src/my_package/main.py`, but we can do
better. Lets use our `pyproject.toml` file to define scripts that run specified entrypoints of our
package[[23]](https://setuptools.pypa.io/en/latest/userguide/quickstart.html#entry-points-and-automatic-script-creation):

```toml
[project.scripts]
coolprojectcli = "my_package.main:main"
```

Now when we run our editable install as before, setuptools will create a script called
`coolprojectcli` in our virtual environment's `bin` folder that runs the `main` function in the
`main.py` module in the package `my_package`. Furthermore, because we performed an editable
install, the codebase is still the source of truth for this script, so modifications to `main` will
be reflected when running the script. Now we can use our package from the command line with a nice
command:

```bash
$ coolprojectcli -h
usage: coolprojectcli [-h] echo

positional arguments:
  echo        String to print back to the console

options:
  -h, --help  show this help message and exit
```

This better reflects how an end user might interact with the package, and again simplifies things
for new developers working with the codebase. The `README.md` file can now specify both a
straightforward installation command and a simple starting point for getting to grips with the
program.

```markdown
# README.md

## Development

Install the development dependencies and program scripts via `pip install -e .[dev]`.
The cli is then accessible through the command `coolprojectcli`.
```


### Metadata

Speaking of the `README.md`, it would be useful if people viewing the package on PyPi could be
privvy to the same information as those viewing the source code itself. To this end, there's lots
of metadata[[24]](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/) that can
be specified in `pyproject.toml` that build backends such as setuptools surface to PyPi (and other
artifact repositories). We can enrich our project with some additions to the `[project]` section,
such as author details, a description, a README embed, a license and so on.

```toml
[project]
name = "cool-python-project"
description = "A python project that is inexplicably cool"
requires-python = ">=3.12.0"
version = "0.1.0"
authors = [
    {name = "Your Name", email = "your@email.com"},
]
license = {text = "BSD-3-Clause"}
readme = {file = "README.md", content-type = "text/markdown"}
dependencies = [
    "numpy == 1.26.4",
    "structlog == 22.1.0"
]
```

The document specified as the `readme` will be used as the README of the built source distribution
and shown on the PyPi page for the project, in this case, a file in the root of the repository
called "README.md". The specified authors will be displayed with email links on the publish page
(if included; email is an optional field[[25]](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/#authors-maintainers)),
along with the licensing information. This is useful not just for filtering packages, but also in
an organisational setting it can help clarify who is primarily responsible for a piece of code. The
`requires-python` key limits the installation of the package to only virtual environments that meet
the requirements, helping prevent incompatibility errors from users running the service in an
invalid environment. More detail on what is available as metadata can be found in the setuptools
documentation[[26]](https://setuptools.pypa.io/en/latest/userguide/pyproject_config.html) and the
official python packaging user guide[[27]](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/).


Now we've got our build backend set up, we're ready to build our wheel! Thanks to all our
configuration specification in `pyproject.toml`, this is done via

```bash
$ python -m build --wheel
```

This builds a wheel in the newly-created `dist/` directory at the root of the codebase (make sure
it's in your `.gitignore`, and make sure you've installed `setuptools` and `wheel` with `pip` in
your virtual environment!), which can then be uploaded to PyPi using `twine` - however it's more
likely you'll want to do this as part of a CI process. We'll come on to that after the next section.

Next, lets move away from why and how we should use a `pyproject.toml` file, and instead see it in
action in scenarios you will be familiar with from across the development lifecycle: CI/CD and
Containerisation. This article will now act less as a tutorialized resource and more as a solutions
reference, describing how to achieve certain goals with the new `pyproject.toml` setup.


## Multi-stage Dockerfiles

One thing that I struggled with after adopting `pyproject.toml` was my usual multi-stage
Containerfile workflow. With a `requirements.txt` file, building a small container with just the
runtime dependencies was a fairly straightforward process: install the requirements into a virtual
environment in a build stage, copy the virtual environment into an app stage, copy the code into
the app stage, set the entrypoint, and you're away. The benefit of splitting out the layers in this
manner is that the build stage only has to run when `requirements.txt` changes, reducing subsequent
build times for code-only changes. With `pyproject`, it is a little hard to get this separation of
layers, but still possible, with a Dockerfile like the following:

```dockerfile
# Dockerfile

# Create a virtual environment and install dependencies
# * Only re-execute this step when pyproject.toml changes
FROM python:3.12 AS build-reqs
WORKDIR /app
COPY pyproject.toml pyproject.toml
RUN python -m venv /venv
RUN /venv/bin/python -m pip install -U setuptools wheel
RUN /venv/bin/pip install -q .

# Build binary for the package and install code
# * The README.md is required for the long description
FROM build-reqs AS build-app
COPY src src
COPY README.md README.md
RUN /venv/bin/pip install .

# Copy the virtualenv into a distroless image
# * These are small images that only contain the runtime dependencies
FROM gcr.io/distroless/python3-debian11
WORKDIR /app
COPY --from=build-app /venv /venv
ENTRYPOINT ["/venv/bin/coolprojectcli"]
```

There's a few nuances in here.

1. `RUN /venv/bin/pip install -q .`: Here we only install the core dependencies in order to keep
    our virtual environment as small as possible. Also it is worth noting that since we have
    specified a script with an entrypoint to the program at `my_package.main:main`, but we have not
    passed the codebase to this stage of the Dockerfile, any attempts at using our entrypoint at
    this layer will fail.
2. `RUN /venv/bin/pip install .`: Since we didn't build the script for our library earlier, we must
    do so now with another call to `pip install` after copying over the source code. This won't
    reinstall any of the dependencies, since they were already downloaded into the virtual
    environment in the previous layer.
3. `FROM gcr.io/distroless/python3-debian11`: In order to improve the security and reduce the size
    of our final container[[28]](https://github.com/GoogleContainerTools/distroless), we use a
    distroless image, just including the runtime dependencies by copying the virtual environment
    from the `build-app` stage.
4. `ENTRYPOINT ["/venv/bin/coolprojectcli"]`: We leverage the script we specified [earlier](#entrypoints)
    to make the Dockerfile act akin to the instantiation of the script itself. In this manner,
    whatever we tag the built image as can be used as a stand-in for the `coolprojectcli` binary.

For example, we can now build and tag the container using

```bash
$ docker build . -t coolprojectdocker:local
```

And (as mentioned above) since the entrypoint of the Dockerfile is the script we specified,
running the built image works akin to the script; no extra commands required:

```bash
$ docker run coolprojectdocker:local -h
usage: coolprojectcli [-h] echo

positional arguments:
  echo        String to print back to the console

options:
  -h, --help  show this help message and exit
```


## Bonus: Efficient GitHub Actions usage

Yes, there are other CI tools - but as with our selection of build frontends and backends, it's
most likely that you are personally using GitHub Actions[[29]](https://www.jetbrains.com/lp/devecosystem-2023/team-tools/#ci_tools),
so we'll focus on that here. Imagine the scenario where, even with a keen eye on external
dependency sizes and namespacing them to optional subsets, our CI pipeline is repeatedly eating up
several minutes of developer time building the virtual environment for the application. Is there a
way to speed this up? Well, yes, and much like with the Dockerfile above it incorporates a similar
separation of concerns to allow for the leveraging of a cache.

Consider two jobs, one to run tests and one to build and publish the wheel to PyPi. Currently, both
steps build the virtual environment from scratch:

```yaml
name: Python CI
on: ["push"]

jobs:
  test-unit:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Install requirements
        run: pip install .[test]
      - name: Run tests
        run: pytest .

  publish-wheel:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Install requirements
        run: pip install .
      - name: Build wheel
        run: python -m pip wheel . --wheel-dir dist
      - name: Publish wheel
        uses: pypa/gh-action-pypi-publish@v1.8.10
        with:
          user: __token__
          password: ${{ secrets.PYPI_API_TOKEN }}
```

Clearly, there's some inefficiencies here. Both jobs install similar sets of dependencies,
duplicating work and doubling wait times. Also, this is running on every CI invocation, regardless
of whether the dependencies of the project have actually changed or not! Lets address these issues
by including a new job, `build-venv`, who's job is solely to construct and cache the virtual
environment. It will only do so if the `pyproject.toml` file has changed, otherwise it should opt
to use the previously cached version of the virtual environment. Subsequent jobs can then use this
cached environment instead of building their own from scratch.

```yaml
name: Python CI
on: ["push"]

jobs:
  build-venv:
    runs-on: ubunut-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
      # Restore cached virtualenv, if available
      # * The pyproject.toml hash is part of the cache key, invalidating
      #   the cache if the file changes
      - name: Restore cached virtualenv
        id: restore-cache
        uses: actions/cache/restore@v3
        with:
          path: ./venv
          key: ${{ runner.os }}-venv-${{ hashFiles('**/pyproject.toml') }}
      # If a previous cache wasn't restored (pyproject has changed), build the venv
      # * Make the venv at `./venv` to ensure compatibility with runners
      - name: Build venv
        run: |
          python -m venv ./venv
          ./venv/bin/python -m pip install .[test]
        if: steps.restore-cache.outputs.cache-hit != 'true'
      # Cache the built virtualenv for future runs
      - name: Cache virtualenv
        uses: actions/cache/save@v3
        with:
          path: ./venv
          key: ${{ steps.restore-cache.outputs.cache-primary-key }}
        if: steps.restore-cache.outputs.cache-hit != 'true'
```

Now, the `test-unit` and `publish-wheel` jobs can use this environment, restoring from the cache:

```
jobs:
  build-venv: ...

  test-unit:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Restore cached virtualenv
        uses: actions/cache/restore@v3
        with:
          path: ./venv
          key: ${{ runner.os }}-venv-${{ hashFiles('**/pyproject.toml') }}
      - name: Install package
        run: ./venv/bin/python -m pip install .
      - name: Run tests
        run: pytest .

  publish-wheel:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Restore cached virtualenv
        uses: actions/cache/restore@v3
        with:
          path: ./venv
          key: ${{ runner.os }}-venv-${{ hashFiles('**/pyproject.toml') }}
      - name: Build wheel
        run: ./venv/bin/python -m pip wheel . --wheel-dir dist
      - name: Publish wheel
        uses: pypa/gh-action-pypi-publish@v1.8.10
        with:
          user: __token__
          password: ${{ secrets.PYPI_API_TOKEN }}
```

I know what you're thinking: *We're still running pip install in the test-unit job! What gives?*
Good spot, it's true - and in fact it's completely necessary. Running pip install at this point,
after restoring the cached virtual environment, will take no time at all, as all the dependencies
are already installed. `pip` will see this, and promptly skip reinstallation, so we don't lose any
time here. But we have to install the package here as, whilst the dependencies and so the virtual
environment might not have changed here, the source code almost certainly will have. As such,
running `pip install` again here ensures we are using an up to date version of the repository in
our testing.

I know what else you're thinking: *Why did we bother to separate dependencies out if we're going to
build the wheel using a virtual environment with the test dependencies installed?* Another good
spot! We did install the test requirements into the cached virtual environment. It's okay to do this
because `pip wheel` will only look for what is specified in the `dependencies` section to include
as dependencies of the wheel. Our wheel stays no bigger than the size it needs to be!

## Bonus: Automatic semantic versioning

One final bonus feature of `pyproject.toml` is the ability to automatically version your package
using the `version` key in the `[project]` section. This can be done, without any
`.bumpversion.cfg` or similar files, by using the [setuptools-git-verioning](https://setuptools-git-versioning.readthedocs.io/en/v2.1.0/)
package.

This tool uses regular git tags to determine the version of the package, and is installed by
modifying the `[build-system]` table at the top of the `pyproject.toml` file:

```toml
[build-system]
requires = ["setuptools>=67", "wheel", "setuptools-git-versioning>=2.0,<3"]
build-backend = "setuptools.build_meta"
```

We also have to tell `setuptools` to use this tool when determining the version, via

```toml
[project]
# version = "0.1.0" Remove this line
dynamic = ["version"] # Add this line

[tool.setuptools-git-versioning]
enabled = true
```

Now, when your package is built, `setuptools` will look at your git tags and determine the version
according to your proximity to the latest one. This can be retrieved at runtime using `importlib`:

```python
from importlib.metadata import PackageNotFoundError, version

# Get package version
try:
    __version__ = version("cloudcasting-app")
except PackageNotFoundError:
    __version__ = "v?"

print(__version__)
```

Changing the version can be done by making a new tag:

```sh
$ git tag -a v0.2.0 -m "Minor changes for 0.2.0"
$ git push --follow-tags
```

But doing this manually is a not a necessary chore at all! To automatically bump the version, for
instance on merges to a main branch, use a job like the following in GitHub actions:

```yaml
name: Default Branch PR Merged CI

on:
  pull_request:
    types: ["closed"]
    branches: ["main"]

jobs:

  # Define an autotagger job that creates tags on changes to master
  # Use #major #minor in merge commit messages to bump version beyond patch
  bump-tag:
    runs-on: ubuntu-latest
    if: |
      github.event_name == 'pull_request' && 
      github.event.action == 'closed' && 
      github.event.pull_request.merged == true
    permissions:
      contents: write
    outputs:
      tag: ${{ steps.tag.outputs.tag }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Bump version and push tag
        uses: anothrNick/github-tag-action@1.67.0
        id: tag
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          RELEASE_BRANCHES: main
          WITH_V: true
          DEFAULT_BUMP: patch
          GIT_API_TAGGING: false
```

This will do a patch bump by default, but you can specify a major or minor bump by including
`#major` or `#minor` in the merge commit message. No more thinking about versioning!

Now all your misgivings have been allayed, I hope that the next time you have to set up a Python
project, you'll feel comfortable doing so using `pyproject.toml`.
