use strict;
use warnings;

# parse and extract needed info from nanopore seq output file "sequencing_summary_XYZ.txt"
# more info: https://community.nanoporetech.com/docs/prepare/library_prep_protocols/Guppy-protocol/v/gpb_2003_v1_revax_14dec2018/input-and-output-files#:~:text=sequencing_summary.,emitted%20containing%20the%20basecall%20results.


use Data::Dumper;
use File::Spec;
use File::Path;
# use File::Copy;
# use File::Temp;
use Getopt::Long;
# use Storable qw/:DEFAULT nstore dclone/;


my (@files, $filelist, $ofile,$help);
GetOptions(
	"files=s{1,}"=>\@files,
	"list=s"=>\$filelist,
	"ofile=s"=>\$ofile,
	"help"=>\$help,
);
if ($help or !$ofile or (!@files and !$filelist)) {die <<USAGE;
-----------------------------------------
# parse nanopore sequencing's output summary file
# output total bases in pass/fail groups

** at least one of [-f] or [-l] is required
[-f file1 2 3 ...]
  - must be tsv file and have a name like "sequencing_summary.txt", or internal formatting might be messed up
[-l file_list.txt]
  - a text file containing a list of sequencing_summary.txt files, one path per line
  - can use "#" at line start for comments
Note: for both [-f] and [-l], can input the directory path that containing the "sequencing_summary.txt" file.

[-o OUTPUT_FILE.txt] **required
  where to write output statistics data into a txt file, containing directory doesn't need to exist

-----------------------------------------

USAGE
}


my @x=File::Spec->splitpath($ofile);
my $odir;
$odir=File::Spec->catpath($x[0], $x[1]);
if (!-d $odir) {
	mkpath $odir;
}

open (my $fh2, ">", $ofile);
printf $fh2 "%s\n", join "\t", qw/summary_file_path   passed_reads   failed_reads   passed_total_bases   failed_total_bases /;

if ($filelist and -e $filelist) {
	open (my $fh, $filelist);
	while (<$fh>) {
		next if /^#/;
		chomp;
		push @files, $_;
	}
	close ($fh);
}

# my $x=0;
foreach my $f0 (@files) {
	printf "> %s . . .\n", $f0;
	my $f;
	if (-d $f0) { # input dir, need to look for seq-sum.txt under this dir
		opendir (my $dh, $f0);
		while (my $f1=readdir $dh) {
			if ($f1=~/^sequencing_summary\S+\.txt$/i) {
				$f=File::Spec->catfile($f0,$f1);
				last;
			}
		}
	}
	elsif (-e $f0) { # input file, will just assume it's a valid "sequencing_summary.txt" file
		$f=$f0;
	}
	else {
		print "    path doesn't exist, skip\n";
		printf $fh2 "%s\t-1\n", $f0;
		next;
	}

	my $stat={
		'pass'=>{total_read=>0, total_len=>0},
		'fail'=>{total_read=>0, total_len=>0}
	};

	my $idx_seqlen=-1;
	my $idx_passfail=-1;
	open (my $fh, $f);
	while (<$fh>) {
		chomp;
		my @c=split /\t/;
		# print $_;
		if ($.==1) { # parse header and get needed index
			for (my $i=0; $i<scalar @c; $i++) {
				if ($c[$i]=~/sequence_length_template/) { $idx_seqlen=$i; } # how long the fastq read is
				elsif ($c[$i]=~/passes_filtering/) { $idx_passfail=$i; } # in _pass/_fail folder
			}
		}
		else {
			my $passfail=($c[$idx_passfail] eq 'TRUE') ? 'pass' : 'fail';
			my $len=$c[$idx_seqlen]; # length of current fastq read in bases
			$stat->{$passfail}{total_read}++;
			$stat->{$passfail}{total_len}+=$len;
		}
	}
	close ($fh);
	printf $fh2 "%s\n", join "\t", $f, $stat->{pass}{total_read}, $stat->{fail}{total_read}, $stat->{pass}{total_len}, $stat->{fail}{total_len};
	# $x++;
	# last if $x==3;
}

print "\n\nall done, output stat data written to ", $ofile;
