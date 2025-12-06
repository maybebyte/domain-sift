#!/usr/bin/env perl

use v5.36;
use autodie;

use File::Temp qw(tempfile);
use File::Spec;
use IPC::Open3;
use Symbol qw(gensym);
use Test::More;

# Path to the CLI script - use blib if available, otherwise bin
my $script = File::Spec->catfile( 'blib', 'script', 'domain-sift' );
$script = File::Spec->catfile( 'bin', 'domain-sift' ) unless -f $script;

# Helper to run the CLI and capture output
sub run_cli (@args) {
	my ($input) = grep { ref $_ eq 'SCALAR' } @args;
	@args = grep { ref $_ ne 'SCALAR' } @args;

	my ( $stdout, $stderr ) = ( '', '' );
	my $err = gensym;
	my $pid = open3( my $in, my $out, $err, $^X, '-Mblib', $script, @args );

	if ($input) {
		print $in $$input;
	}
	close $in;   # Signal EOF to child

	$stdout = do { local $/; <$out> };
	$stderr = do { local $/; <$err> };
	close $out;
	close $err;

	waitpid( $pid, 0 );
	my $exit_code = $? >> 8;

	return ( $exit_code, $stdout, $stderr );
}

# Helper to create a temp file with content
sub temp_file ($content) {
	my ( $fh, $filename ) = tempfile( UNLINK => 1 );
	print $fh $content;
	close $fh;
	return $filename;
}

# =============================================================================
# Argument Parsing Tests
# =============================================================================

subtest 'argument parsing' => sub {
	subtest '-h displays usage' => sub {
		my ( $exit, $stdout, $stderr ) = run_cli('-h');
		like(
			$stderr,
			qr/domain-sift.*\[-h\].*\[-f\s+format\]/i,
			'usage message shown'
		);
		isnt( $exit, 0, 'exits non-zero (die in usage)' );
	};

	subtest '-f accepts valid formats' => sub {
		my $file = temp_file("example.com\n");
		for my $fmt (qw(plain unbound rpz)) {
			my ( $exit, $stdout, $stderr ) = run_cli( '-f', $fmt, $file );
			is( $exit, 0, "-f $fmt accepted" );
			is( $stderr, '', "no error for -f $fmt" );
		}
	};

	subtest '-f rejects invalid format' => sub {
		my $file = temp_file("example.com\n");
		my ( $exit, $stdout, $stderr ) = run_cli( '-f', 'invalid', $file );
		isnt( $exit, 0, 'exits non-zero for invalid format' );
		like( $stderr, qr/not a valid format/i, 'error message shown' );
	};
};

# =============================================================================
# Output Format Tests
# =============================================================================

subtest 'output formats' => sub {
	my $file = temp_file("example.com\ntest.org\n");

	subtest 'plain format (default)' => sub {
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		like( $stdout, qr/^example\.com$/m, 'contains example.com' );
		like( $stdout, qr/^test\.org$/m, 'contains test.org' );
	};

	subtest 'plain format explicit' => sub {
		my ( $exit, $stdout, $stderr ) = run_cli( '-f', 'plain', $file );
		is( $exit, 0, 'exits successfully' );
		like( $stdout, qr/^example\.com$/m, 'contains example.com' );
	};

	subtest 'unbound format' => sub {
		my ( $exit, $stdout, $stderr ) = run_cli( '-f', 'unbound', $file );
		is( $exit, 0, 'exits successfully' );
		like(
			$stdout,
			qr/^local-zone: "example\.com" always_refuse$/m,
			'unbound format for example.com'
		);
		like(
			$stdout,
			qr/^local-zone: "test\.org" always_refuse$/m,
			'unbound format for test.org'
		);
	};

	subtest 'rpz format' => sub {
		my ( $exit, $stdout, $stderr ) = run_cli( '-f', 'rpz', $file );
		is( $exit, 0, 'exits successfully' );
		like(
			$stdout,
			qr/^example\.com CNAME \.$/m,
			'rpz CNAME for example.com'
		);
		like(
			$stdout,
			qr/^\*\.example\.com CNAME \.$/m,
			'rpz wildcard for example.com'
		);
		like( $stdout, qr/^test\.org CNAME \.$/m,
			'rpz CNAME for test.org' );
		like(
			$stdout,
			qr/^\*\.test\.org CNAME \.$/m,
			'rpz wildcard for test.org'
		);
	};

	subtest 'rpz format reduces subdomains' => sub {
		my $file_with_subs =
			temp_file("example.com\nsub.example.com\ndeep.sub.example.com\n");
		my ( $exit, $stdout, $stderr ) =
			run_cli( '-f', 'rpz', $file_with_subs );
		is( $exit, 0, 'exits successfully' );
		like( $stdout, qr/^example\.com CNAME \.$/m,
			'root domain present' );
		unlike(
			$stdout,
			qr/^sub\.example\.com CNAME \./m,
			'subdomain removed'
		);
		unlike(
			$stdout,
			qr/^deep\.sub\.example\.com CNAME \./m,
			'deep subdomain removed'
		);
	};
};

