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

subtest 'TLD file loading' => sub {
	my $match = Domain::Sift::Match->new();
	# Verify reasonable TLD count (IANA has ~1,400+)
	# Access via object instance since %valid_tlds is lexical
	cmp_ok( scalar keys $match->{valid_tlds}->%*, '>', 1200,
		'TLD count exceeds 1200 (IANA baseline)' );
};

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

	# Underscore prefix - RFC 8552 service records preserved
	is( $match->contains_domain("_dmarc.example.com"),
		"_dmarc.example.com", "Underscore prefix: preserves _dmarc" );
	is( $match->contains_domain("_spf.mail.example.com"),
		"_spf.mail.example.com", "Underscore prefix with subdomain preserved" );

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
	is( $match->extract_domain("_DMARC.EXAMPLE.COM"),
		"_dmarc.example.com", "Underscore domain normalized to lowercase" );

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
		[ '_dmarc.example.com', '_dmarc.example.com' ],
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

subtest 'contains_domains (multi-domain)' => sub {
	my $match = Domain::Sift::Match->new();

SKIP: {
		skip "contains_domains not yet implemented", 1
			unless $match->can('contains_domains');

		is_deeply(
			[ $match->contains_domains("example.com test.org") ],
			[qw(example.com test.org)],
			"contains_domains finds multiple domains"
		);
	}
};

subtest 'extract_domains (multi-domain)' => sub {
	my $match = Domain::Sift::Match->new();

SKIP: {
		skip "extract_domains not yet implemented", 19
			unless $match->can('extract_domains');

		is_deeply(
			[ $match->extract_domains("example.com example.net example.org") ],
			[qw(example.com example.net example.org)],
			"Extracts multiple space-separated domains"
		);

		is_deeply(
			[ $match->extract_domains("google.com\tfacebook.com") ],
			[qw(google.com facebook.com)],
			"Extracts multiple tab-separated domains"
		);

		is_deeply(
			[ $match->extract_domains("bing.com") ],
			[qw(bing.com)],
			"Single domain returns single-element list"
		);

		is_deeply(
			[ $match->extract_domains("# comment") ],
			[],
			"Comment line returns empty list"
		);

		is_deeply(
			[ $match->extract_domains("block example.com and test.org now") ],
			[qw(example.com test.org)],
			"Extracts domains embedded in text"
		);

		is_deeply(
			[ $match->extract_domains("127.0.0.1 example.com example.net") ],
			[qw(example.com example.net)],
			"Handles leading IP with multiple domains"
		);

		is_deeply(
			[ $match->extract_domains("EXAMPLE.COM Test.ORG") ],
			[qw(example.com test.org)],
			"Normalizes case for all extracted domains"
		);

		is_deeply(
			[ $match->extract_domains("example.com test.org example.com") ],
			[qw(example.com test.org example.com)],
			"Duplicate domains are preserved in output"
		);

		is_deeply(
			[ $match->extract_domains("just some random text") ],
			[],
			"Text with no domains returns empty list"
		);

		is_deeply(
			[ $match->extract_domains("") ],
			[],
			"Empty string returns empty list"
		);

		is_deeply(
			[ $match->extract_domains("   \t   ") ],
			[],
			"Whitespace-only returns empty list"
		);

		# Embedded IPs are skipped (not valid domains), valid domains still extracted
		is_deeply(
			[ $match->extract_domains("example.com 127.0.0.1 test.org") ],
			[qw(example.com test.org)],
			"Skips space-separated IP, extracts valid domains"
		);

		# IP directly adjacent to text (no space) rejects entire line
		is_deeply(
			[ $match->extract_domains("evil127.0.0.1.com") ],
			[],
			"Rejects line with IP adjacent to text"
		);

		is_deeply(
			[ $match->extract_domains("example.com,test.org;another.net") ],
			[qw(example.com test.org another.net)],
			"Extracts domains separated by punctuation"
		);

		is_deeply(
			[ $match->extract_domains("example.com test.org\r\n") ],
			[qw(example.com test.org)],
			"Handles CRLF with multiple domains"
		);

		is_deeply(
			[ $match->extract_domains("example.com fake.invalidtld test.org") ],
			[qw(example.com test.org)],
			"Skips domains with invalid TLDs"
		);

		my $many_domains = join( " ", map { "domain$_.com" } ( 1 .. 100 ) );
		my @extracted = $match->extract_domains($many_domains);
		is( scalar @extracted, 100, "Extracts 100 domains from single line" );

		my @empty_result = $match->extract_domains("# comment");
		is( scalar @empty_result, 0,
			"Returns empty list (not undef) for comment line" );

		is_deeply(
			[ $match->extract_domains(
				"valid.com not-a-domain invalid..com good.org"
			) ],
			[qw(valid.com good.org)],
			"Filters out malformed domains"
		);
	}
};

