[![Actions Status](https://github.com/lizmat/VERS/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/VERS/actions) [![Actions Status](https://github.com/lizmat/VERS/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/VERS/actions) [![Actions Status](https://github.com/lizmat/VERS/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/VERS/actions)

NAME
====

VERS - Support for the VErsion Range Specifier URI scheme

SYNOPSIS
========

```raku
use VERS;

my $vers = VERS.new("vers:raku/>=1.0");
say v1.0 ~~ $vers;  # True
say v0.9 ~~ $vers;  # False
```

DESCRIPTION
===========

The `VERS` distribution provides an implementation of the **VE**rsion **R**ange **S**pecifier scheme, as described in the [PURL specification](https://github.com/package-url/purl-spec/blob/main/VERSION-RANGE-SPEC.rst).

It is intended to provide support for version checking for all software types supported by the [Package URL standard](https://github.com/package-url/purl-spec/tree/main?tab=readme-ov-file#context).

It currently supports all software packages that use the same version logic as Raku (based on [Version](https://docs.raku.org/type/Version) object comparison semantics).

VERS
====

```raku
my $vers = VERS.new("vers:raku/>=1.0");
say v1.0 ~~ $vers;  # True
say v0.9 ~~ $vers;  # False
```

The `Vers` class encapsulates the logic for parsing [VERS specification strings](https://github.com/package-url/purl-spec/blob/main/VERSION-RANGE-SPEC.rst#version-constraint) and is intended to be used as a target in a smart-match to verify whether a given version is matched by the `vers` specification.

An error will be thrown if the given `vers` specification is not valid.

The `VERS` object stringifies to the canonical representation of the `vers` specification.

    say VERS("vers:raku/>=1.0");  # True
    say VERS("foobar");           # False

If one is only interested in whether a `vers` string is valid or not, one can call the `VERS` class object with the `vers` string: it will return `True` if the `vers` string is valid, and `False` if it is not.

method new
----------

```raku
# accept any version 1.x below 2.0
my $from-string = VERS.new("vers:raku/>=1.0|<2.0");

my $from-nameds = VERS.new(:type<raku>, :constraints(v1.0+, "<2.0"));
```

The `new` method can be called to create a new `VERS` object. It either takes a `vers` specification string, or it can be called using normal named arguments semantics. In the latter case, it expects the `:type` and `:constraints` named arguments to be specified. Note that when using named arguments, the `:constraints` named arguments expects one of more strings or `Version` objects.

method from-Version
-------------------

```raku
# accept any version equal to or higher than 1.x
my $vers = VERS.from-Version(v1.0+);
say $vers;  # vers:raku/>=1.0
```

The `from-Version` method can be called to create a new `VERS` object from a `Version` object.

HELPER CLASSES
==============

VersionConstraint
-----------------

```raku
my $from-spec = VersionConstraint.new("!=1.0");

my $from-nameds = VersionConstraint.new(
  :comparator<!=>, :version<1.0>
);
```

The `VersionConstraint` class encapsulates the logic needed to check a single constraint. Its instances can be used as arguments to the `:constraints` named argument to `VERS.new`.

It can either be instantiated by a `vers` version constraint, or by named arguments. In the latter case, the optional `:comparator` named argument expects a string representing the comparator to be used (any of: `==`, `!=`, `<`, `<=`, `>`, `>=`, defaulting to `==`). The required `:version` named argument should be either a `Version` object or a string representing a version.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/VERS . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2025 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

