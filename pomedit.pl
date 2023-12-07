#!/usr/bin/env perl

# Usage context: Build RPMs of Quattor core components.
# To remove from a pom.xml the <module>ncm-*</module>
# lines that don't correspond to a list of ncm-components.
# This is useful when you don't want to build all ncm-components.

use File::Copy;

my $pomfic = '/home/workspace/src/configuration-modules-core/pom.xml';
my @ncmcomps = @ARGV;

my $tmpfic = "/tmp/newpom.xml";

# Check arguments
die ("Missing arg: space seperated list of ncm-components!") if ( @ncmcomps == 0 );

# Parse pom.xml to generate the new version in tmp
open(FH1, '<', $pomfic) or die $!;
open(FH2, '>>', $tmpfic) or die $!;
while(<FH1>)
{
    if ( m/^\s+<module>/ ) {
        foreach my $comp (@ncmcomps)
        {
            if ( m/$comp/ ) {
                print FH2 $_;
            }
        }
    } else {
        print FH2 $_;
    }
}
close(FH1);
close(FH2);

# Replace pom.xml by the new version in tmp
move($pomfic, "$pomfic.old");
copy($tmpfic, $pomfic);

# Clean-up
unlink($tmpfic);
