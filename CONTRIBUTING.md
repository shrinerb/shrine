Issue Guidelines
================

1. Issues should only be created for things that are definitely bugs.  If you
   are not sure that the behavior is a bug, ask about it on the [forum] or on [Github Discussions]. Otherwise Github gets overwhelmed with issues and it is very difficult for the maintainers to manage.

2. If you are sure it is a bug, then post a complete description of the issue,
   the simplest possible [self-contained example] showing the problem (please do review the link), and the full backtrace of any exception.

Pull Request Guidelines
=======================

1. Try to include tests for all new features and substantial bug
   fixes.

2. Try to include documentation for all new features.  In most cases
   this should include RDoc method documentation, but updates to the
   README is also appropriate in some cases.

3. Follow the style conventions of the surrounding code.  In most
   cases, this is standard ruby style.

Understanding the codebase
==========================

* The [Design of Shrine] guide gives a general overview of Shrine's core
classes.

* The [Creating a New Plugin] guide and the [Plugin system of Sequel and Roda]
  article explain how Shrine's plugin system works.

* The [Notes on study of shrine implementation] article gives an in-depth
  walkthrough through the Shrine codebase.

Running tests
=============

The test suite requires that you have the following installed:

* [libmagic]
* [SQLite]
* [libvips] - please download the appropriate package suiting your operating system.

With Hombrew this would be:

```sh
$ brew install libmagic sqlite libvips
```

The test suite is best run using Rake:

```
$ rake test
```

Code of Conduct
===============

Everyone interacting in the Shrine project’s codebases, issue trackers, chat
rooms, and mailing lists is expected to follow the [Shrine code of conduct].

[Github Discussions]: https://github.com/shrinerb/shrine/discussions
[forum]: https://discourse.shrinerb.com
[Shrine code of conduct]: https://github.com/shrinerb/shrine/blob/master/CODE_OF_CONDUCT.md
[libmagic]: https://github.com/threatstack/libmagic
[libvips]: https://github.com/libvips/libvips/wiki
[SQLite]: https://www.sqlite.org
[Design of Shrine]: /doc/design.md#readme
[Creating a New Plugin]: /doc/creating_plugins.md#readme
[Plugin system of Sequel and Roda]: https://twin.github.io/the-plugin-system-of-sequel-and-roda/
[Notes on study of shrine implementation]: https://bibwild.wordpress.com/2018/09/12/notes-on-study-of-shrine-implementation/
[self-contained example]: https://github.com/shrinerb/shrine/blob/master/SELF_CONTAINED_EXAMPLE.md
