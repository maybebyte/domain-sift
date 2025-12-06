#!/usr/bin/env perl
# Copyright (c) 2023-2025 Ashlen <dev@anthes.is>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use v5.36;
use autodie;

use Test::More;

BEGIN {
	use_ok('Domain::Sift::Match') || print "Bail out!\n";
}

subtest 'has_valid_tld' => sub {
	my $match = Domain::Sift::Match->new();

	# Valid TLDs
	ok(
		$match->has_valid_tld("example.com"),
		"example.com contains a valid TLD"
	);
	ok(
		$match->has_valid_tld("google.co.uk"),
		"google.co.uk contains a valid TLD"
	);
	ok(
		$match->has_valid_tld("stackoverflow.net"),
		"stackoverflow.net contains a valid TLD"
	);

	# Invalid TLDs
	ok( !$match->has_valid_tld("example"), "example is not a valid TLD" );
	ok(
		!$match->has_valid_tld("stackoverflow"),
		"stackoverflow is not a valid TLD"
	);
	ok( !$match->has_valid_tld("lwq"), "lwq is not a valid TLD" );
};

subtest 'contains_domain' => sub {
	my $match = Domain::Sift::Match->new();

	# Valid domains
	ok( $match->contains_domain("example.com"), "Valid domain" );
	ok( $match->contains_domain("subdomain.example.com"),
		"Valid domain with subdomain" );
	ok( $match->contains_domain("xn--fiq228c.com"),
		"Valid punycode domain" );

	# Invalid domains
	ok( !$match->contains_domain("example"), "Invalid domain" );
	ok(
		!$match->contains_domain("example..com"),
		"Invalid domain with double dot"
	);
	ok(
		!$match->contains_domain("example_com"),
		"Invalid domain with underscore"
	);
	ok(
		!$match->contains_domain("example.qrf"),
		"Invalid domain with bogus top-level domain (qrf)"
	);
};

subtest 'extract_domain' => sub {
	my $match = Domain::Sift::Match->new();

	# Chomp trailing newlines
	is( $match->extract_domain("example.com\n"),
		"example.com", "Trailing newlines should be chomped" );

	# Commented lines
	is( $match->extract_domain("# example.com"),
		undef, "Commented line should be skipped (space between)" );
	is( $match->extract_domain("#example.com"),
		undef, "Commented line should be skipped (no space between)" );
	is( $match->extract_domain( " " x 5 . "# example.com" ),
		undef, "Commented line should be skipped (5 spaces)" );
	is( $match->extract_domain( "\t" x 5 . "# example.com" ),
		undef, "Commented line should be skipped (5 tabs)" );
	is( $match->extract_domain( " \t" x 5 . "# example.com" ),
		undef, "Commented line should be skipped (5 spaces + 5 tabs)" );

	# Blank lines
	is( $match->extract_domain(""),
		undef, "Blank line should be skipped (empty string)" );
	is( $match->extract_domain("\n"),
		undef, "Blank line should be skipped (newline)" );
	is( $match->extract_domain( " " x 5 ),
		undef, "Blank line should be skipped (5 spaces)" );
	is( $match->extract_domain( "\t" x 5 ),
		undef, "Blank line should be skipped (5 tabs)" );
	is( $match->extract_domain( " \t" x 5 ),
		undef, "Blank line should be skipped (5 spaces + 5 tabs)" );
	is( $match->extract_domain(" \t\n"),
		undef, "Blank line should be skipped (space + tab + newline)" );

	# Leading IP addresses
	is( $match->extract_domain("127.0.0.1 example.com"),
		"example.com", "Leading 127.0.0.1 should be ignored" );
	is( $match->extract_domain(" \t127.0.0.1 \texample.com"),
		"example.com",
		"Leading 127.0.0.1 should be ignored (spaces + tabs)" );
	is( $match->extract_domain("0.0.0.0 example.com"),
		"example.com", "Leading 0.0.0.0 should be ignored" );
	is( $match->extract_domain(" \t0.0.0.0 \texample.com"),
		"example.com",
		"Leading 0.0.0.0 should be ignored (spaces + tabs)" );

	# IP at end of word (invalid)
	is( $match->extract_domain("example.com127.0.0.1"),
		undef,
		"Line with 127.0.0.1 at the end of a word should be skipped" );
	is( $match->extract_domain("example.com0.0.0.0"),
		undef, "Line with 0.0.0.0 at the end of a word should be skipped" );

	# Case normalization
	is( $match->extract_domain("EXAMPLE.COM"),
		"example.com", "EXAMPLE.COM should be converted to example.com" );

	# Long lines
	is(
		$match->extract_domain(
			"A" x 1024 . " " . "example.com" . " " . "A" x 1024
		),
		"example.com",
		"Extracts domains out of longer lines"
	);
};

