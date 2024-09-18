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
printf $fh2 "%s\n", join "\t", qw/
	summary_file_path
	pass_reads   pass_total_bases  pass_read_max  pass_read_min  pass_read_N50
	fail_reads   fail_total_bases  fail_read_max  fail_read_min  fail_read_N50
/;

if ($filelist and -e $filelist) {
	open (my $fh, $filelist);
	while (<$fh>) {
		next if /^#/;
		chomp;
		push @files, $_;
	}
	close ($fh);
}

foreach my $f0 (@files) {
	printf "> %s . . .\n", $f0;
	my $f;
	if (-d $f0) { # if input dir, need to look for seq-sum.txt under this dir
		opendir (my $dh, $f0);
		while (my $f1=readdir $dh) {
			if ($f1=~/^sequencing_summary\S+\.txt$/i) {
				$f=File::Spec->catfile($f0,$f1);
				last;
			}
		}
	} else {
		$f=$f0;
	}

	if (!$f or !-e $f) {
		print "    can't find proper \"sequencing_summary\" file, skip\n";
		printf $fh2 "%s\t-1\n", $f0;
		next;
	}

	my $stat={
		'pass'=>{total_read=>0, total_len=>0},
		'fail'=>{total_read=>0, total_len=>0}
	};
	my $reads={};

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
			push @{$reads->{$passfail}}, $len;
			# print Dumper $reads->{$passfail};<>;
		}
	}
	close ($fh);
	# calc N50
	# https://timkahlke.github.io/LongRead_tutorials/APP_MET.html#:~:text=The%20N50%20is%20related%20to,in%20the%20set%20of%20sequences.
	foreach my $pf ("pass", "fail") {
		my $n50=$stat->{$pf}{total_len}/2;
		my $reads_sorted = [ sort {$b<=>$a} @{$reads->{$pf}} ];
		# die $reads_sorted[-1];
		$stat->{$pf}{'read_max'} = $reads_sorted->[0];
		for my $i (1..scalar(@$reads_sorted)) {
			my $j=$i*-1;
			if ($reads_sorted->[$j]>0) {
				$stat->{$pf}{'read_min'} = $reads_sorted->[$j]; # exclude 0 from min read len
				last;
			}
		}
		my $lensum=0;
		foreach my $r1 (@$reads_sorted) {
			$lensum+=$r1;
			if ($lensum>=$n50) {
				$stat->{$pf}{'N50'} = $r1;
				last;
			}
		}
	}
	# die Dumper $stat;

	printf $fh2 "%s\n",
		join "\t", ( $f,
			$stat->{pass}{total_read}, $stat->{pass}{total_len}, $stat->{pass}{read_max}, $stat->{pass}{read_min}, $stat->{pass}{N50},
			$stat->{fail}{total_read}, $stat->{fail}{total_len}, $stat->{fail}{read_max}, $stat->{fail}{read_min}, $stat->{fail}{N50}
		);
}

print "\n\nall done, output stat data written to ", $ofile;
