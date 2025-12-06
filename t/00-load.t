#!perl

use v5.36;
use Test::More;

plan tests => 3;

BEGIN {
    use_ok( 'Domain::Sift' ) || print "Bail out!\n";
    use_ok( 'Domain::Sift::Match' ) || print "Bail out!\n";
    use_ok( 'Domain::Sift::Manipulate' ) || print "Bail out!\n";
}

diag( "Testing Domain::Sift $Domain::Sift::VERSION, Perl $], $^X" );
