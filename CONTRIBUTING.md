Issue Guidelines
================

1. Issues should only be created for things that are definitely bugs.  If you
   are not sure that the behavior is a bug, ask about it on the [ruby-shrine]
   Google Group.

2. If you are sure it is a bug, then post a complete description of
   the issue, the simplest possible self-contained example showing
   the problem, and the full backtrace of any exception.

Pull Request Guidelines
=======================

1. Try to include tests for all new features and substantial bug
   fixes.

2. Try to include documentation for all new features.  In most cases
   this should include RDoc method documentation, but updates to the
   README is also appropriate in some cases.

3. Follow the style conventions of the surrounding code.  In most
   cases, this is standard ruby style.

Running tests
=============

The test suite requires that you have ImageMagick, libmagic and SQLite installed.
If you're using Homebrew, you can just run:

```sh
$ brew bundle
```

The test suite is best run using Rake:

```sh
$ rake test
```

You can also automatically run tests accross Ruby versions:

```sh
$ bin/test-versions
```

Code of Conduct
===============

Everyone interacting in the Shrine project’s codebases, issue trackers, chat
rooms, and mailing lists is expected to follow the [Shrine code of conduct].

[ruby-shrine]: https://groups.google.com/forum/#!forum/ruby-shrine
[Shrine code of conduct]: https://github.com/janko-m/shrine/blob/master/CODE_OF_CONDUCT.md
