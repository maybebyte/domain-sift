#!/usr/bin/env perl

use v5.36;
use autodie;

# Core modules.
use English;
use Test::More;

BEGIN {
	use_ok( 'Domain::Sift::Match' ) || print "Bail out!\n";
}

my $sift_match = Domain::Sift::Match->new();

subtest 'has_valid_tld' => sub {
	## Test valid TLDs
	ok(
		$sift_match->has_valid_tld("example.com"),
		"example.com contains a valid TLD"
	);
	ok(
		$sift_match->has_valid_tld("google.co.uk"),
		"google.co.uk contains a valid TLD"
	);
	ok(
		$sift_match->has_valid_tld("stackoverflow.net"),
		"stackoverflow.net contains a valid TLD"
	);

	# Test invalid TLDs
	ok(
		!$sift_match->has_valid_tld("example"),
		"example is not a valid TLD"
	);
	ok(
		!$sift_match->has_valid_tld("stackoverflow"),
		"stackoverflow is not a valid TLD"
	);
	ok(
		!$sift_match->has_valid_tld("lwq"),
		"lwq is not a valid TLD"
	);
};

subtest 'contains_domain' => sub {
	## Test valid domains
	ok(
		$sift_match->contains_domain("example.com"),
		"Valid domain"
	);
	ok(
		$sift_match->contains_domain("subdomain.example.com"),
		"Valid domain with subdomain"
	);
	ok(
		$sift_match->contains_domain("xn--fiq228c.com"),
		"Valid punycode domain"
	);

	# Test invalid domains
	ok(
		!$sift_match->contains_domain("example"),
		"Invalid domain"
	);
	ok(
		!$sift_match->contains_domain("example..com"),
		"Invalid domain with double dot"
	);
	ok(
		!$sift_match->contains_domain("example_com"),
		"Invalid domain with underscore"
	);
	ok(
		!$sift_match->contains_domain("example.qrf"),
		"Invalid domain with bogus top-level domain (qrf)"
	);
};

subtest 'extract_domain' => sub {
	## Test for chomp
	is(
		$sift_match->extract_domain("example.com\n"),
		"example.com", "Trailing newlines should be chomped"
	);

	# Test for commented line
	is(
		$sift_match->extract_domain("# example.com"),
		undef, "Commented line should be skipped (space between)"
	);
	is(
		$sift_match->extract_domain("#example.com"),
		undef, "Commented line should be skipped (no space between)"
	);
	is(
		$sift_match->extract_domain(" " x 5 . "# example.com"),
		undef, "Commented line should be skipped (5 spaces)"
	);
	is(
		$sift_match->extract_domain("\t" x 5 . "# example.com"),
		undef, "Commented line should be skipped (5 tabs)"
	);
	is(
		$sift_match->extract_domain(" \t" x 5 . "# example.com"),
		undef, "Commented line should be skipped (5 spaces + 5 tabs)"
	);

	# Test for blank line
	is(
		$sift_match->extract_domain(""),
		undef, "Blank line should be skipped (empty string)"
	);
	is(
		$sift_match->extract_domain("\n"),
		undef, "Blank line should be skipped (newline)"
	);
	is(
		$sift_match->extract_domain(" " x 5),
		undef, "Blank line should be skipped (5 spaces)"
	);
	is(
		$sift_match->extract_domain("\t" x 5),
		undef, "Blank line should be skipped (5 tabs)"
	);
	is(
		$sift_match->extract_domain(" \t" x 5),
		undef, "Blank line should be skipped (5 spaces + 5 tabs)"
	);
	is(
		$sift_match->extract_domain(" \t\n"),
		undef, "Blank line should be skipped (space + tab + newline)"
	);


	# Test for line with leading IP address
	is(
		$sift_match->extract_domain("127.0.0.1 example.com"),
		"example.com", "Leading 127.0.0.1 should be ignored"
	);
	is(
		$sift_match->extract_domain(" \t127.0.0.1 \texample.com"),
		"example.com", "Leading 127.0.0.1 should be ignored (spaces + tabs)"
	);
	is(
		$sift_match->extract_domain("0.0.0.0 example.com"),
		"example.com", "Leading 0.0.0.0 should be ignored"
	);
	is(
		$sift_match->extract_domain(" \t0.0.0.0 \texample.com"),
		"example.com", "Leading 0.0.0.0 should be ignored (spaces + tabs)"
	);

	# Test for line with IP address at the end of a word
	is(
		$sift_match->extract_domain("example.com127.0.0.1"),
		undef,
		"Line with 127.0.0.1 at the end of a word should be skipped"
	);
	is(
		$sift_match->extract_domain("example.com0.0.0.0"),
		undef,
		"Line with 0.0.0.0 at the end of a word should be skipped"
	);

	# Test for case-insensitive domain name
	is(
		$sift_match->extract_domain("EXAMPLE.COM"),
		"example.com", "EXAMPLE.COM should be converted to example.com"
	);

	# Test for longer lines
	is(
		$sift_match->extract_domain(
			"A" x 1024 . " " . "example.com" . " " . "A" x 1024
		),
		"example.com",
		"Extracts domains out of longer lines"
	);
};

done_testing();
