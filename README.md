# domain-sift

`domain-sift` is a Perl script that extracts unique domains from
at least one provided file and prints them to standard output. If
no file is provided, domain-sift reads from standard input instead.

One use of this utility is to extract domains from blocklists
that contain known malicious or otherwise undesirable domains,
and then format them in such a way that those domains can be
blocked by a DNS resolver.

## Table of Contents

1. [Project structure](#project-structure)
2. [Installation](#installation)
3. [Documentation](#documentation)
4. [domain-sift and unwind](#domain-sift-and-unwind)
5. [domain-sift and unbound](#domain-sift-and-unbound)
6. [domain-sift and a Response Policy Zone (RPZ)](#domain-sift-and-a-response-policy-zone-rpz)
7. [License](#license)

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

## Installation

To install domain-sift, run the following commands:

```
$ perl Makefile.PL
$ make
$ make test
$ make install
```

## Documentation

After installation, you can read the documentation with `perldoc`.
`man` often works as well.

```
$ perldoc Domain::Sift
$ perldoc Domain::Sift::Match
$ perldoc Domain::Sift::Manipulate
$ perldoc domain-sift
```

## domain-sift and unwind

To use `domain-sift` with `unwind.conf(5)`, you need to generate
the blocklist in `plain` format, which is the default setting of
`domain-sift`.

Here are the steps to follow:

1. Generate your blocklist:

```
$ domain-sift /path/to/blocklist_source > blocklist
```

2. Then, modify your `unwind.conf` to include this blocklist:

```
block list "/path/to/blocklist"
```

## domain-sift and unbound

`domain-sift` has the `unbound` output format, which generates a
blocklist that's compatible with `unbound.conf(5)`.

Here are the steps:

1. Generate your blocklist:

```
$ domain-sift -f unbound /path/to/blocklist_source > blocklist
```

2. Then, include the generated blocklist file in your `unbound.conf`:

```
include: "/path/to/blocklist"
```

## domain-sift and a Response Policy Zone (RPZ)

`domain-sift` also supports the Response Policy Zone (RPZ) format.
[RPZ is defined in this Internet
Draft](https://datatracker.ietf.org/doc/draft-vixie-dnsop-dns-rpz/).
By using RPZ, you can define DNS blocking policies in a standardized
way. A nice perk of using RPZ is the ability to block wildcarded
domains.

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
runs on the gateway/router, ensure that a `local-data` entry is
present somewhere so that the name you chose resolves. Something
like this should work:

```
local-data: "rpz.home.arpa. IN A x.x.x.x"
```

You'll need to replace `x.x.x.x` with the machine's actual IP
address.

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

This software is Copyright © 2023 by Ashlen.

This is free software, licensed under the ISC License. For more
details, see the `LICENSE` file in the project root.
