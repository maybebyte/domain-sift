#!/usr/bin/env perl
use v5.36;
use lib 'lib';
use Domain::Sift::Match;

my $m = Domain::Sift::Match->new();

# Test domains that exercise different code paths
my @test_cases = (
    '_dmarc.example.com',       # Valid RFC 8552
    'example.com',              # Simple domain (most common case)
    'sub.example.com',          # Subdomain
    'foo_bar.example.com',      # Invalid mid-label (rejected)
    '__bad.example.com',        # Invalid double underscore
    '_443._tcp.example.com',    # Valid multi-underscore
);

# Test both methods
for (1..100_000) {
    for my $domain (@test_cases) {
        $m->contains_domain($domain);
        $m->contains_domains($domain);
    }
}
