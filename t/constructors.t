#!/usr/bin/env perl

use v5.36;
use autodie;

use Test::More;

BEGIN {
	use_ok('Domain::Sift::Match') || print "Bail out!\n";
	use_ok('Domain::Sift::Manipulate') || print "Bail out!\n";
}

subtest 'Domain::Sift::Match - constructor' => sub {
	my $match = Domain::Sift::Match->new();

	ok( defined $match, 'new() returns defined value' );
	isa_ok( $match, 'Domain::Sift::Match' );

	# Verify valid_tlds is accessible and populated
	ok( exists $match->{valid_tlds}, 'valid_tlds key exists' );
	ok(
		ref $match->{valid_tlds} eq 'HASH',
		'valid_tlds is a hash reference'
	);
	ok(
		scalar keys %{ $match->{valid_tlds} } > 1000,
		'valid_tlds contains over 1000 TLDs'
	);

	# Spot-check common TLDs
	ok( $match->{valid_tlds}{COM}, 'COM TLD present' );
	ok( $match->{valid_tlds}{NET}, 'NET TLD present' );
	ok( $match->{valid_tlds}{ORG}, 'ORG TLD present' );
};

subtest 'Domain::Sift::Manipulate - constructor' => sub {
	my $manipulate = Domain::Sift::Manipulate->new();

	ok( defined $manipulate, 'new() returns defined value' );
	isa_ok( $manipulate, 'Domain::Sift::Manipulate' );
	ok( ref $manipulate eq 'Domain::Sift::Manipulate',
		'ref() returns correct class' );
};

subtest 'Multiple instances - Match' => sub {
	my $match1 = Domain::Sift::Match->new();
	my $match2 = Domain::Sift::Match->new();

	ok( defined $match1, 'first instance defined' );
	ok( defined $match2, 'second instance defined' );
	isnt( $match1, $match2, 'each new() returns a different reference' );

	# Verify shared valid_tlds (package-level by design)
	is( $match1->{valid_tlds}, $match2->{valid_tlds},
		'valid_tlds reference is shared between instances' );
};

subtest 'Multiple instances - Manipulate' => sub {
	my $manipulate1 = Domain::Sift::Manipulate->new();
	my $manipulate2 = Domain::Sift::Manipulate->new();

	ok( defined $manipulate1, 'first instance defined' );
	ok( defined $manipulate2, 'second instance defined' );
	isnt( $manipulate1, $manipulate2,
		'each new() returns a different reference' );
};

done_testing();