# =============================================================================
# Input Handling Tests
# =============================================================================

subtest 'input handling' => sub {
	subtest 'single file input' => sub {
		my $file = temp_file("single.com\n");
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		like( $stdout, qr/^single\.com$/m, 'domain extracted' );
	};

	subtest 'multiple file inputs' => sub {
		my $file1 = temp_file("first.com\n");
		my $file2 = temp_file("second.org\n");
		my ( $exit, $stdout, $stderr ) = run_cli( $file1, $file2 );
		is( $exit, 0, 'exits successfully' );
		like( $stdout, qr/^first\.com$/m, 'first file domain' );
		like( $stdout, qr/^second\.org$/m, 'second file domain' );
	};

	subtest 'stdin input' => sub {
		my $input = "stdin.com\nstdin.org\n";
		my ( $exit, $stdout, $stderr ) = run_cli( \$input );
		is( $exit, 0, 'exits successfully' );
		like( $stdout, qr/^stdin\.com$/m, 'stdin domain 1' );
		like( $stdout, qr/^stdin\.org$/m, 'stdin domain 2' );
	};

	subtest 'missing file produces error' => sub {
		my ( $exit, $stdout, $stderr ) =
			run_cli('/nonexistent/file/path.txt');

		# The <<>> operator with autodie warns but continues, exiting 0
		like( $stderr, qr/can't open|no such file/i,
			'error message shown' );
	};

	subtest 'empty file produces no output' => sub {
		my $file = temp_file('');
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		is( $stdout, '', 'no output' );
	};

	subtest 'whitespace-only file produces no output' => sub {
		my $file = temp_file("   \n\t\n   \t   \n");
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		is( $stdout, '', 'no output' );
	};
};

# =============================================================================
# Deduplication and Sorting Tests
# =============================================================================

subtest 'deduplication and sorting' => sub {
	subtest 'duplicate domains appear once' => sub {
		my $file = temp_file("example.com\nexample.com\nexample.com\n");
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		my @lines = grep { /\S/ } split /\n/, $stdout;
		is( scalar @lines, 1, 'only one line output' );
		is( $lines[0], 'example.com', 'correct domain' );
	};

	subtest 'case variations normalized' => sub {
		my $file = temp_file("EXAMPLE.COM\nExample.Com\nexample.com\n");
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		my @lines = grep { /\S/ } split /\n/, $stdout;
		is( scalar @lines, 1, 'only one line output' );
		is( $lines[0], 'example.com', 'lowercase domain' );
	};

	subtest 'output is alphabetically sorted' => sub {
		my $file = temp_file("zebra.com\napple.com\nmango.com\n");
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		my @lines = grep { /\S/ } split /\n/, $stdout;
		is_deeply(
			\@lines,
			[qw(apple.com mango.com zebra.com)],
			'sorted output'
		);
	};

	subtest 'duplicates across files deduplicated' => sub {
		my $file1 = temp_file("example.com\ntest.org\n");
		my $file2 = temp_file("example.com\nother.net\n");
		my ( $exit, $stdout, $stderr ) = run_cli( $file1, $file2 );
		is( $exit, 0, 'exits successfully' );
		my @lines = grep { /\S/ } split /\n/, $stdout;
		is( scalar @lines, 3, 'three unique domains' );
		is_deeply(
			\@lines,
			[qw(example.com other.net test.org)],
			'deduplicated and sorted'
		);
	};
};

# =============================================================================
# Edge Cases
# =============================================================================

subtest 'edge cases' => sub {
	subtest 'hosts file format' => sub {
		my $file =
			temp_file("127.0.0.1 localhost.com\n0.0.0.0 blocked.org\n");
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		like( $stdout, qr/^localhost\.com$/m,
			'extracts domain after 127.0.0.1' );
		like( $stdout, qr/^blocked\.org$/m,
			'extracts domain after 0.0.0.0' );
	};

	subtest 'comment lines ignored' => sub {
		my $file =
			temp_file("# This is a comment\nexample.com\n# Another comment\n");
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		my @lines = grep { /\S/ } split /\n/, $stdout;
		is( scalar @lines, 1, 'only domain line output' );
		is( $lines[0], 'example.com', 'correct domain' );
	};

	subtest 'mixed valid and invalid domains' => sub {
		my $file =
			temp_file("valid.com\ninvalid\nalso-valid.org\nno-tld\n");
		my ( $exit, $stdout, $stderr ) = run_cli($file);
		is( $exit, 0, 'exits successfully' );
		my @lines = grep { /\S/ } split /\n/, $stdout;
		is( scalar @lines, 2, 'only valid domains' );
		is_deeply(
			\@lines,
			[qw(also-valid.org valid.com)],
			'valid domains sorted'
		);
	};
};

done_testing();
