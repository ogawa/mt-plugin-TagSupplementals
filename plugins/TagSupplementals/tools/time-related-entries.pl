#!/usr/bin/perl
# $Id$
my $t = 0;
while (<>) {
    while ($_ =~ m!RelatedEntries=([0-9.]+)!gis) {
        $t += $1;
    }
}
print "mt:RelatedEntries: $t\n";