subtest 'has_valid_tld edge cases' => sub {
	my $match = Domain::Sift::Match->new();

	# Uppercase TLDs
	ok( $match->has_valid_tld("example.COM"),
		"Uppercase TLD: example.COM" );
	ok(
		$match->has_valid_tld("example.CoM"),
		"Mixed case TLD: example.CoM"
	);

	# Punycode TLDs (internationalized)
	ok(
		$match->has_valid_tld("example.xn--fiqs8s"),
		"Punycode TLD: xn--fiqs8s (Chinese)"
	);
	ok( $match->has_valid_tld("example.xn--vermgensberatung-pwb"),
		"Long punycode TLD" );

	# Empty string
	ok( !$match->has_valid_tld(""), "Empty string returns false" );

	# No period
	ok( !$match->has_valid_tld("examplecom"), "No period returns false" );

	# Just a dot
	ok( !$match->has_valid_tld("."), "Just a dot returns false" );

	# Trailing dot (FQDN format)
	ok(
		!$match->has_valid_tld("example.com."),
		"Trailing dot returns false (empty TLD)"
	);
};

subtest 'contains_domain edge cases' => sub {
	my $match = Domain::Sift::Match->new();

	# Hyphenated domains
	is( $match->contains_domain("my-domain.com"),
		"my-domain.com", "Hyphenated domain: my-domain.com" );
	is( $match->contains_domain("a-b-c.example.com"),
		"a-b-c.example.com", "Multiple hyphens in subdomain" );

	# Leading hyphen - skips invalid prefix, extracts valid domain
	is( $match->contains_domain("-domain.com"),
		"domain.com", "Leading hyphen: extracts domain.com" );

	# Numeric subdomains
	is( $match->contains_domain("123.example.com"),
		"123.example.com", "Numeric subdomain: 123.example.com" );
	is( $match->contains_domain("192-168-1-1.example.com"),
		"192-168-1-1.example.com", "IP-like subdomain with hyphens" );

	# Underscore prefix - extracts valid portion
	is( $match->contains_domain("_dmarc.example.com"),
		"example.com", "Underscore prefix: extracts example.com" );
	is( $match->contains_domain("_spf.mail.example.com"),
		"mail.example.com", "Underscore prefix with subdomain" );

	# Label length edge cases (max 63 chars per label)
	my $label_63 = "a" x 63;
	is( $match->contains_domain("$label_63.com"),
		"$label_63.com", "63-char label is valid" );

	my $label_64 = "a" x 64;
	ok(
		!$match->contains_domain("$label_64.com"),
		"64-char label is invalid (no match)"
	);

	# Single-character labels
	is( $match->contains_domain("a.b.com"),
		"a.b.com", "Single-char labels: a.b.com" );
	is( $match->contains_domain("x.y.z.com"),
		"x.y.z.com", "Multiple single-char labels" );

	# Deep nesting
	is( $match->contains_domain("a.b.c.d.example.com"),
		"a.b.c.d.example.com", "Deep nesting: 5 levels" );
	is(
		$match->contains_domain("one.two.three.four.five.six.com"),
		"one.two.three.four.five.six.com",
		"Deep nesting: 6 levels"
	);

	# Domain embedded in text
	is( $match->contains_domain("Visit example.com today!"),
		"example.com", "Domain embedded in sentence" );
	is( $match->contains_domain("Go to https://www.example.com/path"),
		"www.example.com", "Domain in URL context" );

	# Trailing hyphen - should not match
	ok(
		!$match->contains_domain("domain-.com"),
		"Trailing hyphen in label is invalid"
	);
};

