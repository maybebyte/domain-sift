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
		!$sift_match->has_valid_tld("lwwbae0n03"),
		"lwwbae0n03 is not a valid TLD"
	);
};

subtest 'is_domain' => sub {
	## Test valid domains
	ok(
		$sift_match->is_domain("example.com"),
		"Valid domain"
	);
	ok(
		$sift_match->is_domain("subdomain.example.com"),
		"Valid domain with subdomain"
	);
	ok(
		$sift_match->is_domain("xn--fiq228c.com"),
		"Valid punycode domain"
	);

	# Test invalid domains
	ok(
		!$sift_match->is_domain("example"),
		"Invalid domain"
	);
	ok(
		!$sift_match->is_domain("example..com"),
		"Invalid domain with double dot"
	);
	ok(
		!$sift_match->is_domain("example_com"),
		"Invalid domain with underscore"
	);
	ok(
		!$sift_match->is_domain("example.qrf7zdk"),
		"Invalid domain with bogus top-level domain"
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
		undef, "Commented line should be skipped"
	);

	# Test for blank line
	is(
		$sift_match->extract_domain(""),
		undef, "Blank line should be skipped"
	);

	# Test for line with leading IP address
	is(
		$sift_match->extract_domain("127.0.0.1 example.com"),
		"example.com", "Leading IP address should be removed"
	);

	# Test for line with IP address at the end of a word
	is(
		$sift_match->extract_domain("example.com127.0.0.1"),
		undef,
		"Line with IP address at the end of a word should be skipped"
	);

	# Test for case-insensitive domain name
	is(
		$sift_match->extract_domain("EXAMPLE.COM"),
		"example.com", "Domain name should be converted to lowercase"
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
