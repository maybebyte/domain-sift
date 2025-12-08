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

package Domain::Sift::Match;
use v5.36;
use English;
use File::Spec ();
use File::Basename qw(dirname);

=head1 NAME

Domain::Sift::Match - tools that match domains inside strings

=head1 SYNOPSIS

Domain::Sift::Match offers a set of methods for matching domains.

    use Domain::Sift::Match;

    my $sift_match = Domain::Sift::Match->new();
    my $example_domain = 'example.com';

    my $is_valid_tld = $sift_match->has_valid_tld($example_domain);
    my $valid_domain = $sift_match->contains_domain($example_domain);

    # Extract all domains from text
    my @all_domains = $sift_match->contains_domains($text);
    my @extracted = $sift_match->extract_domains($line);

=head1 SUBROUTINES/METHODS

=head2 new

    my $sift_match = Domain::Sift::Match->new();

Creates a new instance of the Domain::Sift::Match class. This instance
contains a list of valid top-level domains.

=cut

# Defined at the end of the file due to length.
# NOTE: Keep in sync with https://data.iana.org/TLD/tlds-alpha-by-domain.txt
my %valid_tlds;

# IMPORTANT: /p modifier is required for ${^MATCH} to capture matched text.
# Removing /p will cause contains_domain() and contains_domains() to return
# empty strings instead of the matched domain.
#
# Package-level pattern compiled once at module load for performance.
# Used by contains_domain() and contains_domains().
#
# Possessive quantifiers (++, *+) prevent backtracking, eliminating the need
# for a prefix scanning loop to handle invalid patterns like 'foo_bar.example.com'.
our $DOMAIN_PATTERN = qr/

	# word boundary ensures we're at the beginning of a domain
	\b

	# BEGIN domain group
	(

		# Lookahead asserts that the upcoming domain label contains
		# 1-63 allowed characters before a dot
		(?= [a-z 0-9 _-]{1,63} \.)

		# Domain label start: alphanumeric or underscore
		[a-z 0-9 _]++

		# Middle of label: hyphens and underscores followed by alphanumeric
		([-_]*+ [a-z 0-9]++)*

		# Each domain label ends with a dot
		\.

	# One or more domain groups (possessive)
	)++

	# BEGIN Top Level Domain (TLD) group
	(

		# Punycode TLD starts with 'xn--' and is followed by 2-59
		# allowed characters
		(xn-- [a-z 0-9]{2,59})
		|
		# Alternatively, use a regular TLD that has 2-63 letters
		[a-z]{2,63}

	# END TLD group
	)

	# word boundary ensures we're at the end of a domain
	\b

/paaxxni;

sub new ($class) {
	my $self = { valid_tlds => \%valid_tlds };
	return bless $self, $class;
}

=head2 has_valid_tld

    my $is_valid_tld = $sift_match->has_valid_tld($example_domain);

Checks the validity of a given domain's TLD. This function extracts the
TLD from the domain and verifies its presence in the list of valid TLDs.

=cut

# Regular expressions are avoided here due to their performance cost.
sub has_valid_tld ( $self, $domain ){
	my $tld = substr $domain, rindex( $domain, '.' ) + 1;
	return exists $self->{valid_tlds}{ uc($tld) }
}

# RFC 8552: Underscores allowed only at label start (service records)
# Valid: _dmarc.example.com, _443._tcp.example.com
# Invalid: foo_bar.example.com (mid-label), __dmarc.example.com (double)
sub _has_invalid_underscore ($domain) {
	return 0 unless index($domain, '_') >= 0;      # Fast path: no underscores
	return 1 if $domain =~ /__/;                   # Double underscore
	return 1 if $domain =~ /[a-z0-9]_[a-z0-9]/i;   # Mid-label underscore
	return 1 if $domain =~ /_\./;                  # Lone underscore OR trailing before dot
	return 1 if $domain =~ /[a-z0-9-]_$/i;         # Trailing underscore at end
	return 1 if $domain =~ /(?:^|\.)_-/;           # Underscore-hyphen at label start
	return 1 if $domain =~ /-_/;                   # Hyphen-underscore sequence
	return 0;
}

=head2 contains_domain

    my $valid_domain = $sift_match->contains_domain($example_domain);

Evaluates if a provided string is a valid domain name. contains_domain applies
pattern matching to confirm that the domain is formatted correctly and
checks the top-level domain (TLD) against a preloaded list of valid
TLDs. Returns the domain if the string matches the established domain
pattern and has a valid TLD. Otherwise contains_domain returns undef.

