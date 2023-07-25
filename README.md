# Domain-Sift

This is a collection of Perl code used for matching, manipulating, and
sifting through domains. Included in this repository along with reusable
modules is `domain-sift`, a script to extract domains and print them out
in several different formats.

## Table of Contents

1. [Installation](#installation)
2. [Documentation](#documentation)
3. [Project structure](#project-structure)
4. [domain-sift](#domain-sift)
    - [Using domain-sift with unwind](#using-domain-sift-with-unwind)
    - [Using domain-sift with unbound](#using-domain-sift-with-unbound)
    - [Using domain-sift with a Response Policy Zone](#using-domain-sift-with-a-response-policy-zone-rpz)
5. [License](#license)

## Installation

To install this module, run the following commands:

```
perl Makefile.PL
make
make test
make install
```

## Documentation

After installing, you can find documentation for relevant modules and
scripts with `perldoc`. `man` often works as well.

```
perldoc Domain::Sift
perldoc Domain::Sift::Match
perldoc Domain::Sift::Manipulate
perldoc domain-sift
```

## Project structure

```
|-- Changes
|-- LICENSE
|-- MANIFEST
|-- Makefile.PL
|-- README.md
|-- bin
|   `-- domain-sift
|-- lib
|   `-- Domain
|       |-- Sift
|       |   |-- Manipulate.pm
|       |   `-- Match.pm
|       `-- Sift.pm
`-- t
    |-- 00-load.t
    |-- Domain-Sift-Manipulate.t
    |-- Domain-Sift-Match.t
    |-- manifest.t
    |-- pod-coverage.t
    `-- pod.t
```

## domain-sift

The `domain-sift` utility extracts unique domains from at least one
provided file and prints them to standard output. If no file is
provided, domain-sift reads from standard input instead.

One use of this utility is to extract domains from blocklists
that contain known malicious or otherwise undesirable domains,
and then format them in such a way that those domains can be
blocked by a DNS resolver.

### Using domain-sift with unwind

To use `domain-sift` with `unwind.conf(5)`, you need to generate the blocklist
in `plain` format, which is the default setting of `domain-sift`.

Here are the steps to follow:

1. Generate your blocklist:

```
$ domain-sift /path/to/blocklist_source > blocklist
```

2. Then, modify your `unwind.conf` to include this blocklist:

```
block list "/path/to/blocklist"
```

### Using domain-sift with unbound

`domain-sift` has the `unbound` output format, which generates a blocklist
that's compatible with `unbound.conf(5)`.

Here are the steps:

1. Generate your blocklist:

```
$ domain-sift -f unbound /path/to/blocklist_source > blocklist
```

2. Then, include the generated blocklist file in your `unbound.conf`:

```
include: "/path/to/blocklist"
```

### Using domain-sift with a Response Policy Zone (RPZ)

`domain-sift` also supports the Response Policy Zone (RPZ) format. [RPZ is
defined in this Internet
Draft](https://datatracker.ietf.org/doc/draft-vixie-dnsop-dns-rpz/). By
using RPZ, you can define DNS blocking policies in a standardized way. A
nice perk of using RPZ is the ability to block wildcarded domains.

Here are the steps to generate and use RPZ with Unbound:

1. Generate your blocklist:

```
$ domain-sift -f rpz /path/to/blocklist_source > blocklist
```

2. Place the following in `unbound.conf`

```
rpz:
  name: rpz.home.arpa
  zonefile: /var/unbound/etc/rpz-block.zone
  #rpz-log: yes
  rpz-signal-nxdomain-ra: yes
```

NOTE: `rpz.home.arpa` is just an example. The name entry may be
different in your case. In a local access network (LAN) where Unbound
runs on the gateway/router, ensure that a `local-data` entry is present
somewhere so that the name you chose resolves. Something like this
should work:

```
local-data: "rpz.home.arpa. IN A x.x.x.x"
```

You'll need to replace `x.x.x.x` with the machine's actual IP address.

3. Create `/var/unbound/etc/rpz-block.zone`:

```
$ORIGIN rpz.home.arpa.
$INCLUDE /var/unbound/etc/blocklist
```

4. Make sure that you move `blocklist` to the correct location.

```
# mv /path/to/blocklist /var/unbound/etc/blocklist
```

## License

This software is Copyright (c) 2023 by Ashlen.

This is free software, licensed under the ISC License. For more details,
see the `LICENSE` file in the project root.