subtest 'extract_domains edge cases' => sub {
	my $match = Domain::Sift::Match->new();

SKIP: {
		skip "extract_domains not yet implemented", 5
			unless $match->can('extract_domains');

		is_deeply(
			[ $match->extract_domains("valid.com invalid.fakeTLD another.org") ],
			[qw(valid.com another.org)],
			"/g continues matching after invalid TLD"
		);

		my $label_63 = "a" x 63;
		is_deeply(
			[ $match->extract_domains("$label_63.com another.org") ],
			[ "$label_63.com", "another.org" ],
			"63-char label with multiple domains"
		);

		is_deeply(
			[ $match->extract_domains(
				"_dmarc.example.com valid.org _spf.test.net"
			) ],
			[ "_dmarc.example.com", "valid.org", "_spf.test.net" ],
			"Preserves underscore prefixes across multiple domains"
		);

		is_deeply(
			[ $match->extract_domains("a.b.c.d.e.com x.y.z.org") ],
			[ "a.b.c.d.e.com", "x.y.z.org" ],
			"Deep nesting across multiple domains"
		);

		is_deeply(
			[ $match->extract_domains("my-domain.com your-site.org -bad.com") ],
			[ "my-domain.com", "your-site.org", "bad.com" ],
			"Hyphenated domains with leading hyphen case"
		);
	}
};

subtest 'performance benchmark (multi-domain)' => sub {
	use Time::HiRes qw(time);

SKIP: {
		skip "Performance tests skipped in CI", 1 if $ENV{CI};

		my $match = Domain::Sift::Match->new();

	SKIP: {
			skip "extract_domains not yet implemented", 1
				unless $match->can('extract_domains');

			my @test_lines;
			for my $i ( 1 .. 1000 ) {
				push @test_lines, join( " ", map { "test$_-$i.com" } ( 1 .. 5 ) );
			}

			my $start_multi = time();
			my $total_multi = 0;
			for my $line (@test_lines) {
				my @domains = $match->extract_domains($line);
				$total_multi += scalar @domains;
			}
			my $elapsed_multi = time() - $start_multi;

			my $start_single = time();
			my $total_single = 0;
			for my $line (@test_lines) {
				my $domain = $match->extract_domain($line);
				$total_single++ if $domain;
			}
			my $elapsed_single = time() - $start_single;

			is( $total_multi, 5000, "Extracted 5 thousand domains total (multi)" );

			my $overhead_ratio = $elapsed_multi / ( $elapsed_single || 0.001 );
			diag("Single-domain: ${elapsed_single}s (1 thousand domains)");
			diag("Multi-domain: ${elapsed_multi}s (5 thousand domains)");
			diag("Overhead ratio: ${overhead_ratio}x");
			diag( "Throughput: "
					. sprintf( "%.0f", 5000 / $elapsed_multi )
					. " domains/second" );
		}
	}
};