Underscore-prefixed labels (RFC 8552 service discovery) are preserved:
C<_dmarc.example.com> returns C<_dmarc.example.com>. Invalid underscore
patterns (mid-label, double, trailing) cause the method to return undef.

=cut

sub contains_domain ( $self, $text ) {
	if ( $text =~ /$DOMAIN_PATTERN/ ) {
		my $match = ${^MATCH};
		return if _has_invalid_underscore($match);
		return $match if $self->has_valid_tld($match);
	}
	return;
}

=head2 contains_domains

    my @valid_domains = $sift_match->contains_domains($text);

Returns all valid domains found in the given text. Unlike contains_domain
which returns only the first match, this method returns a list of all
domains with valid TLDs.

Underscore-prefixed labels (RFC 8552 service discovery) are preserved.
Invalid underscore patterns are skipped rather than causing rejection
of the entire input, allowing valid domains to still be extracted.

Duplicate domains within the same text are preserved in the order they
appear. This allows the caller to perform frequency analysis if needed.
Most use cases will deduplicate via a hash.

Returns an empty list if no valid domains are found.

=cut

sub contains_domains ( $self, $text ) {
	my @domains;
	while ( $text =~ /$DOMAIN_PATTERN/g ) {
		my $match = ${^MATCH};
		next if _has_invalid_underscore($match);
		push @domains, $match if $self->has_valid_tld($match);
	}
	return @domains;
}

=head2 extract_domain

    my $extracted_domain = $sift_match->extract_domain($example_line);

Extracts and returns a domain from a given line of text, if present. It
ignores comments and blank lines and skips lines containing certain IP
addresses. Domain names are treated as case-insensitive.

=cut

sub extract_domain ( $self, $line ) {
	chomp $line;
	$line =~ s/\r\z//;  # Handle Windows line endings on Unix

	return if $line =~ /\A \s* (\#|\z)/aaxxn;
	$line =~ s/\A \s* (127\.0\.0\.1|0\.0\.0\.0) \s*//aaxxn;
	return if $line =~ /\B (127\.0\.0\.1|0\.0\.0\.0)/aaxxn;

	return $self->contains_domain( lc($line) );
}

=head2 extract_domains

    my @extracted_domains = $sift_match->extract_domains($line);

Extracts and returns all domains from a given line of text. Like
extract_domain, it ignores comments and blank lines and handles
IP addresses, but returns all valid domains instead of just the first.

=cut

sub extract_domains ( $self, $line ) {
	chomp $line;
	$line =~ s/\r\z//;  # Handle Windows line endings on Unix

	return if $line =~ /\A \s* (\#|\z)/aaxxn;
	$line =~ s/\A \s* (127\.0\.0\.1|0\.0\.0\.0) \s*//aaxxn;
	return if $line =~ /\B (127\.0\.0\.1|0\.0\.0\.0)/aaxxn;

	return $self->contains_domains( lc($line) );
}

=head1 AUTHOR

Created and maintained by Ashlen <dev@anthes.is>

=head1 SEE ALSO

RFC 1034, Domain names - concepts and facilities

RFC 2181, Clarifications to the DNS Specification

RFC 8552, Scoped Interpretation of DNS Resource Records through
"Underscored" Naming of Attribute Leaves

IANA top-level domains list
https://data.iana.org/TLD/tlds-alpha-by-domain.txt

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2023-2025 by Ashlen.

This is free software, licensed under the ISC license.

=cut

# Load TLDs from external file at module load time
# Keep in sync with https://data.iana.org/TLD/tlds-alpha-by-domain.txt
{
    my $tld_file = File::Spec->catfile( dirname(__FILE__), 'tlds.txt' );
    open my $fh, '<', $tld_file
        or die "Cannot open TLD file '$tld_file': $!";
    while ( my $tld = <$fh> ) {
        chomp $tld;
        $tld =~ s/\r\z//;            # Handle Windows line endings
        $tld =~ s/\A\s+|\s+\z//g;    # Trim whitespace
        next if $tld eq '';          # Skip blank lines
        next if $tld =~ /\A#/;       # Skip comments
        $valid_tlds{ uc($tld) } = 1; # Normalize to uppercase
    }
    close $fh or warn "Failed to close '$tld_file': $!";

    # Sanity check
    my $count = scalar keys %valid_tlds;
    die "TLD file '$tld_file' appears corrupted: only $count TLDs loaded (expected >1400)"
        if $count < 1400;
}

1; # End of Domain::Sift::Match
