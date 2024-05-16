use strict;
use warnings;

# parse snakemake's `benchmark` output
# input files are parsed as tsv, which is written by snakemake as default format

use Data::Dumper;
use File::Spec;
# use File::Path;
# use File::Copy;
# use File::Temp;
use Getopt::Long;
# use Storable qw/:DEFAULT nstore dclone/;


my (@files,$help);
GetOptions(
	"files=s{1,}"=>\@files,
	"help"=>\$help,
);
if ($help or !@files) {die <<USAGE;
-----------------------------------------
# parse snakemake's `benchmark` output file combine into one tsv file

[-f file1.txt 2.txt ...] # one or more benchmark tsv files

-----------------------------------------

USAGE
}


my @odir=File::Spec->splitpath($files[0]);
pop @odir; # remove file as last elem
my $ofile;
my $fh2;
foreach my $f (@files) {
	printf "%s . . .\n", $f;
	next if !-e $f;
	if (!$ofile) { # only create output file when input file exists, so can avoid issue when in-file/dir is invalid
		$ofile=File::Spec->catfile(@odir, sprintf('benchmark_parsed__%s.txt', time));
	}
	if (!$fh2 and $ofile) {
		open ($fh2, ">", $ofile) or die "!!! can't open output file: $ofile !!!";
		# header + last elem is input file path, the rest are all directly copied from snakemake output
		printf $fh2 "%s\n", (join "\t", qw/s	h:m:s	max_rss	max_vms	max_uss	max_pss	io_in	io_out	mean_load	cpu_time
		file_path/);
	}
	if ($fh2) {
		open (my $fh, $f);
		while (<$fh>) {
			# 1st line should be header
			next if $.==1;
			next if !/\S/;
			chomp;
			print $fh2 $_, "\t", $f, "\n";
		}
	}
}

print "\n\nall done, output file written to ", $ofile;
print "\n\n";