subtest 'RFC 8552 underscore-prefixed labels' => sub {
	my $match = Domain::Sift::Match->new();

	# Valid service records (should preserve)
	is( $match->contains_domain("_dmarc.example.com"),
		"_dmarc.example.com", "DMARC service record preserved" );
	is( $match->contains_domain("_spf.mail.example.com"),
		"_spf.mail.example.com", "SPF service record preserved" );
	is( $match->contains_domain("_443._tcp.example.com"),
		"_443._tcp.example.com", "TLSA record preserved" );
	is( $match->contains_domain("_domainkey.example.com"),
		"_domainkey.example.com", "DKIM record preserved" );
	is( $match->contains_domain("_acme-challenge.example.com"),
		"_acme-challenge.example.com", "ACME challenge preserved" );
	is( $match->contains_domain("_a._b._c.example.com"),
		"_a._b._c.example.com", "Multiple underscore labels preserved" );
	is( $match->contains_domain("_dmarc.xn--nxasmq5b.com"),
		"_dmarc.xn--nxasmq5b.com", "Underscore prefix with punycode" );
	is( $match->contains_domain("_123.example.com"),
		"_123.example.com", "Numeric-only label after underscore" );

	# Invalid patterns (should reject)
	ok( !$match->contains_domain("__dmarc.example.com"),
		"Double underscore rejected" );
	ok( !$match->contains_domain("foo_bar.example.com"),
		"Mid-label underscore rejected" );
	ok( !$match->contains_domain("_foo_bar.example.com"),
		"Mid-label underscore after valid start rejected" );
	ok( !$match->contains_domain("_.example.com"),
		"Lone underscore label rejected" );
	ok( !$match->contains_domain("example_.com"),
		"Trailing underscore in label rejected" );
	ok( !$match->contains_domain("example_.org"),
		"Trailing underscore before TLD rejected" );
	ok( !$match->contains_domain("foo___bar.example.com"),
		"Triple underscore sequence rejected" );
	ok( !$match->contains_domain("test_.sub.example.com"),
		"Trailing underscore in subdomain rejected" );
	ok( !$match->contains_domain("_-weird.example.com"),
		"Underscore-hyphen label rejected (strict interpretation)" );
	ok( !$match->contains_domain("_foo-bar_.example.com"),
		"Trailing underscore after hyphen rejected" );
	ok( !$match->contains_domain("_foo-_bar.example.com"),
		"Hyphen-underscore sequence rejected" );

	# Non-adjacent invalid underscore (regex backtracks, must scan prefix)
	ok( !$match->contains_domain("valid.foo_bar.example.com"),
		"Mid-label underscore in earlier label rejected (prefix scan)" );
	ok( !$match->contains_domain("a.b.foo_bar.c.example.com"),
		"Mid-label underscore deep in subdomain rejected" );

	# Edge cases that SHOULD be preserved
	is( $match->contains_domain("_a._b._c._d.example.com"),
		"_a._b._c._d.example.com", "Deep underscore nesting preserved" );
	is( $match->contains_domain("sub._dmarc.example.com"),
		"sub._dmarc.example.com", "Normal subdomain under service label preserved" );

	# contains_domains: skips invalid, keeps valid
	is_deeply(
		[ $match->contains_domains("_dmarc.example.com valid.org _spf.test.net") ],
		[ "_dmarc.example.com", "valid.org", "_spf.test.net" ],
		"Preserves underscore prefixes across multiple domains"
	);
	is_deeply(
		[ $match->contains_domains("valid.com __bad.example.com another.org") ],
		[ "valid.com", "another.org" ],
		"Skips double-underscore domain, keeps valid ones"
	);
	is_deeply(
		[ $match->contains_domains("foo_bar.com _dmarc.test.org good.net") ],
		[ "_dmarc.test.org", "good.net" ],
		"Skips mid-label underscore, keeps valid ones"
	);
};

subtest 'FQDN format (trailing dot)' => sub {
	my $match = Domain::Sift::Match->new();

	# FQDN format (trailing dot) SHOULD be supported
	# RFC 1035 defines trailing dot as canonical fully-qualified form

	ok( $match->has_valid_tld("example.com."),
		"has_valid_tld: FQDN with trailing dot should be recognized" );

	is( $match->contains_domain("example.com."),
		"example.com", "contains_domain: FQDN extracts domain without dot" );

	is( $match->extract_domain("example.com."),
		"example.com", "extract_domain: FQDN extracts domain without dot" );

	# FQDN mixed with regular domain - both should be extracted
	is( $match->extract_domain("example.com. test.org"),
		"example.com", "extract_domain: FQDN extracted first" );

	# extract_domains should handle FQDN entries
	is_deeply(
		[ $match->extract_domains("example.com. test.org another.net.") ],
		[qw(example.com test.org another.net)],
		"extract_domains: extracts both FQDN and regular domains"
	);
};

subtest 'domain with port numbers' => sub {
	my $match = Domain::Sift::Match->new();

	# Word boundary correctly separates domain from port
	is( $match->extract_domain("example.com:8080"),
		"example.com", "Domain with port: extracts domain only" );
	is( $match->extract_domain("example.com:443"),
		"example.com", "Domain with HTTPS port" );
	is( $match->extract_domain("sub.example.com:3000"),
		"sub.example.com", "Subdomain with port" );

	# URL context with port
	is( $match->extract_domain("http://example.com:8080/path"),
		"example.com", "URL with port extracts domain" );

	# Trailing colon
	is( $match->extract_domain("example.com:"),
		"example.com", "Trailing colon only" );

	# IP:port doesn't match (invalid TLD), so domain:port found
	is( $match->extract_domain("127.0.0.1:8080 example.com:3000"),
		"example.com", "IP:port skipped, domain:port extracted" );

	# extract_domains with ports
	is_deeply(
		[ $match->extract_domains("example.com:8080 test.org:443") ],
		[qw(example.com test.org)],
		"Multiple domains with ports extracted"
	);
};

