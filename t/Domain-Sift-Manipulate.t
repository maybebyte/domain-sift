#!/usr/bin/env perl

use v5.36;
use autodie;

use Test::More;

BEGIN {
	use_ok('Domain::Sift::Manipulate') || print "Bail out!\n";
}

subtest 'reduce_domains' => sub {
	my $manipulate = Domain::Sift::Manipulate->new();
	## Test case 1: No redundant domains
	my $hashref1 = {
		'example.com' => 1,
		'example.net' => 1,
		'example.org' => 1
	};
	my $result1 = $manipulate->reduce_domains($hashref1);
	is_deeply( $result1, {}, "No redundant domains" );

	# Test case 2: One redundant domain
	my $hashref2 = {
		'example.com' => 1,
		'sub.example.com' => 1,
		'example.net' => 1,
		'example.org' => 1
	};
	my $expected_result2 = { 'sub.example.com' => 'example.com', };
	my $result2 = $manipulate->reduce_domains($hashref2);
	is_deeply( $result2, $expected_result2, "One redundant domain" );

	# Test case 3: Multiple redundant domains
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

done_testing();
