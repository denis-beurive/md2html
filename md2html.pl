#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use File::Find;
use File::Spec;
use File::Basename;
use File::Path qw/make_path/;
use Getopt::Long;

# CONFIGURATION
use constant PANDOC => 'C:\Users\denis.beurive\AppData\Local\Pandoc\pandoc.exe';

use constant KEY_BASENAME => 'basename';
use constant KEY_ABSOLUTE_PATH => 'absolute path';
use constant KEY_ABSOLUTE_DIR => 'absolute dir';

my $__DIR__ = File::Spec->rel2abs(dirname(__FILE__));
my $PANDOC_CSS = File::Spec->catfile($__DIR__, 'pandoc.css');
my $cli_root_path = $__DIR__;
my $cli_target_path = $__DIR__;
my $cli_verbose = 0;
my $cli_help = 0;

my $HELP = <<'HELP';
perl md2html.pl [--root-path=<root path>] \
                [--target-path=<target path>] \
                [--verbose] \
                [--help]
HELP

sub get_target_path {
    my ($in_input_path, $in_input_root, $in_output_root) = @_;
    my $input_relpath = File::Spec->abs2rel($in_input_path, $in_input_root);
    my $input_reldir = dirname($input_relpath);
    my $output_absdir = File::Spec->catfile($in_output_root, $input_reldir);
    my $output_abspath = File::Spec->catfile($output_absdir, basename($in_input_path));
    return { &KEY_ABSOLUTE_DIR => $output_absdir, &KEY_ABSOLUTE_PATH => $output_abspath }
}

sub convert_md_links {
    my ($in_input_path) = @_;
    open(my $fd, '<', $in_input_path)
        or die(sprintf('Cannot open file "%s": %s', $in_input_path, $!));
    my @lines = <$fd>;
    close($fd);
    my $html = join('', @lines);
    $html =~ s/<a href="([^"]+)\.md">/<a href="$1.html">/igm;
    open($fd, '>', $in_input_path)
        or die(sprintf('Cannot open file "%s": %s', $in_input_path, $!));
    print $fd $html;
    close($fd)
}

unless (
    GetOptions (
        'help'                               => \$cli_help,
        'verbose'                            => \$cli_verbose,
        'root-path=s'                        => \$cli_root_path,
        'target-path=s'                      => \$cli_target_path,
    )
) { die "ERROR: Invalid command line.\n" }

if ($cli_help) {
    print "${HELP}\n";
    exit(0)
}

$cli_root_path = File::Spec->rel2abs($cli_root_path);
$cli_target_path = File::Spec->rel2abs($cli_target_path);

# List all MarkDown files to convert.
my @md_files = ();
sub wanted {
    push(@md_files, {
        &KEY_BASENAME => $_,
        &KEY_ABSOLUTE_PATH => File::Spec->rel2abs($File::Find::name)
    }) if ($_ =~ m/\.md$/i);
}
find(\&wanted, ($cli_root_path));

if ($cli_verbose) {
    print("MarkDown files to convert:\n");
    foreach my $file (@md_files) { printf("- \"%s\"\n", $file->{&KEY_ABSOLUTE_PATH}) }
    print("\n");
}

# Convert all MarkDown files.
foreach my $file (@md_files) {
    my $md_file = $file->{&KEY_ABSOLUTE_PATH};
    my $target = get_target_path($md_file, $cli_root_path, $cli_target_path);
    my $target_dir = $target->{&KEY_ABSOLUTE_DIR};
    my $target_file = $target->{&KEY_ABSOLUTE_PATH};
    $target_file =~ s/\.md$/.html/i;

    make_path($target_dir) unless(-d $target_dir);
    unlink($target_file) if (-e $target_file);
    printf("${md_file} -> ${target_file}\n") if ($cli_verbose);

    system(
        &PANDOC,
        $md_file,
        '-f',
        'markdown',
        '-t',
        'html',
        '--quiet',
        '--include-in-header',
        $PANDOC_CSS,
        '-s',
        '-o',
        $target_file
    );

    convert_md_links($target_file)
}
