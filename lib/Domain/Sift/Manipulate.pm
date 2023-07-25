package Domain::Sift::Manipulate;

use v5.36;

=head1 NAME

Domain::Sift::Manipulate - sift through domains

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Manipulate a hash reference containing domains.

    use Domain::Sift::Manipulate;

    my $sift_manipulate = Domain::Sift::Manipulate->new();
    my %domains = ( 'example.com', 'subdomain.example.com' );

	# remove subdomain.example.com since *.example.com would match it
    $sift_manipulate->reduce_domains(\%domains);

=head1 SUBROUTINES/METHODS

=head2 new

    my $sift_manipulate = Domain::Sift::Manipulate->new();

Creates a new instance of the Domain::Sift::Manipulate class.

=cut

sub new ($class) {
	my $self = {};
	return bless $self, $class;
}

=head2 reduce_domains

	my $redundant_domains = $sift_manipulate->reduce_domains(\%example_domains);

Receives a reference to a hash of domain names and identifies redundant
domains. If a domain and a subdomain are both keys in the hash, the
subdomain is deemed redundant and removed. This function operates on the
premise that a wildcard attached to the domain can cover the subdomain.

reduce_domains returns a hash reference of the removed domains.

=cut

sub reduce_domains ( $self, $hash_ref ) {
	my %redundant_domains;

	while ( my $domain = each %$hash_ref ) {
		my $index = rindex $domain, '.', rindex( $domain, '.' ) - 1;

		while ( $index != -1 ) {
			my $leaf = substr $domain, $index + 1;

			if ( defined $hash_ref->{$leaf} ) {
				delete $hash_ref->{$domain};
				$redundant_domains{$domain} = $leaf;
				last;
			}

			$index = rindex $domain, '.', $index - 1;
		}
	}
	return \%redundant_domains;
}

=head1 AUTHOR

Created and maintained by Ashlen <dev@anthes.is>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2023 by Ashlen.

This is free software, licensed under the ISC license.

=cut

1;   # End of Domain::Sift::Manipulate