subtest 'extract_domain edge cases' => sub {
	my $match = Domain::Sift::Match->new();

	# Comment after domain
	is( $match->extract_domain("example.com # comment"),
		"example.com", "Comment after domain: extracts domain" );
	is( $match->extract_domain("example.com#nocomment"),
		"example.com", "Hash without space after domain" );

	# Multiple domains (extracts first valid one)
	is( $match->extract_domain("example.com test.org another.net"),
		"example.com", "Multiple domains: extracts first" );

	# Windows line endings
	is( $match->extract_domain("example.com\r\n"),
		"example.com", "Windows line endings (CRLF)" );
	is( $match->extract_domain("example.com\r"),
		"example.com", "Carriage return only" );

	# Tab-separated with trailing data
	is( $match->extract_domain("example.com\t127.0.0.1"),
		"example.com", "Tab-separated: domain then IP" );
	is( $match->extract_domain("example.com\tsome text here"),
		"example.com", "Tab-separated: domain then text" );

	# IP followed by whitespace only
	is( $match->extract_domain("127.0.0.1   "),
		undef, "IP followed by whitespace only returns undef" );
	is( $match->extract_domain("0.0.0.0\t\t"),
		undef, "IP followed by tabs only returns undef" );

	# Mixed case normalization
	is( $match->extract_domain("SUBDOMAIN.EXAMPLE.COM"),
		"subdomain.example.com", "Full uppercase normalized to lowercase" );
	is( $match->extract_domain("SubDomain.Example.Com"),
		"subdomain.example.com", "Mixed case normalized to lowercase" );

	# Punycode domains
	is( $match->extract_domain("xn--nxasmq5b.com"),
		"xn--nxasmq5b.com", "Punycode subdomain" );

	# Domain with valid punycode TLD
	is( $match->extract_domain("example.xn--fiqs8s"),
		"example.xn--fiqs8s", "Domain with punycode TLD" );
};

subtest 'extract_domain performance baseline' => sub {
	use Time::HiRes qw(time);

SKIP: {
		skip "Performance tests skipped in CI", 1 if $ENV{CI};

		my $match = Domain::Sift::Match->new();
		my @test_lines = map { "test$_.com" } ( 1 .. 1_000_000 );

		my $start = time();
		my $count = 0;
		for my $line (@test_lines) {
			my $domain = $match->extract_domain($line);
			$count++ if $domain;
		}
		my $elapsed = time() - $start;

		is( $count, 1_000_000, "Extracted 1 million domains" );
		diag("Baseline: ${elapsed}s for 1 million domains");
		diag( "Throughput: "
				. sprintf( "%.0f", 1_000_000 / $elapsed )
				. " domains/second" );
	}
};

subtest 'constructor performance' => sub {
	use Time::HiRes qw(time);

SKIP: {
		skip "Performance tests skipped in CI", 1 if $ENV{CI};

		my $start = time();
		for ( 1 .. 100_000 ) {
			my $match = Domain::Sift::Match->new();
		}
		my $elapsed = time() - $start;

		pass("Constructor instantiation timing captured");
		diag("100 thousand instantiations: ${elapsed}s");
	}
};

subtest 'cached pattern equivalence' => sub {
	my $match = Domain::Sift::Match->new();

	my @test_cases = (
		[ 'example.com', 'example.com' ],
		[ 'sub.example.com', 'sub.example.com' ],
		[ '_dmarc.example.com', 'example.com' ],
		[ '-bad.com', 'bad.com' ],
		[ 'no-valid-tld.xyz123', undef ],
		[ '127.0.0.1', undef ],
		[ 'a' x 64 . '.com', undef ],
		[ 'a' x 63 . '.com', 'a' x 63 . '.com' ],
	);

	for my $case (@test_cases) {
		my ( $input, $expected ) = @$case;
		is( $match->contains_domain($input),
			$expected, "contains_domain('$input')" );
	}
};

subtest 'no circular references' => sub {
	use Scalar::Util qw(weaken);

	my $match = Domain::Sift::Match->new();
	my $weak_ref = $match;
	weaken($weak_ref);

	undef $match;
	ok( !defined $weak_ref, "Object garbage collected (no circular refs)" );
};

done_testing();
