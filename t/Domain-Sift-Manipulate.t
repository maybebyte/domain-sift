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
	use_ok('Domain::Sift::Manipulate') || print "Bail out!\n";
}

subtest 'reduce_domains - basic' => sub {
	my $manipulate = Domain::Sift::Manipulate->new();

	# No redundant domains
	my $hashref1 = {
		'example.com' => 1,
		'example.net' => 1,
		'example.org' => 1
	};
	my $result1 = $manipulate->reduce_domains($hashref1);
	is_deeply( $result1, {}, "No redundant domains" );

	# One redundant domain
	my $hashref2 = {
		'example.com' => 1,
		'sub.example.com' => 1,
		'example.net' => 1,
		'example.org' => 1
	};
	my $expected_result2 = { 'sub.example.com' => 'example.com' };
	my $result2 = $manipulate->reduce_domains($hashref2);
	is_deeply( $result2, $expected_result2, "One redundant domain" );

	# Multiple redundant domains
	my $hashref3 = {
		'example.com' => 1,
		'sub.example.com' => 1,
		'sub.sub.example.com' => 1,
		'example.net' => 1,
		'example.org' => 1
	};
	my $expected_result3 = {
		'sub.example.com' => 'example.com',
		'sub.sub.example.com' => 'example.com',
	};
	my $result3 = $manipulate->reduce_domains($hashref3);
	is_deeply( $result3, $expected_result3, "Multiple redundant domains" );
};

subtest 'reduce_domains - edge cases' => sub {
	my $manipulate = Domain::Sift::Manipulate->new();

	# Empty hash returns empty hash
	my $empty = {};
	my $result_empty = $manipulate->reduce_domains($empty);
	is_deeply( $result_empty, {}, "Empty hash returns empty hash" );
	is_deeply( $empty, {}, "Original empty hash unchanged" );

	# Single domain - no change
	my $single = { 'example.com' => 1 };
	my $result_single = $manipulate->reduce_domains($single);
	is_deeply( $result_single, {}, "Single domain: no redundant domains" );
	is_deeply( $single, { 'example.com' => 1 }, "Single domain remains" );

	# Sibling domains all remain (no common parent in hash)
	my $siblings = {
		'www.example.com' => 1,
		'api.example.com' => 1,
		'cdn.example.com' => 1,
	};
	my $result_siblings = $manipulate->reduce_domains($siblings);
	is_deeply( $result_siblings, {},
		"Sibling domains: no redundant domains" );
	is( scalar keys %$siblings, 3, "All sibling domains remain" );
};

subtest 'reduce_domains - deep nesting' => sub {
	my $manipulate = Domain::Sift::Manipulate->new();

	# Deep nesting (4 levels): all subdomains map to root
	my $deep = {
		'example.com' => 1,
		'sub.example.com' => 1,
		'deep.sub.example.com' => 1,
		'very.deep.sub.example.com' => 1,
	};
	my $result_deep = $manipulate->reduce_domains($deep);
	is_deeply(
		$result_deep,
		{
			'sub.example.com' => 'example.com',
			'deep.sub.example.com' => 'example.com',
			'very.deep.sub.example.com' => 'example.com',
		},
		"Deep nesting: all subdomains removed"
	);
	is_deeply( $deep, { 'example.com' => 1 }, "Only root domain remains" );

	# Deep nesting without root - middle domain is parent
	my $partial = {
		'sub.example.com' => 1,
		'deep.sub.example.com' => 1,
		'very.deep.sub.example.com' => 1,
	};
	my $result_partial = $manipulate->reduce_domains($partial);
	is_deeply(
		$result_partial,
		{
			'deep.sub.example.com' => 'sub.example.com',
			'very.deep.sub.example.com' => 'sub.example.com',
		},
		"Partial nesting: subdomains map to closest parent"
	);
	is_deeply(
		$partial,
		{ 'sub.example.com' => 1 },
		"Only closest parent remains"
	);
};

subtest 'reduce_domains - return value mapping' => sub {
	my $manipulate = Domain::Sift::Manipulate->new();

	# Verify return value correctly maps removed domains to their parent
	my $domains = {
		'example.com' => 1,
		'www.example.com' => 1,
		'api.example.com' => 1,
		'test.net' => 1,
		'sub.test.net' => 1,
	};
	my $redundant = $manipulate->reduce_domains($domains);

	# Check each removed domain maps to correct parent
	is( $redundant->{'www.example.com'},
		'example.com', "www.example.com maps to example.com" );
	is( $redundant->{'api.example.com'},
		'example.com', "api.example.com maps to example.com" );
	is( $redundant->{'sub.test.net'},
		'test.net', "sub.test.net maps to test.net" );

	# Verify original hash only contains root domains
	is_deeply(
		$domains,
		{ 'example.com' => 1, 'test.net' => 1 },
		"Original hash contains only root domains"
	);
};

subtest 'reduce_domains - large hash' => sub {
	my $manipulate = Domain::Sift::Manipulate->new();

	# Build a large hash with 50+ domains
	my %large;

	# 10 root domains
	for my $i ( 1 .. 10 ) {
		$large{"domain$i.com"} = 1;
	}

	# 5 subdomains per root = 50 subdomains
	for my $i ( 1 .. 10 ) {
		for my $j ( 1 .. 5 ) {
			$large{"sub$j.domain$i.com"} = 1;
		}
	}

	is( scalar keys %large, 60, "Large hash has 60 domains" );

	my $redundant = $manipulate->reduce_domains( \%large );

	is( scalar keys %$redundant, 50, "50 redundant domains removed" );
	is( scalar keys %large, 10, "10 root domains remain" );

	# Verify all remaining are root domains
	for my $domain ( keys %large ) {
		like( $domain, qr/^domain\d+\.com$/,
			"Remaining domain is root: $domain" );
	}

	# Verify all removed domains map to correct parent
	for my $removed ( keys %$redundant ) {
		my $parent = $redundant->{$removed};
		like( $parent, qr/^domain\d+\.com$/, "Parent is root domain" );
		like( $removed, qr/^sub\d+\.\Q$parent\E$/,
			"Subdomain maps to correct parent" );
	}
};

done_testing();
