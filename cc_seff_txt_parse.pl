use strict;
use warnings;

# parse CC-slurm scheduler's `seff` output

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
# parse `seff` output and extract into tsv file

[-f file1.txt 2.txt ...] # one or more seff output txt file
# files are got by running `seff JOBID > output.txt`
# non-existing files will be automatically excluded and NOT reported

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
		$ofile=File::Spec->catfile(@odir, sprintf('seff_parsed__%s.txt', time));
	}
	if (!$fh2 and $ofile) {
		open ($fh2, ">", $ofile) or die "!!! can't open output file: $ofile !!!";
		# header
		printf $fh2 "%s\n", (join "\t", qw/Job_ID  State  Nodes
		Cores_per_node  CPU_Utilized_min  CPU_total_core_walltime_min  Job_Wall_clock_time_min
		Memory_Utilized_GB Memory_total_GB/);
	}
	if ($fh2) {
		my $data=parse_seff_data($f);
		printf $fh2 "%s\n", (join "\t", $data->{id}, $data->{state}, $data->{nodes},
		$data->{cores_per_node}, $data->{cpu}, $data->{cpu_total}, $data->{job_wallclock},
		$data->{memory}, $data->{memory_total});
	}
}

print "\n\nall done, output file written to ", $ofile;
print "\n\n";

sub parse_seff_data {
	my $file=shift;
	if (!-e $file) {
		return {};
	}
	open (my $fh, $file);
	my $linedata;
	while (<$fh>) {
		chomp;
		if (/Job ID: (\d+)/) { $linedata->{id}=$1; }
		elsif (/State: /) { $linedata->{state}=$'; }
		elsif (/Nodes: (\d+)/) { $linedata->{nodes}=$1; }
		elsif (/Cores per node: (\d+)/) { $linedata->{cores_per_node}=$1; }
		elsif (/CPU Utilized: (\S+)/) { $linedata->{cpu}=format_time_min($1); }
		elsif (/CPU Efficiency: \S+ of (\S+) core-walltime/) { $linedata->{cpu_total}=format_time_min($1); }
		elsif (/Job Wall-clock time: /) { $linedata->{job_wallclock}=format_time_min($'); }
		elsif (/Memory Utilized: /) { $linedata->{memory}=format_memory_gb($'); }
		elsif (/Memory Efficiency: \S+ of /) { $linedata->{memory_total}=format_memory_gb($'); }
	}
	return $linedata;
}

sub format_time_min { # return minutes
	my $str=shift;
	# standard format: 1-14:23:45 or 00:14:34
	my $d=0;
	if ($str=~/-/) {
		$d=$`;
		$str=$';
	}
	my ($h, $m, $s)=split /:/, $str;
	return sprintf "%.2f", $d*24*60+$h*60+$m+($s/60);
}

sub format_memory_gb { # return formatted as GB
	my $str=shift;
	my $ram=0; # only consider MB and GB
	if ($str=~/^\s*(\S+) GB/i) {
		$ram=$1;
	}
	elsif ($str=~/^\s*(\S+) MB/i) {
		$ram=$1/1024;
	}
	return sprintf "%.2f", $ram;
}