subtest 'maximum domain length (RFC 1035)' => sub {
	my $match = Domain::Sift::Match->new();

	# Valid: 63-char label (max per RFC 1035)
	my $label_63 = "a" x 63;
	is( $match->contains_domain("$label_63.com"),
		"$label_63.com", "63-char label (max per RFC) accepted" );

	# Valid: Multiple 63-char labels
	my $multi_63 = "$label_63.$label_63.com";    # 131 chars
	is( $match->contains_domain($multi_63),
		$multi_63, "Two 63-char labels accepted" );

	# Valid: Deep nesting (many short labels)
	my $deep_50 = join( ".", ("a") x 50 ) . ".com";    # 103 chars
	is( $match->contains_domain($deep_50),
		$deep_50, "50 single-char labels accepted" );

	# Invalid: 64-char label exceeds limit
	my $label_64 = "a" x 64;
	ok( !$match->contains_domain("$label_64.com"),
		"64-char label (exceeds RFC limit) rejected" );

	# RFC 1035 total domain length limit (253 chars) SHOULD be enforced
	my $too_long = join( ".", ("ab") x 85 ) . ".com";    # 85*3 + 3 = 258 chars
	ok( !$match->contains_domain($too_long),
		"Domain exceeding 253 chars rejected (RFC 1035)" );

	# Domain at exactly 253 chars should be accepted
	my $max_len = join( ".", ("aaaa") x 50 ) . ".com";
	is( $match->contains_domain($max_len),
		$max_len, "Domain at 253 chars accepted" );
};

subtest 'very large input lines' => sub {
	my $match = Domain::Sift::Match->new();

	# 10KB line with domain in middle
	my $large_10k = "X" x 5000 . " example.com " . "X" x 5000;
	is( $match->extract_domain($large_10k),
		"example.com", "Extracts domain from 10KB line" );

	# 100KB line
	my $large_100k = "Y" x 50000 . " test.org " . "Y" x 50000;
	is( $match->extract_domain($large_100k),
		"test.org", "Extracts domain from 100KB line" );

	# No domain in large line (tests regex rejection performance)
	my $no_match_large = "X" x 10000 . " no valid domain " . "X" x 10000;
	ok( !defined $match->extract_domain($no_match_large),
		"Returns undef for large line without domain" );

	# Many invalid TLD candidates (regex stress)
	my $many_invalid = join( " ", map { "word$_.fake" } ( 1 .. 1000 ) );
	ok( !defined $match->extract_domain($many_invalid),
		"Handles 1000 invalid TLD candidates" );

	SKIP: {
		skip "1MB memory test skipped in CI", 1 if $ENV{CI};
		my $large_1mb = "Z" x 500_000 . " large.net " . "Z" x 500_000;
		is( $match->extract_domain($large_1mb),
			"large.net", "Extracts domain from 1MB line" );
	}
};

subtest 'null bytes and control characters' => sub {
	my $match = Domain::Sift::Match->new();

	# Control characters should not be valid word separators
	# Any input containing control chars should reject

	# Null byte in input
	ok( !defined $match->extract_domain("exam\x00ple.com"),
		"Null byte in input: reject" );
	ok( !defined $match->extract_domain("\x00example.com"),
		"Null byte prefix: reject" );
	ok( !defined $match->extract_domain("example.com\x00"),
		"Null byte suffix: reject" );

	# Other control characters
	ok( !defined $match->extract_domain("exam\x01ple.com"),
		"SOH control char: reject" );
	ok( !defined $match->extract_domain("exam\x7Fple.com"),
		"DEL control char: reject" );

	# ANSI escape sequences
	ok( !defined $match->extract_domain("\x1B[31mexample.com\x1B[0m"),
		"ANSI escape sequence: reject" );
	ok( !defined $match->extract_domain("\x1B[0mtest.org"),
		"ANSI reset prefix: reject" );
};

done_testing();
